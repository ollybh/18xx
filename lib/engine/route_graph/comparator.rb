# frozen_string_literal: true

module Engine
  module RouteGraph
    # Compares the outputs of {Engine::Graph} (the old route-finding system)
    # and {RouteGraph::Graph RouteGraph::Graph}/{RouteGraph::GraphWalker}
    # (the new system) for a given game state and entity set.
    #
    # The comparison is done by converting both results to sets of string IDs
    # (node IDs, path hex+index combos, hex IDs) so that object identity
    # differences between the two systems don't affect the comparison.
    #
    # A {::GameError} during old-graph computation is caught and reported as
    # `error: "<message>"` rather than crashing the comparison run.
    class Comparator
      class << self
        # Compare results for a single entity at the current game state.
        #
        # @param game [Engine::Game] The game to compare graphs for.
        # @param entity [Operator] The entity to compute graphs for.
        # @return [Hash] Comparison result with keys:
        #   - :entity [String] entity ID
        #   - :match [Boolean] true if all three method results match
        #   - :connected_nodes [Hash] :extra and :missing as ID arrays
        #   - :connected_paths [Hash] :extra and :missing as ID arrays
        #   - :reachable_hexes [Hash] :extra and :missing as ID arrays
        #   - :timing [Hash] :old, :new_build, :new_walk in microseconds
        #   - :walk_calls [Hash] :old, :new counts of method calls
        #   - :error [String, nil] error message if old-graph compute failed
        def compare(game, entity)
          comparison = { entity: entity.id, match: false }
          timing_stats = {}
          call_stats = {}

          # Old graph
          old_nodes = {}
          old_paths = {}
          old_hexes = {}
          old_start = clock
          begin
            old_graph = Engine::Graph.new(game)
            old_nodes = old_graph.connected_nodes(entity)
            old_paths = old_graph.connected_paths(entity)
            old_hexes = old_graph.reachable_hexes(entity)
            call_stats[:old] = old_graph.walk_calls(entity)
          rescue StandardError => e
            comparison[:error] = e.message
            call_stats[:old] = { all: 0, skipped: 0, not_skipped: 0 }
          end
          timing_stats[:old] = clock - old_start

          # New graph
          build_start = clock
          new_graph = RouteGraph::Graph.new(game, statistics: true)
          timing_stats[:new_build] = clock - build_start

          walk_start = clock
          walker = RouteGraph::GraphWalker.new(new_graph, entity, statistics: true)
          new_nodes = walker.connected_nodes
          new_paths = walker.connected_paths
          new_hexes = walker.reachable_hexes
          timing_stats[:new_walk] = clock - walk_start
          call_stats[:new] = walker.statistics

          comparison[:timing] = timing_stats
          comparison[:walk_calls] = call_stats

          # Compare by ID sets
          node_ids_old = old_nodes.keys.to_set(&:id)
          node_ids_new = new_nodes.to_set(&:id)
          path_ids_old = old_paths.keys.to_set { |p| "#{p.hex.id}-#{p.index}" }
          path_ids_new = new_paths.to_set { |p| "#{p.hex.id}-#{p.index}" }
          hex_ids_old = old_hexes.keys.to_set(&:id)
          hex_ids_new = new_hexes.to_set(&:id)

          nodes_match = node_ids_old == node_ids_new
          paths_match = path_ids_old == path_ids_new
          hexes_match = hex_ids_old == hex_ids_new

          comparison[:connected_nodes] = diff_sets(node_ids_old, node_ids_new)
          comparison[:connected_paths] = diff_sets(path_ids_old, path_ids_new)
          comparison[:reachable_hexes] = diff_sets(hex_ids_old, hex_ids_new)
          comparison[:match] = nodes_match && paths_match && hexes_match

          comparison
        end

        # Compare results for all active entities in the current game.
        #
        # Active entities are corporations and minors that have at least one
        # placed token and are not closed. Entities with no tokens produce no
        # graph results and are excluded.
        #
        # @param game [Engine::Game] The game to compare graphs for.
        # @return [Hash{String => Hash}] Entity ID to comparison result.
        def compare_all(game)
          entities = game.corporations + game.minors
          entities = entities.select { |e| !e.closed? && e.placed_tokens.any? }

          entities.filter_map do |entity|
            result = compare(game, entity)
            [entity.id, result]
          end.to_h
        end

        # Replay a game's actions and compare graphs at regular intervals.
        #
        # The game is loaded from `game_data` (which can be any value accepted
        # by {Engine::Game.load}), then actions are replayed sequentially.
        # After every `interval`-th action (and after the final action) the
        # graphs are compared for all active entities.
        #
        # @param game_data [String, Integer, Hash, ::Game] Game identifier
        # @param interval [Integer] Compare every N actions (default: 10)
        # @return [Hash{Integer => Hash{String => Hash}}] Action number to
        #   entity comparison results.
        def compare_replay(game_data, interval: 10)
          game = Engine::Game.load(game_data, at_action: 0)
          results = {}
          all_actions = game.instance_variable_get(:@raw_all_actions) || []

          all_actions.each_with_index do |action, i|
            next if ((i + 1) % interval).nonzero? && (i != all_actions.length - 1)

            game.process_to_action(action['id'])
            results[action['id']] = compare_all(game)
          end

          results
        end

        # Format a one-block summary of aggregated timings and walk-call counts
        # for a tree of comparison results.
        #
        # @param results [Hash] Either a single comparison result (with a
        #   +:timing+ key) or a nested {entity => result} / {action => {...}}
        #   tree; both shapes are summed by {collate_stats}.
        # @return [String] multi-line summary.
        def stats_summary(results)
          stats = collate_stats(results)
          skip_pct = lambda do |skipped, total|
            total.zero? ? 0 : 100 * skipped / total
          end
          old_skip_pct = skip_pct.call(stats[:old_skipped], stats[:old_calls])
          new_skip_pct = skip_pct.call(stats[:new_skipped], stats[:new_calls])

          count_line = "#{stats[:count]} comparison#{'s' unless stats[:count] == 1}"
          time_line = 'Timings: ' \
                      "old #{stats[:old_time]}μs, " \
                      "build #{stats[:new_time_build]}μs, " \
                      "walk #{stats[:new_time_walk]}μs"
          calls_line = 'Method calls: ' \
                       "old #{stats[:old_calls]} (skipped #{old_skip_pct}%), " \
                       "new #{stats[:new_calls]} (skipped #{new_skip_pct}%), " \
                       "edges #{stats[:new_edges_walked]} (skipped #{stats[:new_edges_skipped]})"
          "#{count_line}\n#{time_line}\n#{calls_line}"
        end

        private

        # Reduce a tree of comparison results to a flat hash of integer totals.
        # Recurses through arbitrary nesting (entity hashes, per-action hashes,
        # per-file hashes) summing leaf statistics.
        #
        # @param results [Hash] single comparison, or nested results tree.
        # @return [Hash{Symbol=>Integer}]
        def collate_stats(results)
          return collate_one(results) if results.key?(:timing)

          results.map { |_, result| collate_stats(result) }
                 .reduce(zero_stats) { |acc, one| acc.merge(one) { |_, a, b| a + b } }
        end

        # Extracts timing and method calls from a comparison result hash,
        # converting this to a flat hash of integer totals.
        #
        # @param result [Hash] Results from a single comparison.
        # @return [Hash{Symbol=>Integer}]
        def collate_one(result)
          {
            count: 1,
            old_time: result[:timing][:old],
            new_time_build: result[:timing][:new_build],
            new_time_walk: result[:timing][:new_walk],
            old_calls: result[:walk_calls][:old][:all],
            old_skipped: result[:walk_calls][:old][:skipped],
            new_calls: result[:walk_calls][:new][:dfs_calls],
            new_skipped: result[:walk_calls][:new][:skipped].values.sum,
            new_edges_walked: result[:walk_calls][:new][:edges_traversed],
            new_edges_skipped: result[:walk_calls][:new][:edges_skipped].values.sum,
          }
        end

        def zero_stats
          {
            count: 0,
            old_time: 0,
            new_time_build: 0,
            new_time_walk: 0,
            old_calls: 0,
            old_skipped: 0,
            new_calls: 0,
            new_skipped: 0,
            new_edges_walked: 0,
            new_edges_skipped: 0,
          }
        end

        # Build the diff hashes for a single set pair.
        def diff_sets(old_ids, new_ids)
          {
            extra: (new_ids - old_ids).to_a.sort,
            missing: (old_ids - new_ids).to_a.sort,
          }
        end

        def clock
          Process.clock_gettime(Process::CLOCK_MONOTONIC, :microsecond)
        end
      end
    end
  end
end
