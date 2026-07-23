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

      describe '#connected_paths with converging plain-track exits' do
        # Tile 23: path=a:0,b:3;path=a:0,b:4 — two paths that converge at
        # edge 0.  The GraphWalker's @crossed_exits guard blocks entry to
        # the shared A3-0 hex exit from the B2 side, so only the north-south
        # path (e3↔e0) is reachable.  Both A5 and B4 are still reachable via
        # A3's north-south path and onward connections.
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
        #   - B4's city (via A3's north-south path → A5 → B4)

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

        it 'discovers only the north-south path on A3' do
          walker = Engine::RouteGraph::GraphWalker.new(graph, alpha)
          a3_paths = walker.connected_paths.select { |p| p.hex.id == 'A3' }
          expect(a3_paths.size).to eq(1)
        end

        it 'reaches both cities (A5 and B4) from the token on A1' do
          # A5 reached via A3's north-south path, B4 via onward
          # connections through A5 and B2.
          walker = Engine::RouteGraph::GraphWalker.new(graph, alpha)
          node_hexes = walker.connected_nodes.map { |n| n.hex.id }.sort
          expect(node_hexes).to contain_exactly('A1', 'A5', 'B4')
        end
      end

      describe 'converging junctions and multi-token walks' do
        # This is a seven-tile map, arranged in a hexagon, with cities at the
        # top (B1) and bottom (B3). The cities are connected in two ways:
        #  - A straight N-S path running B1-B3-B5.
        #  - A swooping path that goes B1-A2-A4-B3(SE-NW)-C3-C4-B5.
        # The tile in B3 is #47, with two straight paths N-S and SE-NW, and two
        # gently curved paths N-SW and S-NE.
        # It is not possible to trace a route from B1 to the S-NE path, or from
        # B5 to the N-SW path.
        let(:hexes) { { white: { %w[A2 A4 B1 B3 B5 C2 C4] => '' } } }
        let(:tiles) { { '5' => 2, '7' => 2, '8' => 2, '47' => 1 } }
        let(:game) { Game::Sandbox::Game.new(players, hexes: hexes, tiles: tiles) }
        let(:alpha) { game.corporations[0] }
        let(:b1) { game.hex_by_id('B1') }
        let(:b5) { game.hex_by_id('B5') }
        let(:walker) { Engine::RouteGraph::GraphWalker.new(graph, alpha) }

        before :each do
          lay_tile('B1', '5', 0, 0)
          lay_tile('B3', '47', 0, 0)
          lay_tile('B5', '5', 3, 1)
          lay_tile('A2', '8', 4, 0)
          lay_tile('A4', '7', 3, 0)
          lay_tile('C2', '7', 0, 1)
          lay_tile('C4', '8', 1, 1)
        end

        it 'cannot reach the S→SW path on B3 from a token in B1' do
          b1.tile.cities.first.place_token(alpha, alpha.next_token, free: true)
          paths = walker.connected_paths.select { |p| p.hex.id == 'B3' }
          expect(paths.map { |p| p.edges.map(&:num).sort }).to match_array([[0, 3], [1, 3], [1, 4]])
        end

        it 'cannot reach the N→NE path on B3 from a token in B5' do
          b5.tile.cities.first.place_token(alpha, alpha.next_token, free: true)
          paths = walker.connected_paths.select { |p| p.hex.id == 'B3' }
          expect(paths.map { |p| p.edges.map(&:num).sort }).to match_array([[0, 3], [0, 4], [1, 4]])
        end

        it 'can reach all paths on B3 from a tokens in B1 and B5' do
          b1.tile.cities.first.place_token(alpha, alpha.next_token, free: true)
          b5.tile.cities.first.place_token(alpha, alpha.next_token, free: true)
          paths = walker.connected_paths.select { |p| p.hex.id == 'B3' }
          pending('walk from multiple tokens being combined')
          expect(paths.map { |p| p.edges.map(&:num).sort }).to match_array([[0, 3], [0, 4], [1, 3], [1, 4]])
        end

        it 'can reach all paths on B3 from a tokens in B5 and B1' do
          b5.tile.cities.first.place_token(alpha, alpha.next_token, free: true)
          b1.tile.cities.first.place_token(alpha, alpha.next_token, free: true)
          paths = walker.connected_paths.select { |p| p.hex.id == 'B3' }
          pending('walk from multiple tokens being combined')
          expect(paths.map { |p| p.edges.map(&:num).sort }).to match_array([[0, 3], [0, 4], [1, 3], [1, 4]])
        end
      end
    end
  end
end
