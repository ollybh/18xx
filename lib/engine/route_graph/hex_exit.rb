# frozen_string_literal: true

module Engine
  module RouteGraph
    # This class represents the point on the edge of a hex where a track path
    # may exit the hex. It takes into account lane placement, so there can be
    # multiple exit points on the same hex edge.
    class HexExit
      # The hex that this exit is part of.
      # @return [Hex]
      attr_reader :hex

      # The edge index of the hex. These are counted clockwise, with zero
      # being the southern edge on a +:flat+ map, and the south-western edge
      # on a +:pointy+ map.
      # @return [integer]
      attr_reader :edge

      # The position of the lane relative to the centre of the tile edge.
      # Positive offsets are anti-clockwise from the centre, negative offsets
      # are clockwise from the centre.
      # - If there is a single lane this will be at offset zero.
      # - If there are two lanes then lane +2.0+ will be at offset 1, and lane
      #   +2-1+ at offset -1.
      # - If there are three lanes, lane +3.0+ will be at offset 2, +3.1+ at 0,
      #   +3.2+ at -2.
      # @return [integer]
      attr_reader :lane_offset

      # Creates a HexEdgeCrossing object from a {Part::Edge}.
      # @param [Part::Edge] edge A tile edge.
      # @param [integer] lanes The number of lanes on this edge.
      # @param [integer] lane  The lane position.
      def initialize(edge, lanes, lane)
        return unless edge

        @hex = edge.hex
        @edge = edge.num
        @lane_offset = lanes - 1 - (lane * 2)
      end

      # The hex next to this exit.
      # @return [Hex, nil] The adjacent hex, or nil if there is no adjacent
      #   hex (such as when this is the edge of the map).
      def adjacent_hex
        @hex.all_neighbors[@edge]
      end

      # Tests whether this exit point is connected directly to another hex exit
      # point.
      # @param [HexExit] other The hex exit to check connectivity with.
      # @return [boolean] true if they connect, false otherwise.
      def connects_to?(other)
        adjacent_hex == other.hex &&
          @edge == (other.edge + 3) % 6 &&
          @lane_offset == -1 * other.lane_offset
      end

      # Creates a new HexExit object, representing the exit point that connects
      # to this one, on the adjacent hex's edge.
      # @return [HexExit, nil] The adjacent exit point, or nil if there is not
      #   an adjacent hex to this one.
      def adjacent_exit
        adjacent = HexExit.new
        adjacent.hex = adjacent_hex
        adjacent.edge = (@edge + 3) % 6
        adjacent.lane_offset = -1 * @lane_offset
        adjacent
      end

      # @return [string] A text description of the hex exit location.
      def id
        "#{@hex.coordinates}_#{@edge}_#{@lane_offset}"
      end

      protected

      attr_writer :hex, :edge, :lane_offset
    end

    # This class represents the point where track paths might meet on the
    # edge shared by two hexes. It takes into account lane placement, so there
    # can be multiple crossing points on the edge between two hexes.
    class HexEdgeCrossing
      # The adjacent {HexExit} points which meet to form the crossing point.
      # If one of the hex edges is on the edge of the map then there will only
      # be a single {HexExit} point.
      # @return [Array<HexExit>] The exit point on the hexes.
      attr_reader :exits

      # Creates a {HexEdgeCrossing} object from a {Part::Edge}.
      # @param [Part::Edge] edge A tile edge.
      # @param [integer] lanes The number of lanes on this edge.
      # @param [integer] lane  The lane position.
      def initialize(edge, lanes, lane)
        exit1 = HexExit.new(edge, lanes, lane)
        exit2 = exit1.adjacent_exit
        @exits = [exit1, exit2].compact.sort_by(&:hex)
      end

      # @return [string] A text description of the hex crossing point.
      def id
        @exits.map(&:id).join('|')
      end

      # Override the default hash calculation, to cause HexEdgeCrossing objects
      # that represent the same location to return the same hash value.
      # @return [integer] The hash value.
      def hash
        [self.class, @exits.map { |e| [e.hex, e.edge, e.lane_offset] }].hash
      end

      # Override the default method, to prevent duplication of HexEdgeCrossing
      # objects in a hash where different objects represent the same location.
      # @param [HexEdgeCrossing] other The HexEdgeCrossing object to compare.
      # @return [boolean] True if this and the other object represent the same
      #   hex edge crossing location, false if not.
      def eql?(other)
        # The opalrb array hash algorithm seems to often produce collisions.
        # Add an extra check to avoid these.
        hash == other.hash && id == other.id
      end
    end
  end
end
