# frozen_string_literal: true

module Engine
  module RouteGraph
    # Vertices occur in the {RouteGraph RouteGraph} at the ends of, and junctions between,
    # {Edge edges}. There are several different types of vertex representing different
    # things, these are represented by subclasses of Vertex.
    #
    # {HexEdgeVertex}::
    #   The edge of a hex tile. These can be where a track Path ends at a hex
    #   edge, where two paths join from two adjacent hexes, or where two or
    #   more paths on the same tile meet at an edge.
    #
    # {NodeVertex}::
    #   These correspond to a {Part::RevenueCenter RevenueCenter} (City/Town/Halt) on the map.
    #
    # {JunctionVertex}::
    #   Junctions in the middle of Lawson-type plain track tiles.
    class Vertex
      # @return [string] A unique identifier for this vertex.
      attr_reader :id

      # @return [Hex] The hex that this vertex is on.
      attr_reader :hex

      # @return [string] The location name, for named hexes.
      attr_reader :location

      # @return [string] A string describing the type of vertex.
      attr_reader :type

      # @return [string] A description of the type of hex and its location.
      def description
        desc = "#{@type} #{@hex.coordinates} #{@id}"
        desc += " [#{@location}]" if @location
        desc
      end

      private

      def inspect
        "<#{self.class.name}: id: #{@id}>"
      end
    end

    # Represents a city, town or halt in the route graph.
    class NodeVertex < Vertex
      # The {Part::City City}, {Part::Town Town} or {Part::Halt Halt} object
      # for the revenue center represented by this vertex in the route graph.
      # @return [Part::RevenueCenter]
      attr_reader :node

      # @param [Part::RevenueCenter] node The node to create a graph vertex for.
      def initialize(node)
        @node = node
        @id = node.id
        @hex = node.tile.hex
        @type = node.class.name.split('::').last
        @location = hex.location_name
      end
    end

    # The edge of a hex tile. These can be where a track Path ends at a hex edge
    # or where two paths join from two adjacent hexes. In the latter case the
    # vertex might be removed and the edges joined if they both have the same
    # track gauge and the same lane.
    class HexEdgeVertex < Vertex
      # @param [HexEdgeCrossing] crossing The point boundary between two hexes
      #   where the track path ends.
      def initialize(crossing)
        @id = crossing.id
        # TODO: This is where two hexes meet. How does this map to a single hex?
        @hex = crossing.exits.first.hex
        @type = 'Edge'
      end
    end

    # Represents a junction in the middle of Lawson-type plain track tile.
    class JunctionVertex < Vertex
      # @param [Part::Junction] junction The track junction to be added to the graph.
      def initialize(junction)
        @id = junction.id
        @hex = junction.tile.hex
        @type = 'Junction'
      end
    end
  end
end
