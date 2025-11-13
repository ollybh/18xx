# frozen_string_literal: true

module Engine
  module RouteGraph
    class Edge
      attr_accessor :left, :right, :gauge

      def initialize(left, right, gauge)
        @left = left
        @right = right
        @gauge = gauge
      end

      def ends
        [@left, @right]
      end

      def linked?(vertex)
        ends.include?(vertex)
      end
    end
  end
end
