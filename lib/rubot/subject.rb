# frozen_string_literal: true

module Rubot
  module Subject
    class Reference
      attr_reader :gid

      def initialize(gid)
        @gid = gid.is_a?(GlobalID) ? gid : GlobalID.parse(gid)
      end

      def present?
        !gid.nil?
      end

      def key
        gid&.to_s
      end

      def type
        gid&.model_name
      end

      def id
        gid&.model_id
      end

      def ==(other)
        other.is_a?(Reference) && other.gid == gid
      end

      alias eql? ==

      def hash
        gid.hash
      end

      def to_h
        { type: type, id: id, gid: key }.compact
      end
    end

    class << self
      def reference(subject)
        return subject if subject.is_a?(Reference)
        return unless subject

        gid = subject.respond_to?(:to_global_id) ? subject.to_global_id : nil

        # Fallback for models not using GlobalID directly but having class and ID
        if gid.nil?
          type = subject.class.name
          id = subject.respond_to?(:id) ? subject.id : nil
          return unless type && id

          # We don't want to enforce GlobalID strictly if the app doesn't configure it for this model
          # but we need to support old behavior to keep backward compatibility.
          # Actually, since we're refactoring to use GlobalID natively, let's create one.
          gid = GlobalID.new(URI::GID.build(app: GlobalID.app || "rubot", model_name: type, model_id: id))
        end

        Reference.new(gid)
      end

      def resolve(subject = nil, type: nil, id: nil, gid: nil)
        return subject if subject && !subject.is_a?(Reference)

        if gid
          reference = Reference.new(gid)
        elsif subject.is_a?(Reference)
          reference = subject
        elsif type && id
          reference = Reference.new(GlobalID.new(URI::GID.build(app: GlobalID.app || "rubot", model_name: type, model_id: id)))
        else
          return nil
        end

        return unless reference.present?

        custom = Rubot.configuration.subject_locator
        return custom.call(reference) if custom

        default_resolve(reference)
      rescue NameError
        nil
      end

      def matches?(left, right)
        left_reference = reference(left)
        right_reference = reference(right)
        left_reference && right_reference && left_reference == right_reference
      end

      private

      def default_resolve(reference)
        # Try to use GlobalID natively first
        record = GlobalID::Locator.locate(reference.gid)
        return record if record

        # Fallback to the old strategy if GlobalID locator fails (e.g. non-AR objects)
        klass = reference.type.safe_constantize
        return unless klass

        return klass.find_by(id: reference.id) if klass.respond_to?(:find_by)
        return klass.find(reference.id) if klass.respond_to?(:find)

        nil
      end
    end
  end
end
