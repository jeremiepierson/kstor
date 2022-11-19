# frozen_string_literal: true

module KStor
  module Model
    # Base class for model objects.
    class Base
      class << self
        attr_reader :properties

        # Define a named property
        #
        # @param name [Symbol] name of the property
        # @param read_only [Boolean] false to define both a getter and a setter
        def property(name, read_only: false)
          @properties ||= []
          @properties << name
          define_method(name) do
            @data[name]
          end
          return if read_only

          define_method("#{name}=".to_sym) do |value|
            @data[name] = value
            @dirty = true
          end
        end

        # Check if a property is defined.
        #
        # @param name [Symbol] name of the property
        # @return [Boolean] true if it is defined
        def property?(name)
          @properties.include?(name)
        end
      end

      # Create a model object from hash values
      #
      # @param values [Hash] property values
      # @return [KStor::Model::Base] a new model object
      def initialize(**values)
        @data = {}
        values.each do |k, v|
          @data[k] = v if self.class.property?(k)
        end
        @dirty = false
      end

      # Check if properties were modified since instanciation
      #
      # @return [Boolean] true if modified
      def dirty?
        @dirty
      end

      # Tell the object that dirty properties were persisted.
      def clean
        @dirty = false
      end

      # Represent model object as a Hash
      #
      # @return [Hash] a hash of model object properties
      def to_h
        @data.to_h { |k, v| [k.to_s, v.respond_to?(:to_h) ? v.to_h : v] }
      end
    end
  end
end
