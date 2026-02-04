# frozen_string_literal: true

module Engine
  module RouteGraph
    # This class represents the boundary between two hexes on the map, where
    # track paths may join. It takes into account lane placement, so parallel
    # lanes will not have the same boundary position.
    class HexBoundary
      # The position of the lane relative to the centre of the tile edge.
      # Examples of these offsets include:
      # 0::  The centre of the edge. This could correspond to a tile path with
      #      its lane defined as any of '1.0', '2.1', '3.1' or '4.2'.
      # +1:: One lane anticlockwise from the centre of the edge. Path lane
      #      definitions for this include '3.2' and '4.3'.
      # -1:: One lane clockwise from the centre of the edge. Path lane
      #      definitions for this include '2.0', '3.0' and '4.1'.
      # -2:: Two lanes anticlockwise from the centre of the edge. Path lane
      #      definitions for this include '4.0'.
      attr_reader :lane_offset

      # Creates a {HexBoundary} object from a {Part::Edge}.
      # @param [Part::Edge] edge A tile edge.
      # @param [integer] lanes The number of lanes on this edge.
      # @param [integer] lane  The lane position.
      def initialize(edge, lanes, lane)
        hex = edge.hex
        @hexes = {
          hex => edge.num,
          hex.all_neighbors[edge.num] => (edge.num + 3) % 6,
        }
        @lane_offset = lane - lanes.div(2)
      end

      # @return [Array<Hex>] The hexes on either side of this boundary.
      def hexes
        @hexes.keys
      end

      # @return [string] A text description of the boundary between hexes,
      # including both hex coordinates and their edge numbers.
      def id
        @hexes.map { |hex, edge| "#{hex.coordinates}-#{edge}" }.sort.join(':') + ":#{@lane_offset}"
      end
    end
  end
end
