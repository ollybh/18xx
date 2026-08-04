# frozen_string_literal: true

module Engine
  module RouteGraph
    # Tests to make sure terminal junction is handled correctly.
    #
    # A GraphWalker subclass spec can use these tests by including the context
    # and the example groups, overriding `subject(:walker)` as needed:
    #   describe MyWalker, :graph do
    #     include_context 'GraphWalker spec setup'
    #     subject(:walker) { MyWalker.new(graph, alpha) }
    #     it_behaves_like 'a GraphWalker on terminal track'
    #   end

    shared_context 'with terminal track' do
      # A map with:
      #  - A normal city in A1.
      #  - An offboard city in A7, whose track connections are terminal.
      #  - A sea area in B4, its track connections are also terminal.
      # It should be possible to trace routes into and out of the A7 city, but
      # not through it. Routes cannot be traced into or through B4.
      let(:hexes) do
        {
          white: {
            %w[A3 A5 B2 B4 B6] => '',
            %w[A1] => 'city=revenue:0;',
          },
          blue: {
            %w[B4] => 'junction;' \
                      'path=a:_0,b:0,terminal:2;' \
                      'path=a:_0,b:1,terminal:2;' \
                      'path=a:_0,b:2,terminal:2;' \
                      'path=a:_0,b:3,terminal:2;',
          },
          red: {
            %w[A7] => 'city=revenue:20;' \
                      'path=a:_0,b:3,terminal:1;' \
                      'path=a:_0,b:4,terminal:1;',
          },
        }
      end
      let(:tiles) { { '5' => 1, '8' => 2, '9' => 2 } }
      let(:a1_city) { hex('A1').tile.cities.first }
      let(:a7_city) { hex('A7').tile.cities.first }

      before do
        lay_tile('A1', '5', 5, 0)
        lay_tile('A3', '9', 0, 0)
        lay_tile('A5', '9', 0, 1)
        lay_tile('B2', '8', 0, 0)
        lay_tile('B6', '8', 1, 1)
      end
    end

    shared_examples 'a GraphWalker on terminal track' do
      include_context 'with terminal track'

      describe 'approaching terminal track' do
        before do
          a1_city.place_token(alpha, alpha.next_token, free: true)
        end

        it 'cannot reach impassable hex B4' do
          expect(walker.reachable_hexes).not_to include(hex('B4'))
        end

        it 'can reach city in A7' do
          expect(walker.connected_nodes.map(&:node)).to include(a7_city)
        end

        it 'cannot reach hex B6 through city in A7 or impassable hex B4' do
          expect(walker.reachable_hexes).not_to include(hex('B6'))
        end
      end

      describe 'leaving terminal track' do
        before do
          a7_city.place_token(alpha, alpha.next_token, free: true)
        end

        it 'cannot reach impassable hex B4' do
          expect(walker.reachable_hexes).not_to include(hex('B4'))
        end

        it 'can reach city in A1' do
          expect(walker.connected_nodes.map(&:node)).to include(a1_city)
        end

        it 'can reach hex B6' do
          expect(walker.reachable_hexes).to include(hex('B6'))
        end
      end
    end
  end
end
