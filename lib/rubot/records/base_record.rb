# frozen_string_literal: true

module Rubot
  module Records
    class BaseRecord
      def self.attributes(*names)
        attr_accessor(*names)
      end

      def initialize(attrs = {})
        attrs.each do |name, value|
          public_send("#{name}=", value) if respond_to?("#{name}=")
        end
      end

      def to_h
        instance_variables.each_with_object({}) do |ivar, memo|
          memo[ivar.to_s.delete("@").to_sym] = instance_variable_get(ivar)
        end
      end
    end
  end
end
