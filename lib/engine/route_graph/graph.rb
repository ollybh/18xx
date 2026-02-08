# frozen_string_literal: true

require_relative 'edge'
require_relative 'vertex'
require_relative 'graph_walker'
require_relative 'hex_boundary'

module Engine
  # The route graph is an abstracted representation of the state of the game
  # map. The graph's edges represent sections of track. The vertices represent
  # cities, towns, track junctions and edges of hexes where track paths end.
  module RouteGraph
    class Graph
      # @return [Array<Vertex>] The graph's vertices.
      attr_reader :vertices

      # @return [Array<Edge>] The graph's edges.
      attr_reader :edges

      # Builds a new route graph from the current game state.
      def initialize(game)
        @vertices = []
        @edges = []
        load_map(game) if game
      end

      # Converts the graph state into a hash that can be consumed by the
      # Javascript {D3}[https://d3js.org] library to produce a visualisation
      # of the graph.
      # @todo See if this can be method can be removed, and the visualisation
      #   produced directly from the RouteGraph object.
      # @return [Hash<nodes, links>] The graph state in a JSON-friendly format.
      def to_d3
        hexes = @vertices.map(&:hex)
        min_x, max_x = hexes.map(&:x).minmax
        min_y, max_y = hexes.map(&:y).minmax
        {
          nodes: @vertices.map.with_index do |v, i|
            {
              id: "node#{i}",
              type: v.type,
              description: v.description,
              name: v.hex.coordinates,
              connections: @edges.count { |e| e.ends.include?(v) },
              x: ((v.hex.x - min_x) / (max_x - min_x) * VIEW_WIDTH) - VIEW_MIN_X,
              y: ((v.hex.y - min_y) / (max_y - min_y) * VIEW_HEIGHT) - VIEW_MIN_Y,
            }
          end,
          links: @edges.map.with_index do |e, i|
            {
              id: "link#{i}",
              source: "node#{@vertices.index(e.left)}",
              target: "node#{@vertices.index(e.right)}",
              gauge: e.gauge,
            }
          end,
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

      # The dimensions of the SVG canvas for the visualisation of the graph.
      VIEW_WIDTH = 1_000
      VIEW_HEIGHT = 1_000
      VIEW_MIN_X = VIEW_WIDTH / 2
      VIEW_MIN_Y = VIEW_HEIGHT / 2

      def add_edge(left, right, gauge)
        e = Edge.new(left, right, gauge)
        @edges << e
        e
      end

      def add_edge_vertex(edge, lanes, lane)
        hb = HexBoundary.new(edge, lanes, lane)
        v = HexEdgeVertex.new(hb)
        @vertices << v
        v
      end

      def add_node_vertex(node)
        v = NodeVertex.new(node)
        @vertices << v
        v
      end

      def add_junction_vertex(junction)
        v = JunctionVertex.new(junction)
        @vertices << v
        v
      end

      def vertex(place, lanes, lane)
        vertex = @vertices.find { |v| v.id == vertex_id(place, lanes, lane) }
        return vertex if vertex

        case place
        when Engine::Part::Node
          add_node_vertex(place)
        when Engine::Part::Edge
          add_edge_vertex(place, lanes, lane)
        when Engine::Part::Junction
          add_junction_vertex(place)
        else
          raise NotImplementedError
        end
      end

      def load_map(game)
        game.hexes.map(&:tile).each do |tile|
          tile.nodes.each do |node|
            add_node_vertex(node)
          end

          tile.paths.each do |path|
            left = vertex(path.a, path.lanes[0][0], path.lanes[0][1])
            right = vertex(path.b, path.lanes[1][0], path.lanes[1][1])
            add_edge(left, right, path.track) if left && right
          end
        end
        join_edges!
      end

      def join_edges!
        @vertices.dup.each do |vertex|
          next unless vertex.is_a? HexEdgeVertex

          edges = @edges.select { |edge| edge.linked?(vertex) }
          next unless edges.size == 2
          next unless edges.map(&:gauge).uniq.one?

          edge_ends = edges.flat_map(&:ends).reject { |v| v == vertex }
          add_edge(*edge_ends, edges.first.gauge)
          edges.each { |edge| @edges.delete(edge) }
          @vertices.delete(vertex)
        end
      end

      def vertex_id(place, lanes, lane)
        return place.id unless place.is_a? Engine::Part::Edge

        HexBoundary.new(place, lanes, lane).id
      end

      # Tests whether there are multiple converging paths meeting on this edge.
      # FIXME: needs to work with lanes.
      def multiple_paths?(edge)
        edge.tile.paths.count { |path| path.exits.include?(edge.num) } > 1
      end
    end
  end
end
