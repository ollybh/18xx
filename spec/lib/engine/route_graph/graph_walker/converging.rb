# frozen_string_literal: true

module Engine
  module RouteGraph
    # Tests to make sure converging junctions are handled correctly, with
    # backtracking blocked.
    #
    # A GraphWalker subclass spec can use these tests by including the context
    # and the example groups, overriding `subject(:walker)` as needed:
    #   describe MyWalker, :graph do
    #     include_context 'GraphWalker spec setup'
    #     subject(:walker) { MyWalker.new(graph, alpha) }
    #     it_behaves_like 'a GraphWalker on converging junctions'
    #   end
    shared_examples 'a GraphWalker on converging junctions' do
      describe 'direct backtracking' do
        # This is a four-tile map, designed to check that routes do not directly
        # backtrack at converging junctions.
        # - A2 and C2 have cities.
        # - B1 has track that connects to both of these cities, but not
        #   directly: it is tile #624 with two tight curves that connect the
        #   southern edge of the tile to A2 and C2.
        # The second part of the test adds a tight curve on B3 and checks that a
        # route is now found to C2: A2→B3→B1→C2.
        let(:hexes) { { white: { %w[A2 B1 B3 C2] => '' } } }
        let(:tiles) { { '5' => 1, '7' => 1, '115' => 1, '624' => 1 } }
        let(:c2_city) { hex('C2').tile.cities.first }
        let(:found_hexes) { walker.reachable_hexes.map(&:coordinates) }
        let(:found_nodes) { walker.connected_nodes }

        before do
          lay_tile('A2', '5', 4)
          lay_tile('B1', '624', 5)
          lay_tile('C2', '115', 2)
          hex('A2').tile.cities.first.place_token(alpha, alpha.next_token, free: true)
        end

        context 'with no track in B3' do
          it 'cannot reach hex C2' do
            expect(found_hexes).to match_array(%w[A2 B1])
          end

          it 'cannot reach city in C2' do
            expect(found_nodes).not_to include(c2_city)
          end
        end

        context 'with track link in B3' do
          before do
            lay_tile('B3', '7', 2)
          end

          it 'can reach all hexes' do
            expect(found_hexes).to match_array(%w[A2 B1 B3 C2])
          end

          it 'can reach city in C2' do
            expect(found_nodes).to include(c2_city)
          end
        end
      end

      describe 'direct backtracking and reversing' do
        # This is a four-hex layout with three cities.
        # - A1 has a single path heading to the south-east (hex B2).
        # - A3 has a single path heading to the north-east (hex B2).
        # - B4 has a single path heading to the north (hex B2).
        # - B2 has two track paths that connect all of these cities.
        #   - One runs north-west to south, connecting to A1 and B4.
        #   - One runs south-west to south, connecting to A3 and B4.
        #   - The southern edge (next to B4) is a converging junction.
        # A token in A1 has a route to the city in B4, but cannot reach the city
        # in A3 without backtracking.
        # As well as checking the route cannot backtrack immediately at the
        # converging junction, this tests that the route cannot go through the
        # junction to the B4 city and reverse back through the junction.
        let(:hexes) { { white: { %w[A1 A3 B2 B4] => '' } } }
        let(:tiles) { { '115' => 3, '29' => 1 } }
        let(:a1_city) { hex('A1').tile.cities.first }
        let(:a3_city) { hex('A3').tile.cities.first }
        let(:b4_city) { hex('B4').tile.cities.first }

        before do
          lay_tile('A1', '115', 5, 0)
          lay_tile('B2', '29', 0, 0)
          lay_tile('B4', '115', 3, 1)
          lay_tile('A3', '115', 4, 2)
          a1_city.place_token(alpha, alpha.tokens.first, free: true)
        end

        it 'does not reach A3 from A1 via the converging junction and B4' do
          expect(walker.connected_nodes).not_to include(a3_city)
        end

        it 'reaches B4 (the dead-end city)' do
          expect(walker.connected_nodes).to include(b4_city)
        end
      end

      describe 'blocked path to converging junction' do
        # This tests that a path ending at a converging junction is not added to
        # `connected_paths` if the only route to that path has already passed
        # through that converging junction.
        #
        # This is a five hex layout. A1, A3 and A5 are in one column, B2 and B4
        # to their east. The tiles are:
        # - A1: city with a single path to the south (hex A3).
        # - A3: plain track with two paths:
        #   - A straight running north to south (A1-A5).
        #   - A gentle curve running south to north-west (A5-B2).
        #   - There is a converging junction on the southern edge (next to A5).
        # - A5: city with two paths, to the north (A3) and north-east (B4).
        # - B2: a plain track tight curve running south to south-west (A3-B4).
        # - B4: city with two paths, to the south-west (A3) and north (B2).
        #
        # The routes out of the city in A1 can be walked in this order:
        # 1. South into hex A3 to the converging junction.
        # 2. South from the converging junction in A3 to the city in A5.
        # 3. North-east from the A5 city to the B4 city.
        # 4. North from the B4 city through B2 heading towards the converging
        #    junction in A3.
        #
        # The path heading out of B4 to the north can be followed across tile
        # B2, but is then blocked when it joins to A3. Following it any further
        # than this would take us back to the converging junction. The purpose
        # of this test is to make sure this last path does not get added to
        # `connected_paths`.
        let(:hexes) { { white: { %w[A1 A3 A5 B2 B4] => '' } } }
        let(:tiles) { { '5' => 1, '6' => 1, '7' => 1, '23' => 1, '115' => 1 } }
        let(:all_paths) { game.hexes.map(&:tile).flat_map(&:paths) }
        let(:connected_paths) { walker.connected_paths }

        before do
          lay_tile('A1', '115', 0)
          lay_tile('A3', '23', 0)
          lay_tile('A5', '5', 3)
          lay_tile('B2', '7', 0)
          lay_tile('B4', '6', 1)
          hex('A1').tile.cities.first.place_token(alpha, alpha.tokens.first, free: true)
        end

        it 'discovers only the north-south path on A3', :aggregate_failures do
          missing = all_paths - connected_paths.to_a
          expect(missing.size).to eq(1)
          expect(missing.first.hex.coordinates).to eq('A3')
          expect(missing.first.ends.map(&:num)).to contain_exactly(0, 4)
        end

        it 'can reach all paths from A5' do
          hex('A5').tile.cities.first.place_token(alpha, alpha.tokens.first, free: true)
          expect(connected_paths).to match_array(all_paths)
        end

        it 'reaches both cities (A5 and B4) from the token on A1' do
          node_hexes = walker.connected_nodes.map { |n| n.hex.id }.sort
          expect(node_hexes).to contain_exactly('A1', 'A5', 'B4')
        end

        it 'reaches all hexes' do
          expect(walker.reachable_hexes.map(&:coordinates)).to match_array(%w[A1 A3 A5 B2 B4])
        end
      end

      describe 'converging junctions and multi-token walks' do
        # This is a seven-tile map, arranged in a hexagon, with cities at the
        # top (B1) and bottom (B3). The cities are connected in two ways:
        #  - A straight N-S path running B1-B3-B5.
        #  - A swooping path that goes B1-A2-A4-B3(SE-NW)-C2-C4-B5.
        # The tile in B3 is #47, with two straight paths N-S and SE-NW, and two
        # gently curved paths N-SW and S-NE.
        # It is not possible to trace a route from B1 to the S-NE path, or from
        # B5 to the N-SW path.
        let(:hexes) { { white: { %w[A2 A4 B1 B3 B5 C2 C4] => '' } } }
        let(:tiles) { { '5' => 2, '7' => 2, '8' => 2, '47' => 1 } }
        let(:b1_city) { hex('B1').tile.cities.first }
        let(:b5_city) { hex('B5').tile.cities.first }
        let(:b3_paths_edges) do
          walker
            .connected_paths
            .select { |path| path.hex.coordinates == 'B3' }
            .map { |path| path.edges.map(&:num).sort }
        end

        before do
          lay_tile('B1', '5',  0, 0)
          lay_tile('B3', '47', 0, 0)
          lay_tile('B5', '5',  3, 1)
          lay_tile('A2', '8',  4, 0)
          lay_tile('A4', '7',  3, 0)
          lay_tile('C2', '7',  0, 1)
          lay_tile('C4', '8',  1, 1)
        end

        it 'cannot reach the S→SW path on B3 from a token in B1' do
          b1_city.place_token(alpha, alpha.next_token, free: true)
          expect(b3_paths_edges).to contain_exactly([0, 3], [1, 3], [1, 4])
        end

        it 'cannot reach the N→NE path on B3 from a token in B5' do
          b5_city.place_token(alpha, alpha.next_token, free: true)
          expect(b3_paths_edges).to contain_exactly([0, 3], [0, 4], [1, 4])
        end

        it 'can reach all paths on B3 from a tokens in B1 and B5' do
          # Routes from B1 are walked first, routes from B5 second.
          b1_city.place_token(alpha, alpha.next_token, free: true)
          b5_city.place_token(alpha, alpha.next_token, free: true)
          expect(b3_paths_edges).to contain_exactly([0, 3], [0, 4], [1, 3], [1, 4])
        end

        it 'can reach all paths on B3 from a tokens in B5 and B1' do
          # Routes from B5 are walked first, routes from B1 second.
          b5_city.place_token(alpha, alpha.next_token, free: true)
          b1_city.place_token(alpha, alpha.next_token, free: true)
          expect(b3_paths_edges).to contain_exactly([0, 3], [0, 4], [1, 3], [1, 4])
        end
      end

      describe 'converging junctions looped cities' do
        # This is a twelve-tile map designed to test if loops through cities are
        # poisoning the DFS explored location set. It is a layout that is
        # mirrorred horizontally, so that any errors are triggered regardless of
        # which path from the token is walked first.
        # The layout is:
        # - A5 has city with a token in it, connected by paths to B4 and B6.
        # - B4 and B6 have converging junctions at their junctions with C3/C5.
        # - A3 and A7 have cities. These connect to the other paths on B4/B6.
        # - C3 and C7 have cities with four track paths each.
        #   - One leads back to the converging junction (B4/B6).
        #   - One connects these two cities together, through a straight in C5.
        #   - Two form loops with two other cities, in B1/C1 and B8/C9.
        # It is possible to trace a route from A5 to A3 by going through B6 to
        # the city in C7, then through C5 to the city in C3, and finally through
        # B4 to A3. This route goes through both converging junctions, but only
        # using one leg of each.
        # The bug this is trying to detect is if there is a different route
        # explored first: from A5 through B3 (using one leg of the converging
        # junction) to the city in C3 and around the looped cities in C1 and B2
        # back to C3 and back to B4. At this point the route doesn't continue to
        # A3 as that would be going through the second path of the converging
        # junction, but does mark the entry to the converging junction from C3
        # as being explored, blocking the correct route.
        let(:hexes) { { white: { %w[A3 A5 A7 B2 B4 B6 B8 C1 C3 C5 C7 C9] => '' } } }
        let(:tiles) { { '5' => 5, '9' => 1, '15' => 2, '23' => 1, '24' => 1, '115' => 2 } }

        before do
          lay_tile('A3', '115', 5, 0)
          lay_tile('A5', '5',   4, 0)
          lay_tile('A7', '115', 4, 1)
          lay_tile('B2', '5',   4, 1)
          lay_tile('B4', '23',  4, 0)
          lay_tile('B6', '24',  5, 0)
          lay_tile('B8', '5',   4, 2)
          lay_tile('C1', '5',   0, 3)
          lay_tile('C3', '15',  0, 0)
          lay_tile('C5', '9',   0, 0)
          lay_tile('C7', '15',  0, 1)
          lay_tile('C9', '5',   2, 4)
          hex('A5').tile.cities.first.place_token(alpha, alpha.next_token, free: true)
        end

        it 'can reach all hexes' do
          all_hexes = hexes.map { |_color, hexdefs| hexdefs.keys }.flatten
          expect(walker.reachable_hexes.map(&:coordinates)).to match_array(all_hexes)
        end

        it 'can reach both paths on B4' do
          b4_path_edges = walker.connected_paths
                                .select { |path| path.hex.coordinates == 'B4' }
                                .map { |path| path.edges.map(&:num).sort }
          expect(b4_path_edges).to contain_exactly([1, 4], [2, 4])
        end

        it 'can reach both paths on B6' do
          b6_path_edges = walker.connected_paths
                                .select { |path| path.hex.coordinates == 'B6' }
                                .map { |path| path.edges.map(&:num).sort }
          expect(b6_path_edges).to contain_exactly([1, 5], [2, 5])
        end
      end

      describe 'converging junctions looped junctions' do
        # This is the same layout as the previous example ('converging layout
        # looped cities') but testing Lawson-type junctions as the centre of the
        # loops instead of cities. Looping back through these is allowed, so
        # this is making sure that track can't be used after going around a
        # loop.
        let(:hexes) { { white: { %w[A3 A5 A7 B2 B4 B6 B8 C1 C3 C5 C7 C9] => '' } } }
        let(:tiles) { { '5' => 1, '7' => 4, '9' => 1, '23' => 1, '24' => 1, '115' => 2, '545' => 2 } }

        before do
          lay_tile('A3', '115',  5, 0)
          lay_tile('A5', '5',    4, 0)
          lay_tile('A7', '115',  4, 1)
          lay_tile('B2', '7',    4, 0)
          lay_tile('B4', '23',   4, 0)
          lay_tile('B6', '24',   5, 0)
          lay_tile('B8', '7',    4, 1)
          lay_tile('C1', '7',    0, 2)
          lay_tile('C3', '545',  0, 0)
          lay_tile('C5', '9',    0, 0)
          lay_tile('C7', '545',  0, 1)
          lay_tile('C9', '7',    2, 3)
          hex('A5').tile.cities.first.place_token(alpha, alpha.next_token, free: true)
        end

        it 'can reach all hexes' do
          all_hexes = hexes.map { |_color, hexdefs| hexdefs.keys }.flatten
          expect(walker.reachable_hexes.map(&:coordinates)).to match_array(all_hexes)
        end

        it 'can reach both paths on B4' do
          b4_path_edges = walker.connected_paths
                                .select { |path| path.hex.coordinates == 'B4' }
                                .map { |path| path.edges.map(&:num).sort }
          expect(b4_path_edges).to contain_exactly([1, 4], [2, 4])
        end

        it 'can reach both paths on B6' do
          b6_path_edges = walker.connected_paths
                                .select { |path| path.hex.coordinates == 'B6' }
                                .map { |path| path.edges.map(&:num).sort }
          expect(b6_path_edges).to contain_exactly([1, 5], [2, 5])
        end
      end
    end
  end
end
