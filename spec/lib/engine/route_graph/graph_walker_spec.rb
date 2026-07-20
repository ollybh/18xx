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
    end
  end
end
