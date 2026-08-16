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

      # @return [Boolean] True if this edge contains any terminal track paths.
      # @!attribute [r] terminal?
      def terminal?
        @paths.any?(&:terminal)
      end

      # @return [Array<Vertex>] Both vertices joined by the edge.
      # @!attribute[r] ends
      def ends
        [@left, @right]
      end

      # @param left [Vertex] The first vertex joined by this edge.
      # @param right [Vertex] The second vertex joined by this edge.
      # @param paths [Array<Part::Path>] The track paths represented by this edge.
      def initialize(left, right, paths)
        @left = left
        @right = right
        @paths = paths
        @gauge = paths.first.track
      end

      # Tests if a vertex as at either end of the edge.
      # @param [Vertex] vertex The vertex to be checked.
      # @return [boolean] True if the vertex is at the end of this edge.
      def linked?(vertex)
        ends.include?(vertex)
      end

      # @param vertex [Vertex] The vertex at one end of this edge.
      # @return [Vertex] The vertex at the other end of this edge. This could be
      #   the same vertex if this edge forms a loop around +vertex+.
      # @raise [GameError] If this edge is not connected to +vertex+.
      def other_end(vertex)
        case vertex
        when @left then @right
        when @right then @left
        else raise GameError, "Edge #{self} not linked to Vertex {vertex}"
        end
      end

      # @param vertex [Vertex] The vertex at one end of this edge.
      # @return [Array<Part::Path>] The track paths for this edge, ordered
      #   starting at +vertex+.
      # @raise [GameError] If this edge is not connected to +vertex+.
      def paths_from(vertex)
        case vertex
        when @left then @paths
        when @right then @paths.reverse
        else raise GameError, "Edge #{self} not linked to Vertex {vertex}"
        end
      end

      # @param vertex [Vertex] The vertex at one end of this edge.
      # @return [Array<Part::Path>] The track paths for this edge, ordered
      #   ending at +vertex+.
      # @raise [GameError] If this edge is not connected to +vertex+.
      def paths_to(vertex)
        case vertex
        when @left then @paths.reverse
        when @right then @paths
        else raise GameError, "Edge #{self} not linked to Vertex {vertex}"
        end
      end

      # Tests whether either end of this edge is part of a converging junction.
      # @return [Boolean]
      def converges?
        ends.any? do |vertex|
          next false unless vertex.is_a?(HexEdgeVertex)

          vertex.edge_converges?(self)
        end
      end
    end
  end
end
