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

        CURRENCY_FORMAT_STR = '%ssfr'

        BANK_CASH = 8_000
        STARTING_CASH = { 2 => 500, 3 => 335, 4 => 250 }.freeze
        CERT_LIMIT = { 2 => 20, 3 => 13, 4 => 10 }.freeze

        PHASES = G1858::Trains::PHASES.reject { |phase| phase['name'] == '7' }
        STATUS_TEXT = G1858::Trains::STATUS_TEXT.merge(
          'green_privates' => ['Yellow and green privates available',
             'The first and second batches of private companies can be auctioned'],
          'all_privates' => ['All privates available',
             'The first, second and third batches of private companies can be auctioned'],
          'blue_privates' => ['Blue privates available',
             'The third batch of private companies can be auctioned'],
        ).freeze
        EVENTS_TEXT = G1858::Trains::EVENTS_TEXT.merge(
            'blue_privates_available' => ['Blue privates can start',
                                           'The third set of private companies becomes available'],
            'privates_close' => ['Yellow/green private companies close',
                                 'The first private closure round takes place at the end of the ' \
                                 'operating round in which the first 5E/4M train is bought'],
            'privates_close2' => ['Blue private companies close',
                                 'The second private closure round takes place at the end of the ' \
                                 'operating round in which the first 6E/5M train is bought'],
          ).freeze

        def game_phases
          phases = super
          phases[2][:status] = %w[all_privates narrow_gauge]
          phases[3][:status] = %w[blue_privates public_companies dual_gauge]
          phases[4][:tiles] = %i[yellow green brown gray]
          phases
        end

        def timeline
          @timeline = ['5D trains are available after the first 6E/5M train has been bought.',
                       '4H/2M trains rust when the second 6E/5M/5D train is bought.',
                       '6H/3M trains rust when the fourth 6E/5M/5D train is bought.']
        end

        def event_blue_privates_available!
          @log << '-- Event: Blue private companies can be started --'
          # Don't need to change anything, the check in buyable_bank_owned_companies
          # will let these companies be auctioned in future stock rounds.
        end

        def event_privates_close!
          @log << '-- Event: Yellow and green private companies will close ' \
                  'at the end of this operating round --'
          @private_closure_round = :next
        end

        def event_privates_close2!
          @log << '-- Event: Blue private companies will close at the end ' \
                  'of this operating round --'
          @private_closure_round = :next
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
        GREY_TRAINS = %w[6E 5M 5D].freeze

        def game_trains
          trains = super
          trains[2][:obsolete_on] = '6E'
          trains[2][:events] = [{ 'type' => 'blue_privates_available' }]
          trains[4][:events] = [{ 'type' => 'privates_close2' }]
          trains[4][:price] = 700
          trains[4][:variants][0][:price] = 600
          trains.last[:available_on] = '6'
          trains
        end

        def num_trains(train)
          TRAIN_COUNTS[train[:name]]
        end

        @phase3_train_trigger = 2
        @phase4_train_trigger = 4
        def maybe_rust_wounded_trains!(grey_trains_bought, purchased_train)
          rust_wounded_trains!(%[4H 2M], purchased_train) if grey_trains_bought == @phase3_train_trigger
          super
        end

        def operating_round(round_num = 1)
          @round_num = round_num
          Engine::Round::Operating.new(self, [
            G1858::Step::Track,
            G18CH::Step::Token,
            G1858::Step::Route,
            G1858::Step::Dividend,
            G1858::Step::DiscardTrain,
            G1858::Step::BuyTrain,
            G1858::Step::IssueShares,
          ], round_num: round_num)
        end

        def closure_round(round_num)
          G18CH::Round::Closure.new(self, [
            G1858::Step::ExchangeApproval,
            G1858::Step::HomeToken,
            G1858::Step::PrivateClosure,
          ], round_num: round_num)
        end

        BONUS_HEXES = {
          north: %w[C4 D3 E2 H1 I2],
          south: %w[H15 I16],
          east: %w[L5 L7],
          west: %w[A14 B7],
          revenue_ns: 'B16',
          revenue_ew: 'L16',
        }.freeze

        def revenue_for(route, stops)
          super + north_south_bonus(route, stops) + east_west_bonus(route, stops)
        end

        def private_colors_available(phase)
          if phase.status.include?('yellow_privates')
            %i[yellow]
          elsif phase.status.include?('green_privates')
            %i[yellow green]
          elsif phase.status.include?('all_privates')
            %i[yellow green blue]
          elsif phase.status.include?('blue_privates')
            %i[blue]
          else
            []
          end
        end

        private

        def hexes_by_id(coordinates)
          coordinates.map { |coord| hex_by_id(coord) }
        end

        def r2r_bonus(route, stops, zone1, zone2, bonus)
          @bonus_nodes ||= {
            north: hexes_by_id(BONUS_HEXES[:north]).map(&:tile).flat_map(&:offboards),
            south: hexes_by_id(BONUS_HEXES[:south]).map(&:tile).flat_map(&:offboards),
            east: hexes_by_id(BONUS_HEXES[:east]).map(&:tile).flat_map(&:offboards),
            west: hexes_by_id(BONUS_HEXES[:west]).map(&:tile).flat_map(&:offboards),
          }
          @bonus_revenue ||= {
            north_south: hex_by_id(BONUS_HEXES[:revenue_ns]).tile.offboards.first,
            east_west: hex_by_id(BONUS_HEXES[:revenue_ew]).tile.offboards.first,
          }
          return 0 unless stops.intersect?(@bonus_nodes[zone1])
          return 0 unless stops.intersect?(@bonus_nodes[zone2])

          @bonus_revenue[bonus].route_revenue(@phase, route.train)
        end

        def north_south_bonus(route, stops)
          r2r_bonus(route, stops, :north, :south, :north_south)
        end

        def east_west_bonus(route, stops)
          r2r_bonus(route, stops, :east, :west, :east_west)
        end
      end
    end
  end
end
