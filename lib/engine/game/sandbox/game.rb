# frozen_string_literal: true

require_relative 'meta'
require_relative '../base'

module Engine
  module Game
    module Sandbox
      # This is not a real game. It is a minimal implementation to allow easier
      # testing of the core engine. There are two ways this can be used:
      #
      # 1. A rspec file can create an instance of this game, defining a minimal
      #   map and tile set. Track and tokens can be added to the map and the
      #   core engine features tested. See {file:docs/testing-with-sandbox.md
      #   testing-with-sandbox} for detailed instructions on how to write rspec
      #   tests using this game.
      #
      # 2. A developer can create start a game through the web interface, after
      #   editing the `HEXES` definition in their copy of this file. This game
      #   designed to allow track and tokens to be added to the map with little
      #   effort, there is no need to click through multiple rounds to advance
      #   the game state. Once the map is in the desired state it can be used to
      #   test the features under development.
      class Game < Game::Base
        include_meta(Sandbox::Meta)

        MARKET = [['100p']].freeze
        CERT_LIMIT = 100
        BANK_CASH = 1_000_000
        STARTING_CASH = 1_000

        PHASES = [
          {
            name: '1',
            train_limit: 10,
            tiles: %i[yellow green brown gray],
            operating_rounds: 1,
          },
        ].freeze

        LAYOUT = :flat
        HEXES = {
          white: {
            %w[A3 A7 A9 B2 B4 B6 B10 C3 C7 C9 D2 D4 D6 D8 D10
               E1 E5 E9 F2 F4 F6 F10 G1 G7 G9 H2 H4 H6 H8 H10] => '',
            %w[A1 A5 C1 C5] => 'city=revenue:0;',
            %w[E7] => 'city=revenue:0;city=revenue:0;label=OO;',
            %w[G3] => 'city=revenue:0;label=Y;',
            %w[B8 F8 G5] => 'town=revenue:0;',
            %w[E3] => 'town=revenue:0;town=revenue:0;',
          },
        }.freeze

        TILES = Config::Tile::YELLOW
          .merge(Config::Tile::GREEN, Config::Tile::BROWN, Config::Tile::GRAY)
          .transform_values { |_| 'unlimited' }
          .freeze

        TILE_LAYS = Array.new(100, { lay: true, upgrade: true, cost: 0 }).freeze
        TRACK_RESTRICTION = :permissive

        # @param players [Array<String>] Player names forwarded to Game::Base.
        # @param hexes [Hash, nil] Custom hex definitions in the same format as
        #   the {Engine::Game::Base::HEXES HEXES} constant. When nil, defaults
        #   to self.class::HEXES.
        # @param tiles [Hash, nil] custom tile definitions in the same format as
        #   TILES constant. When nil, defaults to self.class::TILES.
        # @param corporations [Array<Hash>, nil] Custom corporation definitions
        #   in the same format as the CORPORATIONS constant, forwarded to the
        #   {Engine::Corporation Corporation} constructor (each hash may include
        #   an `abilities:` key for token/teleport abilities). When nil, defaults
        #   to self.class::CORPORATIONS.
        # @param kwargs [Hash] Additional keyword arguments forwarded to
        #   Game::Base.
        # @note Future enhancements could involve adding more parameters that
        #   allow custom companies, corporations and trains to be passed as
        #   arguments to the constructor.
        def initialize(players, hexes: nil, tiles: nil, corporations: nil, **kwargs)
          @custom_hexes = hexes
          @custom_tiles = tiles
          @custom_corporations = corporations
          super(players, **kwargs)
        end

        # @return [Hash] Hex layout used when building the map. Returns the custom
        #   hexes passed to the constructor, or self.class::HEXES as a fallback.
        def game_hexes
          @custom_hexes || self.class::HEXES
        end

        # @return [Hash] Tile definitions used when populating the tile pool. Returns
        #   the custom tiles passed to the constructor, or self.class::TILES as a
        #   fallback.
        def game_tiles
          @custom_tiles || self.class::TILES
        end

        # @return [Array<Hash>] Corporation definitions used to build the
        #   {Engine::Corporation Corporation} objects. Returns the custom
        #   corporations passed to the constructor, or self.class::CORPORATIONS
        #   as a fallback.
        def game_corporations
          @custom_corporations || self.class::CORPORATIONS
        end

        CORPORATIONS = [
          {
            name: 'Alpha',
            sym: 'α',
            logo: 'sandbox/alpha',
            tokens: Array.new(10, 0),
            color: 'red',
            shares: [100],
            float_percent: 100,
            max_ownership_percent: 100,
          },
          {
            name: 'Bravo',
            sym: 'β',
            logo: 'sandbox/beta',
            tokens: Array.new(10, 0),
            color: 'green',
            shares: [100],
            float_percent: 100,
            max_ownership_percent: 100,
          },
          {
            name: 'Gamma',
            sym: 'γ',
            logo: 'sandbox/gamma',
            tokens: Array.new(10, 0),
            color: 'blue',
            shares: [100],
            float_percent: 100,
            max_ownership_percent: 100,
          },
        ].freeze

        TRAINS = [
          {
            name: '4',
            distance: 6,
            price: 1,
            num: 'unlimited',
            variants: [
              {
                name: '3+3',
                distance: [{ 'nodes' => %w[town], 'pay' => 3, 'visit' => 3 },
                           { 'nodes' => %w[city offboard town], 'pay' => 3, 'visit' => 3 }],
                price: 1,
              },
              {
                name: 'D',
                distance: 999,
                price: 1,
              },
            ],
          },
        ].freeze

        def stock_round
          Round::Stock.new(self, [
            Step::BuySellParShares,
          ])
        end

        def operating_round(round_num)
          Round::Operating.new(self, [
            Step::HomeToken,
            Step::TrackAndToken,
            Step::BuyTrain,
            Step::Route,
            Step::Dividend,
          ], round_num: round_num)
        end

        def init_round
          stock_round
        end

        def home_token_locations(corporation)
          hexes.select do |hex|
            hex.tile.cities.any? { |city| city.tokenable?(corporation, free: true) }
          end
        end
      end
    end
  end
end
