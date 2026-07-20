# frozen_string_literal: true

require 'spec_helper'

module Engine
  module RouteGraph
    describe HexExit, :graph do
      # Use the sandbox game with a tile laid on A1 so we have real exits.
      let(:sandbox) do
        g = Game::Sandbox::Game.new(%w[Alice])
        tile = g.tile_by_id('9-0')
        tile.rotate!(0)
        g.hex_by_id('A1').lay(tile)
        g
      end
      let(:hex_a1) { sandbox.hex_by_id('A1') }
      let(:hex_a3) { sandbox.hex_by_id('A3') }
      # A tile 9 (straight north–south) has two edges: edge 0 and edge 3.
      let(:exit_edge_0) { hex_a1.tile.edges.find { |e| e.num == 0 } }

      describe '.from_edge' do
        it 'computes lane offset for a single lane' do
          exit_point = HexExit.from_edge(exit_edge_0, 1, 0)
          expect(exit_point.lane_offset).to eq(0)
        end

        it 'computes lane offset for lane 0 of a dual lane' do
          exit_point = HexExit.from_edge(exit_edge_0, 2, 0)
          expect(exit_point.lane_offset).to eq(1)
        end

        it 'computes lane offset for lane 1 of a dual lane' do
          exit_point = HexExit.from_edge(exit_edge_0, 2, 1)
          expect(exit_point.lane_offset).to eq(-1)
        end

        it 'computes lane offset for lane 0 of three lanes' do
          exit_point = HexExit.from_edge(exit_edge_0, 3, 0)
          expect(exit_point.lane_offset).to eq(2)
        end

        it 'computes lane offset for lane 1 of three lanes' do
          exit_point = HexExit.from_edge(exit_edge_0, 3, 1)
          expect(exit_point.lane_offset).to eq(0)
        end

        it 'computes lane offset for lane 2 of three lanes' do
          exit_point = HexExit.from_edge(exit_edge_0, 3, 2)
          expect(exit_point.lane_offset).to eq(-2)
        end
      end

      describe '#adjacent_hex' do
        it 'returns the neighbor at the same edge' do
          exit_point = HexExit.new(hex_a1, 0, 0)
          expect(exit_point.adjacent_hex).to eq(hex_a3)
        end

        it 'returns nil when there is no adjacent hex' do
          exit_point = HexExit.new(hex_a1, 1, 0)
          expect(exit_point.adjacent_hex).to be_nil
        end
      end

      describe '#connects_to?' do
        it 'returns true for matching exits on adjacent hexes' do
          left_exit  = HexExit.new(hex_a1, 0, 0)
          right_exit = HexExit.new(hex_a3, 3, 0)
          expect(left_exit).to be_connects_to(right_exit)
        end

        it 'returns false when the other hex is not adjacent' do
          left_exit  = HexExit.new(hex_a1, 0, 0)
          far_exit   = HexExit.new(hex_a1, 2, 0)
          expect(left_exit).not_to be_connects_to(far_exit)
        end

        it 'returns false when edges do not align' do
          left_exit  = HexExit.new(hex_a1, 0, 0)
          wrong_edge = HexExit.new(hex_a3, 0, 0)
          expect(left_exit).not_to be_connects_to(wrong_edge)
        end

        it 'returns false when lane offsets do not invert' do
          left_exit = HexExit.new(hex_a1, 0, 1)
          same_sign = HexExit.new(hex_a3, 3, 1)
          expect(left_exit).not_to be_connects_to(same_sign)
        end

        it 'matches exits with opposite lane offsets' do
          left_exit  = HexExit.new(hex_a1, 0, 1)
          right_exit = HexExit.new(hex_a3, 3, -1)
          expect(left_exit).to be_connects_to(right_exit)
        end
      end

      describe '#adjacent_exit' do
        it 'returns a HexExit with inverted lane offset' do
          exit_point = HexExit.new(hex_a1, 0, 1)
          adjacent = exit_point.adjacent_exit
          expect(adjacent.hex).to eq(hex_a3)
          expect(adjacent.edge).to eq(3)
          expect(adjacent.lane_offset).to eq(-1)
        end

        it 'returns nil at the edge of the map' do
          exit_point = HexExit.new(hex_a1, 1, 0)
          expect(exit_point.adjacent_exit).to be_nil
        end
      end

      describe '#id' do
        it 'includes hex coordinates, edge and lane_offset' do
          exit_point = HexExit.new(hex_a1, 0, 1)
          expect(exit_point.id).to eq('A1_0_1')
        end
      end
    end

    describe HexEdgeCrossing, :graph do
      # Tile 5 (city at edges 0,1) laid on A1 gives an interior edge at 0
      # (toward A3) and a map-edge at 1 (south-west, off the map).
      let(:sandbox) do
        g = Game::Sandbox::Game.new(%w[Alice])
        tile = g.tile_by_id('5-0')
        tile.rotate!(0)
        g.hex_by_id('A1').lay(tile)
        g
      end
      let(:hex_a1) { sandbox.hex_by_id('A1') }
      let(:exit_edge_0) { hex_a1.tile.edges.find { |e| e.num == 0 } }
      let(:exit_edge_1) { hex_a1.tile.edges.find { |e| e.num == 1 } }

      describe '#initialize' do
        it 'creates a crossing with both exits for an interior edge' do
          crossing = HexEdgeCrossing.new(exit_edge_0, 1, 0)
          expect(crossing.exits.size).to eq(2)
        end

        it 'creates a crossing with one exit at the map edge' do
          crossing = HexEdgeCrossing.new(exit_edge_1, 1, 0)
          expect(crossing.exits.size).to eq(1)
        end
      end

      describe '#id' do
        it 'joins exit ids with a pipe' do
          crossing = HexEdgeCrossing.new(exit_edge_0, 1, 0)
          expect(crossing.id).to include('|')
        end
      end
    end
  end
end
