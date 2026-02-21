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

      # @return [Array<Part::Path>] The track paths represented by this edge.
      #   These are ordered so that the first path in the array connects to
      #   {#left}, and the last path connects to {#right}.
      attr_reader :paths

      # @return [Label] The gauge of the track.
      attr_reader :gauge

      # @param [Vertex] left  The first vertex joined by this edge.
      # @param [Vertex] right The second vertex joined by this edge.
      # @param [Array<Part::Path>] paths The track paths represented by this edge.
      def initialize(left, right, paths)
        @left = left
        @right = right
        @paths = paths
        @gauge = paths.first.track
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

      # @param [Vertex] vertex The vertex at one end of this edge.
      # @return [Array<Part::Path>] The track paths for this edge, ordered
      #   starting at +vertex+.
      # @raise [GameError] If this edge is not connected to +vertex+.
      def paths_from(vertex)
        case vertex
        when left then @paths
        when right then @paths.reverse
        else raise GameError, "Edge #{self} not linked to Vertex {vertex}"
        end
      end

      # @param [Vertex] vertex The vertex at one end of this edge.
      # @return [Array<Part::Path>] The track paths for this edge, ordered
      #   ending at +vertex+.
      # @raise [GameError] If this edge is not connected to +vertex+.
      def paths_to(vertex)
        case vertex
        when left then @paths.reverse
        when right then @paths
        else raise GameError, "Edge #{self} not linked to Vertex {vertex}"
        end
      end
    end
  end
end
