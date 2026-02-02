# frozen_string_literal: true

module Engine
  module RouteGraph
    # This class represents the boundary between two hexes on the map.
    class HexBoundary
      # Creates a {HexBoundary} object from a {Part::Edge}.
      # @param [Part::Edge] edge A tile edge.
      def initialize(edge)
        hex = edge.hex
        @hexes = {
          hex => edge.num,
          hex.all_neighbors[edge.num] => (edge.num + 3) % 6,
        }
      end

      # @return [Array<Hex>] The hexes on either side of this boundary.
      def hexes
        @hexes.keys
      end

      # @return [string] A text description of the boundary between hexes,
      # including both hex coordinates and their edge numbers.
      def id
        @hexes.map { |hex, edge| "#{hex.coordinates}-#{edge}" }.sort.join(':')
      end
    end
  end
end
