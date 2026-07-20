# frozen_string_literal: true

require 'spec_helper'

module Engine
  module RouteGraph
    describe Graph, :graph do
      # A minimal hex grid covering everything the tests need.
      # A1, A3, A5 form a vertical chain: A1(south) ↔ A3(north),
      # A3(south) ↔ A5(north).  B2 is A1's south-east neighbour,
      # and B6 is A5's south-east neighbour.
      test_hexes = {
        white: {
          %w[A1 A3 A5 B2 B6] => '',
        },
      }

      # One copy of each tile type needed by these tests.
      test_tiles = {
        '5' => 1,
        '9' => 1,
        '6' => 1,
        '8' => 1,
        '3' => 1,
      }

      let(:players) { %w[Alice Bob Charlie] }
      let(:game) { Game::Sandbox::Game.new(players, hexes: test_hexes, tiles: test_tiles) }

      # Helper: look up a hex by its coordinates string, e.g. 'A1', 'A3'.
      def hex(id)
        game.hex_by_id(id)
      end

      # Helper: look up a tile by its name and index, e.g. tile('5', 0).
      def tile(name, index = 0)
        game.tile_by_id("#{name}-#{index}")
      end

      # Helper: place a tile on a hex at the given rotation.
      def lay_tile(hex_id, tile_name, rotation = 0, index = 0)
        h = hex(hex_id)
        t = tile(tile_name, index)
        t.rotate!(rotation)
        h.lay(t)
      end

      # Build a new RouteGraph from the current game state.
      subject(:graph) { game.route_graph }

      context 'with a single city tile' do
        before :each do
          # Tile 5: yellow city at edges 0 (south) and 1 (south-west)
          lay_tile('A1', '5', 0)
        end

        it 'has edges for each city path' do
          expect(graph.edges.size).to eq(2)
        end

        it 'has vertices for the city and each hex edge' do
          expect(graph.vertices.size).to eq(3)
        end

        it 'connects the city node to both hex edge vertices' do
          # One edge goes to hex edge A1_0_0|A3_3_0 (south towards A3),
          # the other to A1_1_0 (south-west, off the map).
          edge_ids = graph.edges.map { |e| [e.left.id, e.right.id] }
          expect(edge_ids).to include(
            include('5-0-0'),
            include('A1_0_0|A3_3_0'),
            include('A1_1_0')
          )
        end

        it 'has a node vertex for the city' do
          cities = graph.vertices.select { |v| v.is_a?(NodeVertex) }
          expect(cities.size).to eq(1)
          expect(cities.first.id).to eq('5-0-0')
        end
      end

      context 'with two cities connected by track' do
        before :each do
          # A1: tile 5 (city at edges 0,1)   path a:0,b:_0; a:1,b:_0
          # A3: tile 9 (straight north–south) path a:0,b:3
          # A5: tile 6 (city at edges 0,2)   path a:0,b:_0; a:2,b:_0
          #
          # Rotations:
          #   A1 rot 0 → edges 0 (south), 1 (south-west)
          #   A3 rot 0 → edges 0 (south), 3 (north)
          #   A5 rot 3 → edges 3 (north), 5 (south-east)
          #
          # Connection: A1(e0/south) ↔ A3(e3/north) ↔ A3(e0/south) ↔ A5(e3/north)
          lay_tile('A1', '5', 0)
          lay_tile('A3', '9', 0)
          lay_tile('A5', '6', 3)
        end

        it 'produces 3 edges after merging intermediate vertices' do
          # After join_edges!:
          #   1. A1 city ↔ A5 city (merged through A1_0|A3_3 and A3)
          #   2. A1 city ↔ A1 edge 1 (dead end, south-west)
          #   3. A5 city ↔ A5 edge 5|B6 edge 2 (dead end, south-east)
          expect(graph.edges.size).to eq(3)
        end

        it 'produces 4 vertices' do
          # Expected vertices:
          #   1. City A1
          #   2. City A5
          #   3. Edge A1_1_0 (dead end south-west of A1)
          #   4. Edge A5_5_0|B6_2_0 (dead end south-east of A5)
          expect(graph.vertices.size).to eq(4)
        end

        it 'has two city node vertices' do
          cities = graph.vertices.select { |v| v.is_a?(NodeVertex) }
          expect(cities.size).to eq(2)
        end

        it 'connects both cities via a single merged edge' do
          city_edge = graph.edges.find do |e|
            e.left.is_a?(NodeVertex) && e.right.is_a?(NodeVertex)
          end
          expect(city_edge).not_to be_nil
          # The merged edge contains paths from all three tiles:
          # A1's city-to-edge-0, A3's edge-3-to-edge-0, and A5's edge-3-to-city
          expect(city_edge.paths.size).to eq(3)
        end

        context 'when a token is placed' do
          let(:alpha) { game.corporations.find { |c| c.id == 'α' } }

          before :each do
            a1_city = hex('A1').tile.cities.first
            a1_city.place_token(alpha, alpha.tokens.first, free: true)
          end

          it 'the walker finds both cities from the token' do
            walker = game.graph_walker(alpha)
            expect(walker.connected_nodes.map(&:id))
              .to contain_exactly('5-0-0', '6-0-0')
          end
        end
      end

      context 'with a branching track configuration' do
        before :each do
          # A1: tile 5 (city edges 0,1)
          # A3: tile 9 (straight a:0,b:3)
          #
          # The track goes from A1(e0/south) → A3(e3/north) → A3(e0/south),
          # ending at the edge of A5 (which is still a blank white hex).
          #
          # After join_edges!:
          #   A1 city ↔ A3_0|A5_3 (merged through A1_0|A3_3 and A3)
          #   A1 city ↔ A1_1_0
          lay_tile('A1', '5', 0)
          lay_tile('A3', '9', 0)
        end

        it 'has two edges' do
          expect(graph.edges.size).to eq(2)
        end

        it 'has three vertices' do
          # City A1, Edge A1_1_0, Edge A3_0_0|A5_3_0
          expect(graph.vertices.size).to eq(3)
        end
      end

      context 'with a town tile' do
        before :each do
          # Tile 3: yellow town at edges 0 (south) and 1 (south-west)
          lay_tile('A3', '3', 0)
        end

        it 'creates a node vertex for the town' do
          towns = graph.vertices.select { |v| v.is_a?(NodeVertex) }
          expect(towns.size).to eq(1)
        end
      end

      context 'with multi-lane track' do
        context 'when two multi-lane tiles connect' do
          # Both tiles have 2 parallel lanes: edge 0 ↔ edge 3
          #   Lane [2,0] on edge 0 gives offset +1 (anti-clockwise)
          #   Lane [2,1] on edge 0 gives offset −1 (clockwise)
          #
          #   A2: [══]  edge 0 (south) ── edge 3 (north, off map)
          #   A4: [══]  edge 0 (south, off map) ── edge 3 (north)
          #
          # At the shared border (A2 e0 ↔ A4 e3), lane offsets invert:
          #   [2,0]→offset +1 on A2 ↔ [2,1]→offset −1 on A4  ✓
          #   [2,1]→offset −1 on A2 ↔ [2,0]→offset +1 on A4  ✓
          # After join_edges!, border crossings merge away, leaving
          # 2 separate edges from A2's dead ends to A4's dead ends.

          let(:game) do
            hexes = { white: { %w[A2 A4] => '' } }
            tiles = {
              'ML_STRAIGHT' => {
                'count' => 2,
                'color' => 'yellow',
                'code' => 'path=a:0,b:3,lanes:2',
              },
            }
            Game::Sandbox::Game.new(players, hexes: hexes, tiles: tiles)
          end

          before :each do
            lay_tile('A2', 'ML_STRAIGHT', 0, 0)
            lay_tile('A4', 'ML_STRAIGHT', 0, 1)
          end

          it 'produces 2 edges after join_edges!' do
            expect(graph.edges.size).to eq(2)
          end

          it 'produces 4 vertices' do
            expect(graph.vertices.size).to eq(4)
          end

          it 'keeps the two lanes as separate edges' do
            expect(graph.edges).to all(have_attributes(paths: have_attributes(size: 2)))
          end
        end

        context 'when single-lane tile meets multi-lane tile' do
          # A2 has the standard single-lane straight (tile 9, lanes [[1,0],[1,0]])
          # → offset 0 on both ends.
          # A4 has dual lanes: [2,0]→offset +1 and [2,1]→offset −1 on edge 3.
          #
          # At the border (A2 e0 ↔ A4 e3):
          #   A2 offset 0 vs A4 offset +1: 0 ≠ −(+1) → no match
          #   A2 offset 0 vs A4 offset −1: 0 ≠ −(−1) → no match
          # The graph stays in two disconnected parts.

          let(:game) do
            hexes = { white: { %w[A2 A4] => '' } }
            tiles = {
              '9' => 1,
              'ML_STRAIGHT' => {
                'count' => 1,
                'color' => 'yellow',
                'code' => 'path=a:0,b:3,lanes:2',
              },
            }
            Game::Sandbox::Game.new(players, hexes: hexes, tiles: tiles)
          end

          before :each do
            lay_tile('A2', '9', 0)
            lay_tile('A4', 'ML_STRAIGHT', 0, 0)
          end

          it 'produces 3 edges' do
            # A2: 1 edge (border crossing ↔ A2 e3 dead end)
            # A4: 2 edges (one per lane: A4 e0 dead end ↔ border crossing)
            expect(graph.edges.size).to eq(3)
          end

          it 'produces 6 vertices' do
            # A2: crossing(A2_0_0|A4_3_0) + dead end(A2_3_0)
            # A4: 2 crossings(A2_0_±1|A4_3_∓1) + 2 dead ends(A4_0_±1)
            expect(graph.vertices.size).to eq(6)
          end

          it 'has no edge crossing the shared border' do
            graph.vertices.each do |v|
              next unless v.is_a?(HexEdgeVertex)
              next unless v.id.match?(/^(A[24]_[03]_|.*A[24]_[03]_)/)

              expect(v.edges.size).to eq(1)
            end
          end
        end

        context 'with cities connected via multi-lane track' do
          # A2: city with 2 parallel tracks to edge 0 (south, towards A4)
          # A4: city with 2 parallel tracks to edge 3 (north, towards A2)
          #
          # The two cities have 2 parallel paths between them, one for
          # each lane. After join_edges!, the border crossings merge
          # and the graph resolves to 2 cities connected by 2 edges.
          let(:game) do
            hexes = { white: { %w[A2 A4] => '' } }
            tiles = {
              'ML_CITY' => {
                'count' => 2,
                'color' => 'yellow',
                'code' => 'city=revenue:0;path=a:0,b:_0,lanes:2',
              },
            }
            Game::Sandbox::Game.new(players, hexes: hexes, tiles: tiles)
          end

          before :each do
            lay_tile('A2', 'ML_CITY', 0, 0)  # copy 0, rot 0 → edge 0 south
            lay_tile('A4', 'ML_CITY', 3, 1)  # copy 1, rot 3 → edge 0 north
          end

          it 'produces 2 vertices' do
            expect(graph.vertices.size).to eq(2)
          end

          it 'both vertices are cities' do
            expect(graph.vertices).to all(be_a(NodeVertex))
          end

          it 'produces 2 edges' do
            expect(graph.edges.size).to eq(2)
          end

          it 'both edges connect the two cities' do
            a2_city = hex('A2').tile.cities.first.id
            a4_city = hex('A4').tile.cities.first.id
            graph.edges.each do |e|
              expect([e.left.id, e.right.id]).to contain_exactly(a2_city, a4_city)
            end
          end

          context 'when a token is placed' do
            let(:alpha) { game.corporations.find { |c| c.id == 'α' } }

            before :each do
              a2_city = hex('A2').tile.cities.first
              a2_city.place_token(alpha, alpha.tokens.first, free: true)
            end

            it 'the walker finds both cities' do
              walker = game.graph_walker(alpha)
              city_ids = [hex('A2'), hex('A4')].map { |h| h.tile.cities.first.id }
              expect(walker.connected_nodes.map(&:id))
                .to contain_exactly(*city_ids)
            end
          end
        end
      end

      context 'with crossing and non-joining tracks' do
        let(:game) do
          hexes = {
            white: {
              %w[A2 B1 B3 C2 D1 D3 E2 F1 F3 G2 H1 H3 I2] => '',
            },
          }
          tiles = {
            '5' => 2,
            '8' => 8,
            '20' => 2,
            '17' => 1,
          }
          Game::Sandbox::Game.new(players, hexes: hexes, tiles: tiles)
        end

        before :each do
          #     _   _   _   _
          #    / \ / \ / \ / \
          #   O   X   =   X   O
          #    \_/ \_/ \_/ \_/
          #
          # O → city (A2, I2), X → crossing (C2, G2), = → non-touching (E2)
          # Path 1: A2─B1─C2─D3─E2─F3─G2─H1─I2
          # Path 2: A2─B3─C2─D1─E2─F1─G2─H3─I2

          lay_tile('A2', '5', 4)
          %w[B1 D1 F1 H1].each_with_index { |h, i| lay_tile(h, '8', 5, i) }
          %w[B3 D3 F3 H3].each_with_index { |h, i| lay_tile(h, '8', 2, i + 4) }
          lay_tile('C2', '20', 1, 0)
          lay_tile('G2', '20', 1, 1)
          lay_tile('E2', '17', 1)
          lay_tile('I2', '5', 1, 1)
        end

        it 'join_edges! resolves to two city vertices connected by two edges' do
          expect(graph.vertices.size).to eq(2)
          expect(graph.edges.size).to eq(2)
          expect(graph.vertices).to all(be_a(NodeVertex))

          a2_city_id = hex('A2').tile.cities.first.id
          i2_city_id = hex('I2').tile.cities.first.id
          edge_pairs = graph.edges.map { |e| [e.left.id, e.right.id].sort }
          expect(edge_pairs).to all(eq([a2_city_id, i2_city_id].sort))
        end
      end

      context 'with a triangle of track forming a self-loop on a city' do
        # Three hexes A1, A3, B2 form a triangle:
        #   A1 edge 0 (south) ↔ A3 edge 3 (north)
        #   A1 edge 5 (south-east) ↔ B2 edge 2 (north-west)
        #   A3 edge 4 (north-east) ↔ B2 edge 1 (south-west)
        #
        # Tiles and rotations:
        #   A1: tile 5 rot 5 → city at edges 5 (→B2) and 0 (→A3)
        #   A3: tile 7 rot 3 → curve edges 3↔4 (A1↔B2)
        #   B2: tile 7 rot 1 → curve edges 1↔2 (A3↔A1)
        #
        # After join_edges!, the three HexEdgeVertex objects merge away
        # and the three edges combine into a single self-loop on the city.
        let(:game) do
          hexes = { white: { %w[A1 A3 B2] => '' } }
          tiles = { '5' => 1, '7' => 2 }
          Game::Sandbox::Game.new(players, hexes: hexes, tiles: tiles)
        end

        before :each do
          lay_tile('A1', '5', 5, 0)
          lay_tile('A3', '7', 3, 0)
          lay_tile('B2', '7', 1, 1)
        end

        it 'reduces to 1 vertex (the city)' do
          expect(graph.vertices.size).to eq(1)
          expect(graph.vertices.first).to be_a(NodeVertex)
        end

        it 'reduces to 1 edge (a self-loop)' do
          expect(graph.edges.size).to eq(1)
        end

        it 'the self-loop edge connects the city to itself' do
          edge = graph.edges.first
          city = graph.vertices.first
          expect(edge.left).to eq(city)
          expect(edge.right).to eq(city)
        end

        it 'the self-loop edge contains paths from the three tiles (with A1 repeated once)' do
          edge = graph.edges.first
          # The A1 city path appears in both merged segments, giving 4 total:
          #   A3 path, A1 path (from city→edge_0), B2 path, A1 path (from city→edge_5)
          expect(edge.paths.size).to eq(4)
        end
      end

      describe 'the to_d3 visualisation format' do
        before :each do
          # Use hexes from different columns so that min_x != max_x.
          # A1 is col A (x=0), B2 is col B (x=1).
          # Also lay a tile on B2 so we have vertices on both columns.
          lay_tile('A1', '5', 0)
          lay_tile('B2', '8', 0)
        end

        it 'returns a hash with nodes and links' do
          d3 = graph.to_d3
          expect(d3).to have_key(:nodes)
          expect(d3).to have_key(:links)
        end

        it 'includes all vertices as nodes' do
          d3 = graph.to_d3
          expect(d3[:nodes].size).to eq(graph.vertices.size)
        end

        it 'includes all edges as links' do
          d3 = graph.to_d3
          expect(d3[:links].size).to eq(graph.edges.size)
        end

        it 'gives each node a type' do
          d3 = graph.to_d3
          types = d3[:nodes].map { |n| n[:type] }.uniq
          expect(types).to include('City', 'Edge')
        end
      end
    end
  end
end
