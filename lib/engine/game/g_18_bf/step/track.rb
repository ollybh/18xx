# frozen_string_literal: true

require_relative '../../g_1867/step/track'

module Engine
  module Game
    module G18BF
      module Step
        class Track < G1867::Step::Track
          def available_hex(entity, hex)
            return super unless hex == @london_small

            london_available?(entity)
          end

          def london_available?(entity)
            @london_zoomed.any? { |hex| available_hex(entity, hex) }
          end

          def lay_tile(action, extra_cost: 0, entity: nil, spender: nil)
            super

            @game.london_upgraded(action.hex.tile) if action.hex == @london_small
          end
        end
      end
    end
  end
end
