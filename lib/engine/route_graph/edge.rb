# frozen_string_literal: true

module Engine
  module RouteGraph
    # Edges join {Vertex vertices} in the {RouteGraph RouteGraph}. They
    # represent a section of track and corresponds to one or more
    # {Part::Path paths} on tiles.
    class Edge
      # @return [Vertex] One end of the edge.
      attr_reader :left

      # @return [Vertex] The other end of the edge.
      attr_reader :right

      # @return [Label] The gauge of the track.
      attr_reader :gauge

      # @param [Vertex] left  The first vertex joined by this edge.
      # @param [Vertex] right The second vertex joined by this edge.
      # @param [Label]  gauge The gauge of track represented by this edge.
      def initialize(left, right, gauge)
        @left = left
        @right = right
        @gauge = gauge
      end

      # @return [Array<Vertex>] Both vertices joined by the edge.
      def ends
        [@left, @right]
      end

      # Tests if a vertex as at either end of the edge.
      # @param [Vertex] vertex The vertex to be checked.
      # @return [boolean] True if the vertex is at the end of this edge.
      def linked?(vertex)
        ends.include?(vertex)
      end
    end
  end
end
