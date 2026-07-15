# frozen_string_literal: true

require_relative 'edge'
require_relative 'vertex'
require_relative 'graph_walker'
require_relative 'hex_exit'

module Engine
  module RouteGraph
    # The route graph is an abstracted representation of the state of the game
    # map. The graph's edges represent sections of track. The vertices represent
    # cities, towns, track junctions and edges of hexes where track paths end.
    class Graph
      # The edges in the graph.
      # @return [Array<Edge>]
      attr_reader :edges

      # The vertices in the graph.
      # @return [Array<Vertex>]
      def vertices
        @vertices.values
      end

      # Builds a new route graph from the current game state.
      def initialize(game)
        @edges = []
        @vertices = Hash.new { |h, k| h[k] = new_vertex(k) }
        load_map(game) if game
      end

      # Converts the graph state into a hash that can be consumed by the
      # Javascript {D3}[https://d3js.org] library to produce a visualisation
      # of the graph.
      # @api private
      # @note Intended for the route graph visualisation only.
      # @todo See if this can be method can be removed, and the visualisation
      #   produced directly from the RouteGraph object.
      # @param width  [integer] The width of the SVG element the visualisation
      #   will be rendered in. This is used to seed the initial positions of
      #   the vertices, so there is a vaguely geographical layout on the final
      #   visualisation.
      # @param height [integer] The width of the SVG element the visualisation
      #   will be rendered in. This is used to seed the initial positions of
      #   the vertices, so there is a vaguely geographical layout on the final
      #   visualisation.
      # @return [Hash<nodes, links>] The graph state in a JSON-friendly format.
      def to_d3(width = 1000, height = 1000)
        vertices = @vertices.values
        hexes = vertices.map(&:hex)
        min_x, max_x = hexes.map(&:x).minmax
        min_y, max_y = hexes.map(&:y).minmax
        range_x = min_x == max_x ? 1 : max_x - min_x
        range_y = min_y == max_y ? 1 : max_y - min_y
        {
          nodes: vertices.map.with_index do |v, i|
            {
              id: "node#{i}",
              type: v.type,
              description: v.description,
              name: v.hex.coordinates,
              connections: v.edges.size,
              x: ((v.hex.x - min_x) / range_x * width) - (width / 2),
              y: ((v.hex.y - min_y) / range_y * height) - (height / 2),
            }
          end,
          links: @edges.map.with_index do |e, i|
            {
              id: "link#{i}",
              source: "node#{vertices.index(e.left)}",
              target: "node#{vertices.index(e.right)}",
              gauge: e.gauge,
              hexes: e.paths.map { |p| p.hex.coordinates }.join('-'),
            }
          end,
          width: width,
          height: height,
        }
      end

      # Creates a {GraphWalker} for the specified entity.
      # @param [Operator] entity The corporation/minor/system to compute the
      #   possible graph connections for.
      # @return [GraphWalker]
      def walker(entity)
        GraphWalker.new(self, entity)
      end

      private

      def add_edge(left, right, paths)
        e = Edge.new(left, right, paths)
        left.edges << e
        right.edges << e
        @edges << e
        e
      end

      def new_vertex(place)
        case place
        when Engine::Part::Node
          NodeVertex.new(place)
        when HexEdgeCrossing
          HexEdgeVertex.new(place)
        when Engine::Part::Junction
          JunctionVertex.new(place)
        else
          raise NotImplementedError
        end
      end

      def load_map(game)
        game.hexes.map(&:tile).each do |tile|
          tile.nodes.each do |node|
            @vertices[node]
          end

          tile.paths.each do |path|
            left = @vertices[node_or_exit(path.a, *path.lanes.first)]
            right = @vertices[node_or_exit(path.b, *path.lanes.last)]
            add_edge(left, right, [path]) if left && right
          end
        end
        join_edges!
      end

      def node_or_exit(place, lanes, lane)
        return place unless place.is_a?(Engine::Part::Edge)

        HexEdgeCrossing.new(place, lanes, lane)
      end

      def join_edges!
        @vertices.dup.each do |place, vertex|
          next unless vertex.edges_mergeable?

          left, right = vertex.edges.flat_map(&:ends).reject { |v| v == vertex }
          paths = vertex.edges.first.paths_to(vertex) +
                  vertex.edges.last.paths_from(vertex)
          add_edge(left, right, paths)
          vertex.edges.each do |edge|
            left.edges.delete(edge)
            right.edges.delete(edge)
            @edges.delete(edge)
          end
          @vertices.delete(place)
        end
      end
    end
  end
end
