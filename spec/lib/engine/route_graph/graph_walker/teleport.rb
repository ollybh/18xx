# frozen_string_literal: true

module Engine
  module RouteGraph
    # Tests to make sure teleport token abilities are handled correctly.
    #
    # A GraphWalker subclass spec can use these tests by including the context
    # and the example groups, overriding `subject(:walker)` as needed:
    #   describe MyWalker, :graph do
    #     include_context 'GraphWalker spec setup'
    #     subject(:walker) { MyWalker.new(graph, alpha) }
    #     it_behaves_like 'a GraphWalker with teleport token abilities'
    #   end
    shared_examples 'a GraphWalker with teleport token abilities' do
      # Hex A1 is Alpha's home; A5 is an isolated city with no track connecting
      # it. Alpha gains a `:token` ability with a `teleport_price`, so its
      # destination city is added to the walker's result set even though no walk
      # can reach it. Mirrors the corp-direct `:token` teleports in 1846 /
      # 18_LA / 18_MO, and matches Engine::Graph#compute, which reads the same
      # `game.abilities(entity, :token)` gate (§2.6).
      let(:hexes) do
        {
          white: {
            %w[A1] => 'city=revenue:0;',
            %w[A5] => 'city=revenue:0;',
          },
        }
      end
      let(:tiles) { {} }
      let(:corporations) do
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
            abilities: [
              { type: 'token', hexes: %w[A5], price: 0, teleport_price: 0 },
            ],
          },
        ]
      end
      let(:a5_city) { hex('A5').tile.cities.first }
      let(:a5_hex) { hex('A5') }

      before do
        hex('A1').tile.cities.first.place_token(alpha, alpha.tokens.first, free: true)
      end

      it 'lists the destination city in teleport_nodes' do
        expect(walker.send(:teleport_nodes)).to contain_exactly(a5_city)
      end

      it 'includes the destination city in connected_nodes' do
        expect(walker.connected_nodes).to include(a5_city)
      end

      it 'does not add the destination hex to connected_hexes' do
        # A :token teleport adds destination cities to `connected_nodes` only;
        # the hex itself is not added to `connected_hexes`.
        expect(walker.connected_hexes).not_to have_key(a5_hex)
      end

      it 'does not treat the destination as reachable by track' do
        expect(walker.reachable_hexes).not_to include(a5_hex)
      end
    end
  end
end
