# frozen_string_literal: true

module Engine
  module RouteGraph
    # Vertices occur in the {RouteGraph RouteGraph} at the ends of, and junctions between,
    # {Edge edges}. There are several different types of vertex representing different
    # things, these are represented by subclasses of Vertex.
    #
    # {HexEdgeVertex}::
    #   The edge of a hex tile. These can be where a track Path
    #   ends at a hex edge or where two paths join from two adjacent hexes. In
    #   the latter case the vertex might be removed and the edges joined if they
    #   both have the same track gauge and the same lane.
    #
    # {NodeVertex}::
    #   These correspond to a {Part::RevenueCenter RevenueCenter} (City/Town/Halt) on the map.
    #
    # {JunctionVertex}::
    #   Junctions in the middle of Lawson-type plain track tiles.
    #
    # {ConvergingJunctionVertex}::
    #   Junctions on the edges of curvilinear-type
    #   plain track or town tiles. These will generally include restrictions on
    #   valid entry/exit combinations, to avoid a route backtracking at the
    #   junction.
    class Vertex
      attr_reader :id       # @return [String] A unique identifier for this vertex.
      attr_reader :hex      # @return [Hex]    The hex that this vertex is on.
      attr_reader :location # @return [String] The location name, for named hexes.
      attr_reader :type     # @return [String] A string describing the type of vertex.

      # @return [String] A description of the type of hex and its location.
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

    # The edge of a hex tile. These can be where a track Path
    # ends at a hex edge or where two paths join from two adjacent hexes. In
    # the latter case the vertex might be removed and the edges joined if they
    # both have the same track gauge and the same lane.
    class HexEdgeVertex < Vertex
      # @param [Part::Edge] edge The tile edge to be added to the graph.
      # @param [String] id The unique identifier for the tile edge.
      def initialize(edge, id)
        @id = id
        # Set the hex to the one adjacent to the hex, so the link from this
        # vertex is to the hex where track could be laid.
        @hex = edge.hex.all_neighbors[edge.num]
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

    # Represents a junction between two or more track paths on the edge of a
    # curvilinear-type plain track or town tile.
    class ConvergingJunctionVertex < JunctionVertex
      # @param [Part::Edge] edge The tile edge to be added to the graph.
      # @param [String] id The unique identifier for the tile edge.
      def initialize(edge, id)
        @id = id
        @hex = edge.tile.hex
        @type = 'Junction'
      end
    end
  end
end
