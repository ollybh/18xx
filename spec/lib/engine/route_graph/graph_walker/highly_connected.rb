# frozen_string_literal: true

module Engine
  module RouteGraph
    # Tests using maps with many Lawson-type junctions or converging junctions.
    #
    # A GraphWalker subclass spec can use these tests by including the context
    # and the example groups, overriding `subject(:walker)` as needed:
    #   describe MyWalker, :graph do
    #     include_context 'GraphWalker spec setup'
    #     subject(:walker) { MyWalker.new(graph, alpha) }
    #     it_behaves_like 'a GraphWalker on highly connected maps'
    #   end
    shared_examples 'a GraphWalker on highly connected maps' do
      include_context 'GraphWalker spec setup'

      describe 'on a highly connected map with Lawson tiles' do
        let(:hexes) { { white: { %w[A3 A5 A7 B2 B4 B6 B8 C1 C3 C5 C7 C9 D2 D4 D6 D8 E3 E5 E7] => '' } } }
        let(:tiles) { { '12' => 2, '60' => 7, '80' => 4, '545' => 6 } }

        before :each do
          lay_tile('C1', '12',  5, 0)
          lay_tile('C9', '12',  2, 1)
          lay_tile('A3', '80',  4, 0)
          lay_tile('A7', '80',  3, 1)
          lay_tile('E3', '80',  0, 2)
          lay_tile('E7', '80',  1, 3)
          %w[B4 B6 C3 C5 C7 D4 D6].each_with_index { |hex, i| lay_tile(hex, '60',  0, i) }
          %w[E5 D8 B8 A5 B2 D2].each_with_index    { |hex, i| lay_tile(hex, '545', i, i) }
          hex('C1').tile.cities.first.place_token(alpha, alpha.next_token, free: true)
        end

        it 'can reach all hexes' do
          all_hexes = hexes.map { |_color, hexdefs| hexdefs.keys }.flatten
          expect(walker.reachable_hexes.map(&:coordinates)).to match_array(all_hexes)
        end

        it 'can reach all paths' do
          all_paths = game.hexes.map(&:tile).flat_map(&:paths)
          expect(walker.connected_paths).to match_array(all_paths)
        end
      end

      describe 'on a highly connected map with converging junctions' do
        let(:hexes) { { white: { %w[A3 A5 A7 B2 B4 B6 B8 C1 C3 C5 C7 C9 D2 D4 D6 D8 E3 E5 E7] => '' } } }
        let(:tiles) { { '12' => 2, '39' => 4, '43' => 6, '114' => 7 } }

        before :each do
          lay_tile('C1', '12',  5, 0)
          lay_tile('C9', '12',  2, 1)
          lay_tile('A3', '39',  4, 0)
          lay_tile('A7', '39',  3, 1)
          lay_tile('E3', '39',  0, 2)
          lay_tile('E7', '39',  1, 3)
          %w[B4 B6 C3 C5 C7 D4 D6].each_with_index { |hex, i| lay_tile(hex, '114', 0, i) }
          %w[E5 D8 B8 A5 B2 D2].each_with_index    { |hex, i| lay_tile(hex, '43',  i, i) }
          hex('C1').tile.cities.first.place_token(alpha, alpha.next_token, free: true)
        end

        it 'can reach all hexes' do
          all_hexes = hexes.map { |_color, hexdefs| hexdefs.keys }.flatten
          expect(walker.reachable_hexes.map(&:coordinates)).to match_array(all_hexes)
        end

        it 'can reach all paths' do
          all_paths = game.hexes.map(&:tile).flat_map(&:paths)
          expect(walker.connected_paths).to match_array(all_paths)
        end
      end
    end
  end
end
