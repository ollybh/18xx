# frozen_string_literal: true

require_relative 'base'

module Engine
  module Part
    class Reservation < Base
      attr_reader :entity, :icon

      def initialize(entity)
        @entity = entity
      end

      def inspect
        "<#{self.class.name} entity=#{@entity.id}>"
      end
    end
  end
end
