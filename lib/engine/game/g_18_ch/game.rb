# frozen_string_literal: true

require_relative 'entities'
require_relative 'map'
require_relative 'meta'
require_relative 'tiles'
require_relative '../g_1858/game'

module Engine
  module Game
    module G18CH
      class Game < G1858::Game
        include_meta(G18CH::Meta)
        include Entities
        include Map
        include Tiles

        CURRENCY_FORMAT_STR = '%sfr'

        BANK_CASH = 8_000
        STARTING_CASH = { 2 => 500, 3 => 335, 4 => 250 }.freeze
        CERT_LIMIT = { 2 => 20, 3 => 13, 4 => 10 }.freeze

        PHASES = G1858::Trains::PHASES.reject { |phase| phase['name'] == '7' }
        STATUS_TEXT = G1858::Trains::STATUS_TEXT.merge(
          'green_privates' => ['Yellow and green privates available',
                               'The first and second batches of private companies can be auctioned'],
          'blue_privates' => ['All privates available',
                               'The first, second and third batches of private companies can be auctioned'],
        ).freeze

        def game_phases
          phases = super
          phases[2][:status] = %w[blue_privates narrow_gauge]
          phases
        end

        TRAINS = G1858::Trains::TRAINS.reject { |train| train['name'] == '7E' }
        TRAIN_COUNTS = {
          '2H' => 4,
          '4H' => 3,
          '6H' => 3,
          '5E' => 2,
          '6E' => 10,
          '5D' => 5,
        }.freeze

        def game_trains
          trains = super
          trains.last[:available_on] = '6'
          trains
        end

        def num_trains(train)
          TRAIN_COUNTS[train[:name]]
        end
      end
    end
  end
end
