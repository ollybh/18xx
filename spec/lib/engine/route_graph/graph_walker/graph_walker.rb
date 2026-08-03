# frozen_string_literal: true

module Engine
  module RouteGraph
    # Tests of basic GraphWalker functionality.
    #
    # A GraphWalker subclass spec can use these tests by including the context
    # and the example groups, overriding `subject(:walker)` as needed:
    #   describe MyWalker, :graph do
    #     include_context 'GraphWalker spec setup'
    #     subject(:walker) { MyWalker.new(graph, alpha) }
    #     it_behaves_like 'a GraphWalker'
    #   end
    shared_examples 'a GraphWalker' do
      include_context 'GraphWalker spec setup'

      describe '#departure_blocked?' do
        let(:hexes) { { white: { %w[A1 A3 A5 B2 B6] => '' } } }
        let(:tiles) { { '5' => 1, '9' => 1, '6' => 1 } }

        before :each do
          lay_tile('A1', '5', 0)
          a1_city = hex('A1').tile.cities.first
          a1_city.place_token(alpha, alpha.tokens.first, free: true)
        end

        it 'blocks immediate reversal through the same edge' do
          edge = graph.edges.first
          vertex = edge.left
          expect(walker.send(:departure_blocked?, vertex, edge, edge)).to be true
        end

        it 'allows departure to a different edge from a city' do
          # The city has 2 edges; pick one as incoming and the other as outgoing.
          city_vertex = graph.vertices.find { |v| v.is_a?(NodeVertex) }
          edges = city_vertex.edges.to_a
          expect(edges.size).to be >= 2
          expect(walker.send(:departure_blocked?, city_vertex, edges[0], edges[1])).to be false
        end
      end

      describe '#connected_nodes' do
        let(:hexes) { { white: { %w[A1 A3 A5] => '' } } }
        let(:tiles) { { '5' => 1, '6' => 1, '9' => 1 } }
        let(:a1_city) { hex('A1').tile.cities.first }
        let(:a5_city) { hex('A5').tile.cities.first }

        before :each do
          lay_tile('A1', '5', 0)
          lay_tile('A3', '9', 0)
          lay_tile('A5', '6', 3)
          a1_city.place_token(alpha, alpha.tokens.first, free: true)
        end

        it 'finds connected nodes when walking from a token' do
          expect(walker.connected_nodes.map(&:node)).to match_array([a1_city, a5_city])
        end

        it 'finds no connected nodes when no token is placed' do
          beta = game.corporation_by_id('β')
          walker = Engine::RouteGraph::GraphWalker.new(graph, beta)
          expect(walker.connected_nodes).to be_empty
        end
      end
    end
  end
end
