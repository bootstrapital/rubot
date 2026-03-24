# frozen_string_literal: true

module Rubot
  module Policy
    Request = Struct.new(
      :action,
      :resource,
      :runnable,
      :run,
      :subject,
      :context,
      :controller,
      :actor,
      keyword_init: true
    ) do
      def policy_target
        resource || runnable || run
      end

      def policy_definition
        target = policy_target
        return target.rubot_policy if target.respond_to?(:rubot_policy)

        if run && Object.const_defined?(run.name)
          runnable_class = Object.const_get(run.name)
          return runnable_class.rubot_policy if runnable_class.respond_to?(:rubot_policy)
        end

        nil
      end
    end

    class BaseAdapter
      def authorize!(_request)
        raise NotImplementedError, "#{self.class.name} must implement #authorize!"
      end
    end

    class PunditAdapter < BaseAdapter
      def authorize!(request)
        policy_class = resolve_policy_class(request)
        actor = request.actor || raise(Rubot::AuthorizationError, "No policy actor was available for #{request.action}")
        query = "#{request.action}?".to_sym
        policy = policy_class.new(actor, request)

        raise Rubot::AuthorizationError, "Pundit policy #{policy_class.name} does not implement #{query}" unless policy.respond_to?(query)
        raise Rubot::AuthorizationError, "Not authorized to #{request.action}" unless policy.public_send(query)

        true
      end

      private

      def resolve_policy_class(request)
        definition = request.policy_definition
        case definition
        when Class
          definition
        when String, Symbol
          Object.const_get(definition.to_s)
        when NilClass
          return Object.const_get("RubotPolicy") if Object.const_defined?("RubotPolicy")

          raise Rubot::AuthorizationError, "No Pundit policy configured for #{request.policy_target || request.run}"
        else
          raise Rubot::AuthorizationError, "Unsupported Pundit policy definition #{definition.inspect}"
        end
      rescue NameError => e
        raise Rubot::AuthorizationError, "Unable to resolve Pundit policy: #{e.message}"
      end
    end

    class CanCanAdapter < BaseAdapter
      def initialize(ability_class_name: "Ability")
        @ability_class_name = ability_class_name
      end

      def authorize!(request)
        actor = request.actor || raise(Rubot::AuthorizationError, "No policy actor was available for #{request.action}")
        ability = resolve_ability(actor, request)
        target = request.policy_target || request

        raise Rubot::AuthorizationError, "Not authorized to #{request.action}" unless ability.can?(request.action, target)

        true
      end

      private

      attr_reader :ability_class_name

      def resolve_ability(actor, request)
        return request.controller.current_ability if request.controller&.respond_to?(:current_ability)
        raise Rubot::AuthorizationError, "CanCanCan ability #{ability_class_name} is not defined" unless Object.const_defined?(ability_class_name)

        Object.const_get(ability_class_name).new(actor)
      end
    end

    class << self
      def authorize!(action:, resource: nil, runnable: nil, run: nil, subject: nil, context: {}, controller: nil, actor: nil, fail_run: false)
        adapter = Rubot.configuration.policy_adapter
        return true unless adapter

        request = Request.new(
          action: action.to_sym,
          resource: resource,
          runnable: runnable,
          run: run,
          subject: subject || run&.subject,
          context: context || run&.context || {},
          controller: controller,
          actor: actor || resolve_actor(context, controller)
        )

        adapter.authorize!(request)
      rescue Rubot::AuthorizationError => e
        record_denial!(run, request || nil, e)
        run.fail!(class: e.class.name, message: e.message, type: "authorization_denied") if fail_run && run && !run.terminal?
        raise
      end

      def resolve_actor(context = {}, controller = nil)
        return Rubot.configuration.policy_actor_resolver.call(context, controller) if Rubot.configuration.policy_actor_resolver
        return context[:current_actor] if context.is_a?(Hash) && context.key?(:current_actor)
        return context[:actor] if context.is_a?(Hash) && context.key?(:actor)
        return controller.current_user if controller&.respond_to?(:current_user)

        nil
      end

      private

      def record_denial!(run, request, error)
        return unless run

        run.add_event(
          Event.new(
            type: "policy.denied",
            step_name: run.current_step,
            payload: {
              action: request&.action,
              resource: request&.policy_target&.respond_to?(:name) ? request.policy_target.name : request&.policy_target&.class&.name,
              error_class: error.class.name,
              error_message: error.message
            }.compact
          )
        )
      end
    end
  end
end
