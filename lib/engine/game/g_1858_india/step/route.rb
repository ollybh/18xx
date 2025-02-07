# frozen_string_literal: true

require_relative '../../g_1858/step/route'

module Engine
  module Game
    module G1858India
      module Step
        class Route < G1858::Step::Route
          def actions(entity)
            actions = super.dup
            actions << 'choose' if !actions.empty? && choosing?(entity)
            actions
          end

          def choice_name
            'Attach mail train to another train'
          end

          def choices
            attachable_trains(current_entity).to_h do |train|
              [train.id, "#{train.name} train"]
            end
          end

          def round_state
            super.merge({ mail_trains: {} })
          end

          def process_choose(action)
            @round.mail_trains[action.entity] = @game.train_by_id(action.choice)
          end

          def train_name(corporation, train)
            return train.name unless @round.mail_trains[corporation] == train

            "#{train.name} + Mail"
          end

          private

          def choosing?(corporation)
            @game.owns_mail_train?(corporation) && !mail_train_attached?(corporation)
          end

          # The trains that a mail train can be attached to.
          def attachable_trains(corporation)
            corporation.trains.select do |train|
              train.track_type == :broad && !@game.mail_train?(train)
            end
          end

          def mail_train_attached?(corporation)
            !@round.mail_trains[corporation].nil?
          end
        end
      end
    end
  end
end
