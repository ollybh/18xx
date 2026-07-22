# frozen_string_literal: true

require 'spec_helper'

module Engine
  module RouteGraph
    describe GraphWalker, :graph do
      test_hexes = {
        white: {
          %w[A1 A3 A5 B2 B6] => '',
        },
      }

      test_tiles = {
        '5' => 1,
        '9' => 1,
        '6' => 1,
      }

      let(:players) { %w[Alice Bob Charlie] }
      let(:game) { Game::Sandbox::Game.new(players, hexes: test_hexes, tiles: test_tiles) }

      def hex(id)
        game.hex_by_id(id)
      end

      def tile(name, index = 0)
        game.tile_by_id("#{name}-#{index}")
      end

      def lay_tile(hex_id, tile_name, rotation = 0, index = 0)
        h = hex(hex_id)
        t = tile(tile_name, index)
        t.rotate!(rotation)
        h.lay(t)
      end

      subject(:graph) { game.route_graph }

      describe '#can_traverse?' do
        let(:alpha) { game.corporations.find { |c| c.id == 'α' } }

        before :each do
          lay_tile('A1', '5', 0)
          a1_city = hex('A1').tile.cities.first
          a1_city.place_token(alpha, alpha.tokens.first, free: true)
        end

        it 'blocks immediate reversal through the same edge' do
          walker = game.graph_walker(alpha)
          edge = graph.edges.first
          vertex = edge.left
          expect(walker.send(:can_traverse?, vertex, edge, edge)).to be false
        end

        it 'allows traversal to a different edge from a city' do
          walker = game.graph_walker(alpha)
          # The city has 2 edges; pick one as incoming and the other as outgoing.
          city_vertex = graph.vertices.find { |v| v.is_a?(NodeVertex) }
          edges = city_vertex.edges.to_a
          expect(edges.size).to be >= 2
          expect(walker.send(:can_traverse?, city_vertex, edges[0], edges[1])).to be true
        end
      end

      describe '#connected_nodes with converging junction reversal guard' do
        # Tile 29 at B2 creates a converging junction: its two paths both
        # meet at the southern edge (edge 0), which connects to B4. After
        # join_edges!, the HexEdgeVertex at B2_0_0|B4_3_0 has 3 incident
        # edges (to A1, A3, and B4) and cannot be merged.
        #
        # Without the from_edge == to_edge guard in can_traverse?, a walk
        # from A1 could reach B4, then reverse direction back through the
        # same edge (E2) to the junction, and from there take the other
        # path to A3 — giving the illusion that A3 is reachable.
        #
        # Layout:
        #
        #   A1 (115 rot 5, city e5→B2)
        #          \
        #    A3──── B2 (29 rot 0, e2→A1 + e1→A3 + e0→B4)
        #              \
        #               B4 (115 rot 3, city e3→B2)
        #
        # With the guard, the walk terminates at B4 and never finds A3.

        let(:game) do
          hexes = { white: { %w[A1 A3 B2 B4] => '' } }
          tiles = { '115' => 3, '29' => 1 }
          Game::Sandbox::Game.new(players, hexes: hexes, tiles: tiles)
        end

        let(:alpha) { game.corporations.find { |c| c.id == 'α' } }

        before :each do
          lay_tile('A1', '115', 5, 0)
          lay_tile('B2', '29', 0, 0)
          lay_tile('B4', '115', 3, 1)
          lay_tile('A3', '115', 4, 2)

          a1_city = hex('A1').tile.cities.first
          a1_city.place_token(alpha, alpha.tokens.first, free: true)
        end

        it 'does not reach A3 from A1 via the converging junction and B4' do
          walker = game.graph_walker(alpha)
          a3_city_id = hex('A3').tile.cities.first.id
          expect(walker.connected_nodes.map(&:id)).not_to include(a3_city_id)
        end

        it 'reaches B4 (the dead-end city)' do
          walker = game.graph_walker(alpha)
          b4_city_id = hex('B4').tile.cities.first.id
          expect(walker.connected_nodes.map(&:id)).to include(b4_city_id)
        end
      end

      describe '#connected_nodes' do
        let(:alpha) { game.corporations.find { |c| c.id == 'α' } }

        before :each do
          lay_tile('A1', '5', 0)
          lay_tile('A3', '9', 0)
          lay_tile('A5', '6', 3)
          a1_city = hex('A1').tile.cities.first
          a1_city.place_token(alpha, alpha.tokens.first, free: true)
        end

        it 'finds connected nodes when walking from a token' do
          walker = game.graph_walker(alpha)
          expect(walker.connected_nodes.map(&:id))
            .to contain_exactly('5-0-0', '6-0-0')
        end

        context 'when no token is placed' do
          it 'finds no connected nodes' do
            beta = game.corporations.find { |c| c.id == 'β' }
            walker = game.graph_walker(beta)
            expect(walker.connected_nodes).to be_empty
          end
        end
      end

      describe '#connected_paths with converging plain-track exits', :comparison do
        # Tile 23: path=a:0,b:3;path=a:0,b:4 — two paths that converge at
        # edge 0.  The walk order in the old Engine::Graph reaches Path 2
        # (a:0,b:4) from B2's side only after Path 1 (a:0,b:3) has already
        # crossed edge A3-0 (to A5).  Because Path 2 shares edge A3-0, the
        # old walker's edge-counter check
        #
        #   return if edges.sum { |edge| counter[edge.id] }.positive?
        #
        # fires — counter["A3-0"] is already 1 from the Path 1 traversal
        # — and Path 2 is never yielded.  The new RouteGraph merges both
        # paths into a single edge that spans A3↔B2 via the shared hex-edge
        # vertex at A3/A5, so the walker traverses the full segment and
        # Path 2 appears in connected_paths.
        #
        # Hex layout (flat):
        #
        #   A1 (0,0)  — tile 115 rot 0, city path to edge 0 (S → A3)
        #     |
        #   A3 (0,2)  — tile 23 rot 0, paths: e3↔e0 (N↔S, to A1↔A5) and
        #     |  \                      e0↔e4 (S↔NW, to A5↔B2)
        #   A5 (0,4)  — tile 5 rot 3, city paths to e3 (N → A3) and
        #     |  \                      e4 (NW → B4)
        #   B2 (1,1)  — tile 7 rot 0, curve e1 (SE → A3) ↔ e0 (S → B4)
        #   B4 (1,3)  — tile 6 rot 1, city paths to e1 (SE → A5) and
        #                           e3 (N → B2)
        #
        # Alpha has a token on A1's city.  From there the walker can reach:
        #   - A5's city (via A3's north-south path)
        #   - B4's city (via A3's converging curve → B2)

        let(:converging_hexes) do
          { white: { %w[A1 A3 A5 B2 B4] => '' } }
        end

        let(:converging_tiles) do
          { '5' => 1, '6' => 1, '7' => 1, '23' => 1, '115' => 1 }
        end

        let(:game) { Game::Sandbox::Game.new(players, hexes: converging_hexes, tiles: converging_tiles) }

        before :each do
          lay_tile('A1', '115', 0)
          lay_tile('A3', '23', 0)
          lay_tile('A5', '5', 3)
          lay_tile('B2', '7', 0)
          lay_tile('B4', '6', 1)
          game.hex_by_id('A1').tile.cities[0]
            .place_token(alpha, alpha.tokens.first, free: true)
        end

        let(:alpha) { game.corporations[0] }

        it 'discovers both paths on A3 via the converging junction' do
          # The new RouteGraph connects both paths at the converging point
          # via a JunctionVertex.  Both the north-south path (e3↔e0) and the
          # converging curve (e0↔e4) should be reachable.
          walker = Engine::RouteGraph::GraphWalker.new(graph, alpha)
          a3_paths = walker.connected_paths.select { |p| p.hex.id == 'A3' }
          expect(a3_paths.size).to eq(2)
        end

        it 'reaches both cities (A5 and B4) from the token on A1' do
          # The new RouteGraph follows both paths through the converging
          # junction, reaching A5's city (via the north-south path) and
          # B4's city (via the converging curve → B2).
          walker = Engine::RouteGraph::GraphWalker.new(graph, alpha)
          node_hexes = walker.connected_nodes.map(&:hex).map(&:id).sort
          expect(node_hexes).to contain_exactly('A1', 'A5', 'B4')
        end

        it 'the old Engine::Graph cannot traverse the converging curve on A3' do
          # The old graph reaches B2 via A5 → B4, then tries to enter A3
          # from B2 at edge 4.  Path 2 on tile 23 (a:0,b:4) shares edge A3-0
          # with Path 1, which was already crossed during A3 → A5.  The
          # old walker's edge-counter check sees counter["A3-0"] > 0 and
          # bails before yielding Path 2.
          #
          # All hexes are reachable via the north-south path and onward
          # connections (the long way around), but only the north-south
          # path on A3 appears in connected_paths.
          old_graph = Engine::Graph.new(game)
          old_graph.compute(alpha)

          a3_paths = old_graph.connected_paths(alpha).keys.select { |p| p.hex.id == 'A3' }
          expect(a3_paths.size).to eq(1)

          # All hexes are reachable via the north-south path and onward
          # connections, just not via the direct converging curve.
          hex_ids = old_graph.connected_hexes(alpha).keys.map(&:id).sort
          expect(hex_ids).to contain_exactly('A1', 'A3', 'A5', 'B2', 'B4')
        end
      end
    end
  end
end
