# frozen_string_literal: true

require_relative 'graph'
require_relative 'edge'
require_relative 'vertex'

module Engine
  module RouteGraph
    class GraphWalker
      def initialize(graph)
        @graph = graph
        @found_vertices = Set[]
      end

      def walk(entity)
        home_nodes(entity).each do |node|
          vertex = @graph.vertices.find { |v| v.id == node.id }
          puts "starting walk at vertex #{vertex.id}"
          dfs(vertex)
        end
        puts "finished, found vertices #{@found_vertices.map(&:id).join(', ')}"
      end

      private

      def dfs(vertex)
        return if @found_vertices.include?(vertex)

        @found_vertices << vertex
        puts "continuing walk at vertex #{vertex.id}"
        edges = @graph.edges.select do |edge|
          next unless edge.linked?(vertex)

          dfs(edge.ends.reject(vertex).first)
        end
      end

      def home_nodes(entity)
        entity.placed_tokens.map(&:city)
      end
    end
  end
end
