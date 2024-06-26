# frozen_string_literal: true

require_relative '../g_1858/graph'

module Engine
  module Game
    module G18CH
      class Graph < G1858::Graph
        private

        GOTTHARD_HEX = 'H11'
        PRIVATE_BROAD_GAUGE = 'GB'
        PRIVATE_NARROW_GAUGE = 'FOB'

        def path_node(path, entity)
          node = G1858::Part::PathNode.new(path)
          return node unless path.hex.coordinates == GOTTHARD_HEX

          # The pre-printed Gotthard hex is a special case. It is a home hex
          # for two private railways (FOB and GB) and it has two paths, one
          # broad gauge and one metre (narrow) gauge. FOB is only allowed to
          # trace routes from this hex using the metre gauge path, and GB can
          # only use the broad gauge path.
          return node if (path.track == :broad && entity.id == PRIVATE_BROAD_GAUGE) ||
                         (path.track == :narrow && entity.id == PRIVATE_NARROW_GAUGE)
        end
      end
    end
  end
end
