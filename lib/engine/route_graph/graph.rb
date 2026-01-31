# frozen_string_literal: true

require_relative 'edge'
require_relative 'vertex'
require_relative 'graph_walker'

module Engine
  module RouteGraph
    class Graph
      attr_accessor :vertices, :edges

      # The dimensions of the SVG canvas for the visualisation of the graph.
      VIEW_WIDTH = 1_000
      VIEW_HEIGHT = 1_000
      VIEW_MIN_X = VIEW_WIDTH / 2
      VIEW_MIN_Y = VIEW_HEIGHT / 2

      def initialize(game)
        @vertices = []
        @edges = []
        load_map(game) if game
      end

      def add_edge(left, right, gauge)
        e = Edge.new(left, right, gauge)
        @edges << e
        e
      end

      def add_edge_vertex(edge, id)
        v = HexEdgeVertex.new(edge, id)
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

      def add_converging_junction_vertex(edge)
        # This tile has two (or more) paths that converge on the same edge.
        # Treat this similar to a Lawson-type tile, with a junction near the
        # edge of the tile and a single path from the junction to the edge.
        edge_vertex = @vertices.find { |vertex| vertex.id == edge_id(edge) }
        edge_vertex ||= add_edge_vertex(edge, edge_id(edge))

        junction_vertex = @vertices.find { |vertex| vertex.id == edge_junction_id(edge) }
        unless junction_vertex
          junction_vertex = ConvergingJunctionVertex.new(edge, edge_junction_id(edge))
          @vertices << junction_vertex
        end

        if @edges.none? { |e| (e.ends - [edge_vertex, junction_vertex]).empty? }
          add_edge(edge_vertex, junction_vertex, :broad) # FIXME: gauge from paths
        end

        junction_vertex
      end

      def vertex(place)
        vertex = @vertices.find { |v| v.id == vertex_id(place) }
        return vertex if vertex

        case place
        when Engine::Part::Node
          add_node_vertex(place)
        when Engine::Part::Edge
          if multiple_paths?(place)
            add_converging_junction_vertex(place)
          else
            add_edge_vertex(place, vertex_id(place))
          end
        when Engine::Part::Junction
          add_junction_vertex(place)
        else
          raise NotImplementedError
        end
      end

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

      def walker(entity)
        GraphWalker.new(self, entity)
      end

      private

      def load_map(game)
        game.hexes.map(&:tile).each do |tile|
          tile.nodes.each do |node|
            add_node_vertex(node)
          end

          tile.paths.each do |path|
            left = vertex(path.a)
            right = vertex(path.b)
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

      def edge_id(edge)
        [edge.hex, edge.hex.all_neighbors[edge.num]].map(&:coordinates).sort.join('-')
      end

      def edge_junction_id(edge)
        "#{edge.tile.hex.coordinates}-junction-edge#{edge.num}"
      end

      def vertex_id(place)
        return place.id unless place.is_a? Engine::Part::Edge

        if multiple_paths?(place)
          edge_junction_id(place)
        else
          edge_id(place)
        end
      end

      # Tests whether there are multiple converging paths meeting on this edge.
      # FIXME: needs to work with lanes.
      def multiple_paths?(edge)
        edge.tile.paths.count { |path| path.exits.include?(edge.num) } > 1
      end
    end
  end
end
