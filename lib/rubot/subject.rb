# frozen_string_literal: true

module Rubot
  module Subject
    class Reference
      attr_reader :type, :id

      def initialize(type:, id:)
        @type = type
        @id = id&.to_s
      end

      def present?
        !type.to_s.empty? && !id.to_s.empty?
      end

      def key
        return unless present?

        "#{type}:#{id}"
      end

      def ==(other)
        other.is_a?(Reference) && other.type == type && other.id == id
      end

      alias eql? ==

      def hash
        [type, id].hash
      end

      def to_h
        { type:, id: }
      end
    end

    class << self
      def reference(subject)
        return subject if subject.is_a?(Reference)
        return unless subject

        type = subject.class.name
        id = subject.respond_to?(:id) ? subject.id : nil
        return unless type && id

        Reference.new(type:, id:)
      end

      def resolve(subject = nil, type: nil, id: nil)
        return subject if subject && !subject.is_a?(Reference)

        reference = subject.is_a?(Reference) ? subject : Reference.new(type:, id:)
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
        return unless Object.const_defined?(reference.type)

        klass = Object.const_get(reference.type)
        return klass.find_by(id: reference.id) if klass.respond_to?(:find_by)
        return klass.find(reference.id) if klass.respond_to?(:find)

        nil
      end
    end
  end
end
