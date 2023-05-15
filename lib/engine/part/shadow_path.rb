# frozen_string_literal: true

require_relative 'path'

module Engine
  module Part
    class ShadowPath < Path
      def shadow?
        true
      end

      def track
        :shadow
      end
    end
  end
end
