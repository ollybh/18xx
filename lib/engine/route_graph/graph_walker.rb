# frozen_string_literal: true

require_relative 'graph'
require_relative 'edge'
require_relative 'vertex'

module Engine
  module RouteGraph
    class GraphWalker
      def initialize(graph, entity)
        @graph = graph
        @entity = entity
        @found_vertices = Set[]
        @walked_edges = Set[]
      end

      def walk
        home_nodes(@entity).each do |node|
          vertex = @graph.vertices.find { |v| v.id == node.id }
          dfs(vertex)
        end
      end

      # connected_hexes - hexes in which this corporation can lay track
      def connected_hexes
        []
      end

      # connected_nodes - hexes in which this corporation can token
      def connected_nodes
        @found_vertices.select { |v| v.is_a? NodeVertex }.map(&:node)
      end

      def connected_paths
        []
      end

      # reachable_hexes - hexes in which this corporation can run
      def reachable_hexes
        {}
      end

      def debug
        "#{self.class} for #{@entity.inspect}" \
          "\n\tconnected hexes: #{connected_hexes.map(&:coordinates).sort.join(', ')}" \
          "\n\tconnected nodes: #{connected_nodes.map(&:id).sort.join(', ')}" \
          "\n\tconnected paths: #{connected_paths.map(&:id).sort.join(', ')}" \
          "\n\treachable hexes: #{reachable_hexes.keys.map(&:coordinates).sort.join(', ')}"
      end

      private

      def dfs(vertex)
        return if @found_vertices.include?(vertex)

        @found_vertices << vertex
        @graph.edges.select do |edge|
          next unless edge.linked?(vertex)

          @walked_edges << edge
          dfs(edge.ends.reject(vertex).first)
        end
      end

      def home_nodes(entity)
        entity.placed_tokens.map(&:city)
      end
    end
  end
end
