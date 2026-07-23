# frozen_string_literal: true

module Engine
  module RouteGraph
    # Vertices occur in the {RouteGraph RouteGraph} at the ends of, and junctions between,
    # {Edge edges}. There are several different types of vertex representing different
    # things, these are represented by classes that include this module.
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
    module Vertex
      # @return [Array<Edge>] The edges directly connected to this vertex.
      attr_reader :edges

      def initialize(_place)
        @edges = []
      end

      # @api private
      # @note Intended for debugging and route graph visualisation only.
      # @return [string] A description of the type of vertex.
      # @!attribute [r] description
      def description
        type
      end

      # Links this vertex to another edge.
      # @param edge [Edge] The new edge to link.
      def add_edge!(edge)
        @edges << edge
      end

      # Removes an edge that had been linked to this vertex.
      # @param edge [Edge] The edge to unlink.
      def delete_edge!(edge)
        @edges.delete(edge)
      end

      # Tests whether it is possible to optimise the route graph by removing
      # this vertex and merging its edges.
      # @return [boolean] True if this vertex's edges can be merged.
      def edges_mergeable?
        false
      end

      private

      def inspect
        "<#{self.class.name}: id: #{@id}>"
      end
    end

    # Represents a city, town or halt in the route graph.
    class NodeVertex
      include Vertex

      # The {Part::City City}, {Part::Town Town} or {Part::Halt Halt} object
      # for the revenue center represented by this vertex in the route graph.
      # @return [Part::RevenueCenter]
      attr_reader :node

      # @return [string] A unique identifier for this vertex.
      attr_reader :id

      # @return [Hex] The hex that this vertex is on.
      attr_reader :hex

      # @return [string] The location name, for named hexes.
      attr_reader :location

      # @return [string] A string describing the type of vertex.
      attr_reader :type

      # @param [Part::RevenueCenter] node The node to create a graph vertex for.
      def initialize(node)
        super
        @node = node
        @id = node.id
        @hex = node.tile.hex
        @type = node.class.name.split('::').last
        @location = hex.location_name
      end

      # @api private
      # @note Intended for debugging and route graph visualisation only.
      # @return [string] A description of the type of vertex, its hex and
      #   location name.
      def description
        desc = "#{type} #{hex.coordinates} #{id}"
        desc += " [#{@location}]" if @location
        desc
      end
    end

    # The edge of a hex tile. These can be where a track Path ends at a hex edge
    # or where two paths join from two adjacent hexes. In the latter case the
    # vertex might be removed and the edges joined if they both have the same
    # track gauge and the same lane.
    class HexEdgeVertex
      include Vertex

      # @return [string] A unique identifier for this vertex.
      attr_reader :id

      # @!attribute [r] edges
      def edges
        @edges.values.flatten
      end

      # @param [HexEdgeCrossing] crossing The point boundary between two hexes
      #   where the track path ends.
      def initialize(crossing)
        @crossing = crossing
        @id = crossing.id

        # Instead of maintaining a single collection of edges, split it by the
        # HexExit they reach the vertex from. This lets us determine if there
        # are any converging junctions: if two or more edges/paths reach the
        # hex edge point via the same HexExit then this is a converging
        # junction.  If just a single edge uses the HexExit then this is not
        # a converging junction.
        @edges = Hash.new { |h, k| h[k] = [] }
      end

      # Links this vertex to another edge.
      # @param edge [Edge] The new edge to link.
      def add_edge!(edge)
        hex = edge.paths_from(self).first.hex
        hex_exit = @crossing.exits.find { |e| e.hex == hex }
        @edges[hex_exit] << edge
      end

      # Finds the HexExit associated with a given edge at this vertex.
      # @param edge [Edge]
      # @return [HexExit, nil]
      def exit_for_edge(edge)
        @edges.each_key.find { |hex_exit| @edges[hex_exit].include?(edge) }
      end

      # The HexExits at this crossing.
      # @return [Array<HexExit>]
      def crossing_exits
        @crossing.exits
      end

      # Removes an edge that had been linked to this vertex.
      # @param edge [Edge] The edge to unlink.
      def delete_edge!(edge)
        @edges.each_value { |edges| edges.delete(edge) }
      end

      # @return [string] A string describing the type of vertex.
      def type
        case @edges.size
        when 1 then 'Edge'
        when 2 then paths_cross_edge? ? 'Junction' : 'Edge'
        else 'Junction'
        end
      end

      # Tests whether edges are part of a converging junction. This method is
      # used to prevent backtracking at converging junctions.
      # @param edge1 [Edge]
      # @param edge2 [Edge]
      # @return [Boolean] True if edge1 and edge2 are part of a converging
      #   junction.
      def edges_converge?(edge1, edge2)
        @edges.any? { |_exit, edges| ([edge1, edge2] - edges).empty? }
      end

      # There are usually two hexes associated with a hex edge (the exception
      # is at the edge of maps). This returns one of the two hexes for the
      # vertex's location. If there is only track on one of the two hexes then
      # the hex with no track is returned, so the hex where new track could be
      # built can be shown in the graph visualisation.
      # @return [Hex] A hex associated with this vertex.
      def hex
        # Doesn't make much difference which hex we use where there is track
        # on both sides of the hex edge crossing.
        return @crossing.exits.first.hex if paths_cross_edge?

        hex = @crossing.exits.map(&:hex).difference(path_hexes).first
        return hex if hex

        # Track pointing off the edge of the map, with no adjacent hex.
        @crossing.exits.first.hex
      end

      # @api private
      # @note Intended for debugging and route graph visualisation only.
      # @return [string] A description of the type of vertex.
      def description
        "#{type} #{id}"
      end

      # A hex edge vertex can be optimised out of the route graph by merging
      # its edges if there are two paths meeting at this hex edge, they are on
      # different hexes, and they both have the same track gauge.
      # @return [boolean] True if this vertex's edges can be merged.
      def edges_mergeable?
        return false if edges.any? { |e| edge_converges?(e) || far_end_converges?(e) }
        return false unless paths_cross_edge?

        edges.map(&:gauge).uniq.one?
      end

      protected

      # Tests whether an edge is part of a converging junction at this vertex.
      # @param edge [Edge]
      # @return [Boolean]
      def edge_converges?(edge)
        @edges.any? { |_exit, edges| edges.size > 1 && edges.include?(edge) }
      end

      private

      # Tests whether the far end of an edge is at a converging junction.
      # @param edge [Edge]
      # @return [Boolean]
      def far_end_converges?(edge)
        other = edge.other_end(self)
        other.is_a?(HexEdgeVertex) && other.edge_converges?(edge)
      end

      def path_hexes
        @edges.keys.map(&:hex).uniq
      end

      # Tests if the hex edge crossing point represented by this vertex has
      # path connections on both adjoining hexes.
      # @return [boolean] True if track paths cross the hex edge at this point.
      def paths_cross_edge?
        path_hexes.size > 1
      end
    end

    # Represents a junction in the middle of Lawson-type plain track tile.
    class JunctionVertex
      include Vertex

      # @return [string] A unique identifier for this vertex.
      attr_reader :id

      # @return [Hex] The hex that this vertex is on.
      attr_reader :hex

      # @return [string] A string describing the type of vertex.
      attr_reader :type

      # @param [Part::Junction] junction The track junction to be added to the graph.
      def initialize(junction)
        super
        @id = junction.id
        @hex = junction.tile.hex
        @type = 'Junction'
      end

      # @api private
      # @note Intended for debugging and route graph visualisation only.
      # @return [string] A description of the type of vertex and its hex.
      def description
        "#{type} #{hex.coordinates} #{id}"
      end
    end
  end
end
