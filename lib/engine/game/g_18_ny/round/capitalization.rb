# frozen_string_literal: true

require_relative '../../../round/operating'

module Engine
  module Game
    module G18NY
      module Round
        class Capitalization < Engine::Round::Operating
          def name
            'Capitalization Round'
          end

          def self.short_name
            'CR'
          end

          def setup
            @current_operator = nil
            after_setup
          end

          def start_operating
            entity = @entities[@entity_index]
            @current_operator = entity
            @current_operator_acted = false
            skip_steps
            next_entity! if finished?
          end

          def show_in_history?
            false
          end
        end
      end
    end
  end
end
