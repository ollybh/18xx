# frozen_string_literal: true

module Engine
  module RouteGraph
    class Vertex
      attr_reader :id, :hex, :location, :type

      def name
        hex.coordinates
      end

      def description
        desc = "#{@type} #{name} #{@id}"
        desc += " [#{@location}]" if @location
        desc
      end

      private

      def inspect
        "<#{self.class.name}: id: #{@id}>"
      end
    end

    class NodeVertex < Vertex
      attr_reader :node

      def initialize(node)
        @node = node
        @id = node.id
        @hex = node.tile.hex
        @type = node.class.name.split('::').last
        @location = hex.location_name
      end
    end

    class HexEdgeVertex < Vertex
      def initialize(edge, id)
        @id = id
        # Set the hex to the one adjacent to the hex, so the link from this
        # vertex is to the hex where track could be laid.
        @hex = edge.hex.all_neighbors[edge.num]
        @type = 'Edge'
      end
    end

    class JunctionVertex < Vertex
      def initialize(junction)
        @id = junction.id
        @hex = junction.tile.hex
        @type = 'Junction'
      end
    end

    class ConvergingJunctionVertex < JunctionVertex
      def initialize(edge, id)
        @id = id
        @hex = edge.tile.hex
        @type = 'Junction'
      end
    end
  end
end
