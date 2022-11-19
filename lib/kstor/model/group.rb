# frozen_string_literal: true

module KStor
  module Model
    # A group of users that can access the same set of secrets.
    class Group < Base
      # @!macro dsl_model_properties_rw
      property :id
      # @!macro dsl_model_properties_rw
      property :name
      # @!macro dsl_model_properties_rw
      property :pubk

      # Dump properties except pubk.
      def to_h
        super.except('pubk')
      end
    end
  end
end
