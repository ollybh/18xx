# frozen_string_literal: true

require 'spec_helper'

module Engine
  module Game
    module Sandbox
      describe Game do
        # ---------- default construction ----------
        context 'with default arguments' do
          subject(:game) { described_class.new(%w[Alice Bob]) }

          it 'creates hexes from the HEXES constant' do
            # The default map has hex A1, B6, E7, G3 plus ~40 white blanks.
            expect(game.hex_by_id('A1')).to be_a(Hex)
            expect(game.hex_by_id('B6')).to be_a(Hex)
            expect(game.hex_by_id('E7')).to be_a(Hex)
            expect(game.hex_by_id('G3')).to be_a(Hex)
          end

          it 'creates tiles from the TILES constant' do
            expect(game.tile_by_id('5-0')).to be_a(Tile)
            expect(game.tile_by_id('9-0')).to be_a(Tile)
          end

          it 'has three corporations' do
            expect(game.corporations.size).to eq(3)
          end

          it 'has the correct layout' do
            expect(game.layout).to eq(:flat)
          end
        end

        # ---------- custom hexes ----------
        context 'with custom hexes' do
          let(:tiny_hexes) do
            {
              white: {
                %w[A1 A3] => '',
                %w[B2] => 'city=revenue:0;',
              },
            }
          end

          subject(:game) { described_class.new(%w[Alice Bob], hexes: tiny_hexes) }

          it 'uses the custom hexes instead of the default HEXES' do
            expect(game.hex_by_id('A1')).to be_a(Hex)
            expect(game.hex_by_id('B2')).to be_a(Hex)
          end

          it 'does not include hexes from the default HEXES' do
            expect(game.hex_by_id('E7')).to be_nil
            expect(game.hex_by_id('G3')).to be_nil
          end

          it 'still loads default tiles' do
            expect(game.tile_by_id('5-0')).to be_a(Tile)
          end
        end

        # ---------- custom tiles ----------
        context 'with custom tiles' do
          # Use a tile name known to Tile.for (e.g. '5') so 'unlimited' works.
          # The Sandbox default TILES transforms all Config::Tile values
          # to 'unlimited', so supplying a subset keeps only those tiles.
          let(:custom_tiles) do
            { '5' => 'unlimited', '9' => 'unlimited' }
          end

          subject(:game) { described_class.new(%w[Alice Bob], tiles: custom_tiles) }

          it 'uses the custom tiles instead of the default TILES' do
            expect(game.tile_by_id('5-0')).to be_a(Tile)
            expect(game.tile_by_id('9-0')).to be_a(Tile)
          end

          it 'does not include tiles absent from the custom set' do
            expect(game.tile_by_id('6-0')).to be_nil
            expect(game.tile_by_id('7-0')).to be_nil
          end

          it 'still loads default hexes' do
            expect(game.hex_by_id('A1')).to be_a(Hex)
          end
        end

        context 'with explicit integer count (>1) for a known tile' do
          let(:custom_tiles) do
            { '5' => 3 }
          end

          subject(:game) { described_class.new(%w[Alice Bob], tiles: custom_tiles) }

          it 'creates the requested number of copies' do
            expect(game.tile_by_id('5-0')).to be_a(Tile)
            expect(game.tile_by_id('5-1')).to be_a(Tile)
            expect(game.tile_by_id('5-2')).to be_a(Tile)
          end

          it 'does not create copies beyond the requested count' do
            expect(game.tile_by_id('5-3')).to be_nil
          end

          it 'does not include default tiles' do
            expect(game.tile_by_id('6-0')).to be_nil
            expect(game.tile_by_id('9-0')).to be_nil
          end
        end

        context 'with multiple copies via code hash' do
          # Truly novel tile names use a Hash value. count: 3 means three
          # copies (indices 0, 1, 2).
          let(:custom_tiles) do
            {
              'X' => {
                'count' => 3,
                'color' => 'yellow',
                'code' => 'city=revenue:10;path=a:0,b:_0;path=a:1,b:_0',
              },
            }
          end

          subject(:game) { described_class.new(%w[Alice Bob], tiles: custom_tiles) }

          it 'creates the requested number of copies' do
            expect(game.tile_by_id('X-0')).to be_a(Tile)
            expect(game.tile_by_id('X-1')).to be_a(Tile)
            expect(game.tile_by_id('X-2')).to be_a(Tile)
          end

          it 'does not create copies beyond the requested count' do
            expect(game.tile_by_id('X-3')).to be_nil
          end

          it 'does not include default tiles' do
            expect(game.tile_by_id('5-0')).to be_nil
          end
        end

        context 'with a single copy via code hash' do
          let(:custom_tiles) do
            {
              'Y' => {
                'count' => 1,
                'color' => 'yellow',
                'code' => 'path=a:0,b:3',
              },
            }
          end

          subject(:game) { described_class.new(%w[Alice Bob], tiles: custom_tiles) }

          it 'creates a tile from a custom code hash' do
            expect(game.tile_by_id('Y-0')).to be_a(Tile)
          end

          it 'does not include default tiles' do
            expect(game.tile_by_id('5-0')).to be_nil
          end
        end

        # ---------- custom hexes AND tiles ----------
        context 'with both custom hexes and tiles' do
          let(:tiny_hexes) do
            {
              white: {
                %w[C3 C5] => '',
                %w[D4] => 'city=revenue:0;',
              },
            }
          end

          # Tile 'Z' defined via code hash. Two copies so both C3 and C5
          # can receive one (matching the doc example).
          let(:custom_tiles) do
            {
              'Z' => {
                'count' => 2,
                'color' => 'yellow',
                'code' => 'path=a:0,b:3',
              },
            }
          end

          subject(:game) { described_class.new(%w[Alice], hexes: tiny_hexes, tiles: custom_tiles) }

          it 'creates hexes from the custom set' do
            expect(game.hex_by_id('C3')).to be_a(Hex)
            expect(game.hex_by_id('D4')).to be_a(Hex)
          end

          it 'creates the requested number of tile copies' do
            expect(game.tile_by_id('Z-0')).to be_a(Tile)
            expect(game.tile_by_id('Z-1')).to be_a(Tile)
            expect(game.tile_by_id('Z-2')).to be_nil # only 2 copies
          end

          it 'excludes default hexes' do
            expect(game.hex_by_id('A1')).to be_nil
          end

          it 'excludes default tiles' do
            expect(game.tile_by_id('5-0')).to be_nil
          end

          it 'allows tiles to be laid on multiple custom hexes' do
            h1 = game.hex_by_id('C3')
            h2 = game.hex_by_id('C5')
            t1 = game.tile_by_id('Z-0')
            t2 = game.tile_by_id('Z-1')
            t1.rotate!(0)
            t2.rotate!(0)
            h1.lay(t1)
            h2.lay(t2)

            expect(h1.tile.exits).to include(0, 3)
            expect(h2.tile.exits).to include(0, 3)
          end
        end

        # ---------- edge cases ----------
        context 'with empty hexes hash' do
          subject(:game) { described_class.new(%w[Alice], hexes: {}) }

          it 'produces no hexes' do
            expect(game.hexes).to be_empty
          end

          it 'still loads default tiles' do
            expect(game.tile_by_id('5-0')).to be_a(Tile)
          end
        end

        context 'with empty tiles hash' do
          subject(:game) { described_class.new(%w[Alice], tiles: {}) }

          it 'produces no tiles' do
            expect(game.tiles).to be_empty
          end

          it 'still loads default hexes' do
            expect(game.hex_by_id('A1')).to be_a(Hex)
          end
        end

        # ---------- custom corporations ----------
        context 'with custom corporations' do
          let(:custom_corporations) do
            [
              {
                name: 'Alpha Corporation',
                sym: 'α',
                logo: 'sandbox/alpha',
                tokens: Array.new(10, 0),
                color: 'red',
                shares: [100],
                float_percent: 100,
                max_ownership_percent: 100,
              },
            ]
          end

          subject(:game) { described_class.new(%w[Alice Bob], corporations: custom_corporations) }

          it 'uses the custom corporations instead of the default CORPORATIONS' do
            expect(game.corporations.size).to eq(1)
            corp = game.corporation_by_id('α')
            expect(corp).to be_a(Corporation)
            expect(corp.full_name).to eq('Alpha Corporation')
          end

          it 'does not include corporations from the default CORPORATIONS' do
            expect(game.corporation_by_id('β')).to be_nil
            expect(game.corporation_by_id('γ')).to be_nil
          end

          it 'still loads default hexes' do
            expect(game.hex_by_id('A1')).to be_a(Hex)
          end

          it 'still loads default tiles' do
            expect(game.tile_by_id('5-0')).to be_a(Tile)
          end
        end

        context 'with custom corporations carrying abilities' do
          let(:custom_corporations) do
            [
              {
                name: 'Teleporter',
                sym: 'α',
                logo: 'sandbox/alpha',
                tokens: Array.new(10, 0),
                color: 'red',
                shares: [100],
                float_percent: 100,
                max_ownership_percent: 100,
                abilities: [
                  { type: 'token', hexes: ['A1'], price: 0, teleport_price: 0 },
                  { type: 'reservation', hex: 'A1', remove: 'IV' },
                ],
              },
            ]
          end

          subject(:game) { described_class.new(%w[Alice Bob], corporations: custom_corporations) }

          it 'attaches the abilities to the corporation' do
            corp = game.corporation_by_id('α')
            expect(corp.all_abilities.map(&:type)).to include(:token, :reservation)
          end

          it 'assigns the corporation as the ability owner' do
            corp = game.corporation_by_id('α')
            token_ability = corp.all_abilities.find { |a| a.type == :token }
            expect(token_ability.owner).to eq(corp)
          end

          it 'makes the abilities discoverable via game.abilities(corp, :token)' do
            corp = game.corporation_by_id('α')
            found = nil
            game.abilities(corp, :token) { |ability, owner| found = [ability, owner] }
            expect(found).not_to be_nil
            expect(found[0].type).to eq(:token)
            expect(found[1]).to eq(corp)
          end
        end

        context 'with an empty corporations array' do
          subject(:game) { described_class.new(%w[Alice], corporations: []) }

          it 'produces no corporations' do
            expect(game.corporations).to be_empty
          end

          it 'still loads default hexes' do
            expect(game.hex_by_id('A1')).to be_a(Hex)
          end
        end

        context 'with explicit nil corporations (defaults to constant)' do
          subject(:game) { described_class.new(%w[Alice], corporations: nil) }

          it 'falls back to the CORPORATIONS constant' do
            expect(game.corporations.size).to eq(3)
            expect(game.corporation_by_id('α')).to be_a(Corporation)
          end
        end
      end
    end
  end
end
