# frozen_string_literal: true

require_relative 'graph'
require_relative 'edge'
require_relative 'vertex'

module Engine
  module RouteGraph
    # A GraphWalker walks the {RouteGraph::Graph} for a specific entity,
    # calculating which of the graph’s {RouteGraph::Vertex vertices} and
    # {RouteGraph::Edge edges} can be reached. These are then used to calculate
    # the map parts that are accessible: {Engine::Hex hexes}, {Part::Node nodes}
    # and {Part::Path paths}.
    #
    # The {RouteGraph::Graph} is an abstract representation of the game map's
    # topology. The GraphWalker is where the game rules are enforced, ensuring
    # that routes cannot reuse track or pass through tokened out cities.
    #
    # The walk is triggered lazily: creating a GraphWalker stores references to
    # the graph and entity but does not carry out any computation. The first
    # call to any of the query methods will trigger the DFS graph walk.
    # Subsequent calls to the query methods will return cached data, until a
    # change in the underlying graph is detected. At this point the graph will
    # be re-run transparently. Callers never need to directly invoke the walk.
    #
    # The class is designed to be extensible: if a game needs different rules
    # for route finding then a GraphWalker subclass can be created, overriding a
    # few key methods to produce the desired behaviour:
    # - {#home_nodes} determines the starting locations for walking the graph.
    # - Then, once the walk is underway:
    #   - {#edge_blocked?} controls whether the walker may proceed along an edge.
    #     This blocks edges that are already on the current route or of an
    #     incompatible gauge.
    #   - {#arrival_blocked?} controls whether a walker may explore a new vertex that
    #     is found. This blocks re-entry to a city/town already on the current
    #     route, and is also the hook for hex-entry restrictions.
    #   - {#departure_blocked?} controls whether switching from an incoming edge to
    #     an outgoing edge is allowed at a vertex. This prevents immediate
    #     reversal and checks for blocked cities.
    class GraphWalker
      # @api private
      attr_reader :connected_edges, :connected_vertices

      # Creates a new GraphWalker object.
      # @param graph [RouteGraph::Graph] The route graph to be walked.
      # @param entity [Operator] The entity whose routes will be calculated by
      #   the GraphWalker.
      # @param backtracking [Boolean] Whether backtracking at converging
      #   junctions is permitted.
      # @param statistics [Boolean] If true then walk instrumentation statistics
      #   will be collected.
      # @return [RouteGraph::GraphWalker] The new GraphWalker.
      def initialize(graph, entity, backtracking: false, statistics: false)
        @graph = graph
        @entity = entity
        @backtracking = backtracking
        @graph_version = nil
        @stats = if statistics
                   {
                     dfs_calls: 0,
                     skipped: Hash.new(0),
                     edges_traversed: 0,
                     edges_skipped: Hash.new(0),
                     resolving_dfs_calls: 0,
                     frontier: nil,
                   }
                 end

        # These two variables accumulate the final results of the graph walk:
        # the vertices and edges that are reachable by @entity.
        @connected_vertices = Set[]
        @connected_edges = Set[]
      end

      # @!group Query Methods

      # Hexes where track can be laid.
      #
      # These hexes are a superset of those returned by {#reachable_hexes}. That
      # method finds the hexes that contain reachable track, this also includes:
      #  - Home hexes with no track.
      #  - Hexes which could be reached by extending incomplete tracks.
      #
      # @return [Hash{Engine::Hex => Set<integer>}]
      #   Returns a hash mapping each {Engine::Hex} that is reachable from the
      #   corporation's tokens to set of integer edge numbers (0 to 5)
      #   indicating which sides of the hex are connected.
      def connected_hexes
        walk! if stale?
        return @cache_hexes_edges if @cache_hexes_edges

        hexes_edges = Hash.new { |h, k| h[k] = Set[] }

        @connected_edges.flat_map(&:paths).each do |path|
          hex = path.hex
          path.exits.each do |edge|
            hexes_edges[hex] << edge
            next unless (neighbor = hex.neighbors[edge])

            hexes_edges[neighbor] << hex.invert(edge)
          end
        end

        extra_hexes = home_nodes.map(&:hex)
        extra_hexes.each { |hex| hexes_edges[hex] |= hex.neighbors.keys }

        @cache_hexes_edges = hexes_edges.freeze
      end

      # Nodes (cities, towns, offboards) that can be reached. Used to determine
      # where a corporation can place a token, merge, or establish connectivity
      # for other purposes.
      #
      # @return [Set<Engine::Part::Node>]
      #   Returns a set containing each {Engine::Part::Node} that is reachable.
      def connected_nodes
        walk! if stale?

        @cache_nodes ||= @connected_vertices.grep(NodeVertex).to_set(&:node).freeze
      end

      # Connected track paths for track-laying validation.
      #
      # Used in the track step {Engine::Step::Tracker#check_track_restrictions!}
      # call to ensure that newly laid track can be reached.
      #
      # @return [Set<Engine::Part::Path>]
      #   Returns a set containing each {Engine::Part::Path} that is reachable.
      def connected_paths
        walk! if stale?

        @cache_paths ||= @connected_edges.flat_map(&:paths).to_set.freeze
      end

      # Hexes which can be reached using existing track. These are the hexes
      # where trains can be run.
      #
      # This is a subset of the hexes included in {#connected_hexes}. That
      # method also includes hexes that could be connected by laying new track,
      # and unconnected home hexes.
      #
      # Used in the {Engine::Step::Track#available_hex} checks in the route step
      # (via {Engine::Step::Tracker#hex_neighbors}) and in game-specific logic
      # such as mine access, coal fields, and ferry connectivity.
      #
      # @return [Set<Engine::Hex>]
      #   Returns a set containing each {Engine::Hex} that any reachable path
      #   passes through.
      def reachable_hexes
        walk! if stale?

        @cache_hexes ||= @connected_edges.flat_map(&:paths).to_set(&:hex).freeze
      end

      # @!endgroup

      # Allows access to the instrumentation statistics collected when walking
      # the graph.
      #
      # @return [Hash]
      #   - :time [integer] The time taken to walk the graph, in microseconds.
      #   - :dfs_calls [integer] The number of times the {#dfs} method was
      #     called whilst walking the graph.
      #   - :skipped [Hash<label => integer] The number of times the {#dfs}
      #     method was skipped without further processing, grouped by the reason
      #     the walk chain was ended.
      #   - :edges_traversed [integer] The number of {Edge edges} walked.
      #   - :edges_skipped [Hash<label => integer] The number of times the edges
      #     were examined but not walked, grouped by the reason they were
      #     skipped.
      #   Returns an empty hash if instrumentation statistics were not requested
      #   when the Graph object was constructed.
      def statistics
        @stats
      end

      protected

      # @!group Walker Traversal Methods
      #
      # These are the key methods that determine the behaviour of the walker.
      # Implementing a subclass is likely to involve overriding one or more of
      # these methods.

      # Tests whether the walker is allowed to walk along an edge to reach the
      # vertex at the other end.
      #
      # Reasons why walking along the edge is blocked are:
      #  - The edge has already been walked on the current route.
      #  - The edge goes to a converging junction where one of the other paths
      #    has been walked.
      #  - The track gauge is incompatible.
      #  - We have reached terminal track that leads to a junction. These are
      #    used to represent impassable hexes, such as mountains or sea.
      #    Multiple tracks can lead up to these hexes, but the routes do not
      #    pass through them.
      #
      # @param edge [RouteGraph::Edge] The edge being walked.
      # @param from_vertex [RouteGraph::Vertex] The end that the walk is
      #   starting from.
      # @param state [WalkState]
      # @return [Boolean] True if the edge is blocked, false if it may be walked.
      def edge_blocked?(edge, from_vertex, state)
        return true if state.stack_edges.include?(edge)
        return true if backtracking_blocked?(edge, from_vertex, state)

        if edge.terminal?
          edge.other_end(from_vertex).is_a? JunctionVertex
        else
          false
        end
      end

      # Tests whether the walker, entering `vertex` on edge `from_edge` is
      # allowed to leave on edge `to_edge`.
      #
      # Reasons why leaving the vertex is blocked are:
      #  - This is a tokened out city.
      #  - This is an off-board area.
      #  - We are trying to pass through a city using a path which has a
      #    `terminal` attribute.
      #  - We are attempting to reverse and leave on the same edge as we
      #    arrived on.
      #
      # @param vertex [RouteGraph::Vertex] The vertex the walker is currently
      #   exploring.
      # @param from_edge [RouteGraph::Edge, nil] The last edge to have been
      #   walked. nil if the walk is starting at this vertex.
      # @param to_edge [RouteGraph::Edge] The edge to be tested.
      # @return [Boolean] True if departure along `to_edge` is blocked.
      def departure_blocked?(vertex, from_edge, to_edge)
        return false unless from_edge # Starting walk here.
        return true if from_edge == to_edge # Can't reverse.

        case vertex
        when JunctionVertex, HexEdgeVertex
          false
        when NodeVertex
          # The terminal check is for offboard-type cities where there are
          # terminal paths (track spikes) pointing to the city. Routes cannot
          # pass through these cities.
          vertex.node.blocks?(@entity) || from_edge.terminal? || to_edge.terminal?
        end
      end

      # Tests whether the walker when walking an edge is allowed to reach the
      # vertex at the other end of the edge.
      #
      # This will return true if the vertex is a town or city that has already
      # been visited on the current route.
      #
      # This is not the same test as {#departure_blocked?}: that method is
      # called once the vertex has been reached and we are checking which edges
      # the walk can continue along. This method is called before vertex is
      # added to the set of explored vertices, if it returns true the vertex
      # will not be added.
      #
      # @param vertex [RouteGraph::Vertex] The vertex the walk is about to reach.
      # @param _from_edge [RouteGraph::Edge] The edge being walked.
      # @param state [WalkState]
      # @return [Boolean] True if entry is blocked, false if it may be explored.
      def arrival_blocked?(vertex, _from_edge, state)
        return false unless vertex.is_a?(NodeVertex)

        state.stack_nodes.include?(vertex)
      end

      # @!endgroup

      # @!group Home Location Methods

      # Starting locations for walking the graph.
      # @return [Array<Engine::Part::Node>] The {Engine::Part::Node}s that are
      #   starting points for walking the graph.
      def home_nodes
        @entity.placed_tokens.map(&:city)
      end

      # Cities which are the target of teleport token abilities.
      #
      # @note The entity's abilities are checked when the graph is walked for
      #   teleport token abilities. If they are permitted by
      #   `ability_right_time?` at the point when the graph is walked then these
      #   cities will be added to {#connected_vertices}. These will be cached
      #   until the graph state is {RouteGraph::Graph#invalidate! invalidated},
      #   there is no check in {#connected_nodes} that the ability can be used
      #   when the query is made.
      #
      # @return [Array<Engine::Part::Node>]
      def teleport_nodes
        hex_ids = Set[]

        @graph.game.abilities(@entity, :token) do |ability, owner|
          next unless owner == @entity
          next unless ability.teleport_price

          hex_ids |= ability.hexes
        end

        hex_ids.flat_map { |hex_id| @graph.game.hex_by_id(hex_id).tile.cities }
      end

      # @!endgroup

      private

      # Walks the graph. Generally {#stale?} should be called first to check
      # whether the walker state is already up to date. This method will be
      # called automatically from the public node/hex/path accessor methods if
      # the walker is stale.
      #
      # The walk is implemented as a three-stage algorithm. The goal is to find
      # the set of vertices and edges that are reachable by @entity, `R` (real
      # set).
      # 1. Backtracking walk. This is the fastest DFS walk, with time complexity
      #    O(V+E). It allows backtracking at converging junctions and uses
      #    [vertex] as the DFS visited set. If no converging junctions are
      #    found in the walk, or if backtracking is permitted, then this will
      #    find the real set of reachable vertices and edges (R) and stages 2
      #    and 3 are skipped. If backtracking should have been prevented then
      #    this walk might reach sections of the graph that should be
      #    inaccessible. The result of this walk (`L`, lax set) is a superset
      #    of R.
      # 2. Approximate walk. This is another DFS walk with time complexity
      #    O(V+E) but is slower than the stage 1 walk. It uses [vertex, incoming
      #    edge] as the DFS visited set and prevents backtracking at converging
      #    junctions. This will often return the correct results (R) but there
      #    are cases with nested loops where the DFS visited set is poisoned and
      #    valid routes to converging junctions are blocked. The result of this
      #    walk (`S`, strict) is a subset of R.
      # 3. Exact walk. If there is a difference between L and S (`F` the
      #    frontier set) then the exact set of reachable vertices and edges
      #    needs to be resolved. This is another DFS walk that uses [vertex,
      #    incoming edge] as the visited set, but differs from stage 2 in that
      #    items are removed from the visited set as the DFS algorithm
      #    backtracks (in stage 2 this set accumulates and nothing is removed
      #    until the set is reset when the walk is restarted from another home
      #    node). This walk has potentially exponential time complexity.
      #
      # @return [void]
      def walk!
        @cache_paths = nil
        @cache_nodes = nil
        @cache_hexes = nil
        @cache_hexes_edges = nil
        found = nil
        start = time if @stats

        l = walk_from_homes(:backtracking)
        if @backtracking || !converging_junctions?(l.edges)
          found = l
        else
          s = walk_from_homes(:whole_walk)
          frontier = l.vertices - s.vertices
          @stats[:frontier] = frontier.size if @stats

          # TODO: The route local walk is a brute-force approach to finding the
          # correct set of reachable vertices and edges. It will always work but
          # has potentially exponential time complexity. It is unlikely that
          # this can be avoided in all cases, but there might be ways to take
          # the difference between the stage 1 and stage 2 walks (the frontier
          # vertices/edges), break them into subgraphs and test whether they are
          # reachable.
          found = frontier.empty? ? s : walk_from_homes(:route_local)
        end

        @connected_vertices = found.vertices
        @connected_edges = found.edges

        # Add extra nodes to @connected_vertices for :token abilities.
        teleport_nodes.each { |n| @connected_vertices << @graph.vertex_for(n) }

        @graph_version = @graph.version
        @stats[:time] = time - start if @stats
      end

      # Runs the DFS algorithm starting at each of @entity's home nodes.
      # @see #walk!
      # @param stage [Label] The label for the stage whose walk is being carried
      #   out. Passed to {RouteState#initialize}.
      # @return [Found] The sets of vertices and edges found.
      def walk_from_homes(stage)
        found = Found.new
        state = WalkState.new(stage)
        home_vertices.each do |vertex|
          state.reset!
          dfs(vertex, nil, state, found)
        end
        found
      end

      # The core depth-first search algorithm for walking the graph.
      # This calls itself recursively for each new vertex it encounters.
      #
      # @param vertex [RouteGraph::Vertex] The vertex to be explored.
      # @param incoming [RouteGraph::Edge, nil] The edge which was walked to
      #   reach this vertex. nil if the walk is starting at this vertex.
      # @param state [WalkState] Route-local state for the current stage.
      # @param found [Found] Result accumulator for the current stage.
      # @return [void]
      def dfs(vertex, incoming, state, found)
        increment_stats(:dfs_calls)
        increment_stats(:resolving_dfs_calls) if state.mode == :route_local
        return skip_vertex(:arrival) if arrival_blocked?(vertex, incoming, state)
        return skip_vertex(:explored) if state.explored?(vertex, incoming)

        state.on_explored_enter(vertex, incoming)
        found.vertices << vertex
        state.push_exit(vertex, incoming)
        state.push_node(vertex) if vertex.is_a?(NodeVertex)
        vertex.edges.each do |edge|
          next skip_edge(:departure) if departure_blocked?(vertex, incoming, edge)
          next skip_edge(:edge) if edge_blocked?(edge, vertex, state)

          found.edges << edge
          state.push_edge(edge)
          increment_stats(:edges_traversed)
          dfs(edge.other_end(vertex), edge, state, found)
          state.pop_edge(edge)
        end
        state.pop_node(vertex) if vertex.is_a?(NodeVertex)
        state.pop_exit(vertex, incoming)
        state.on_explored_leave(vertex, incoming)
      end

      # The graph vertices for the home nodes.
      # @return [Array<Vertex>]
      # @raise [GameError] if a home node is not found in the graph.
      def home_vertices
        home_nodes.map { |node| @graph.vertex_for(node) }
      end

      # Checks whether walking an edge would involve crossing a HexExit that
      # is in on the crossed exits call stack. Crossing one of these exits
      # would involve revisiting a converging junction where one of the other
      # edges has already been walked in the current route being explored.
      #
      # @param edge [RouteGraph::Edge]
      # @param from_vertex [RouteGraph::Vertex]
      # @param state [WalkState]
      # @return [Boolean] True if traversal is blocked by an active exit.
      def backtracking_blocked?(edge, from_vertex, state)
        [from_vertex, edge.other_end(from_vertex)].any? do |vertex|
          next false unless vertex.is_a?(HexEdgeVertex)

          hex_exit = vertex.exit_for_edge(edge)
          hex_exit && state.stack_exits.include?(hex_exit)
        end
      end

      # Tests if there are any converging junctions in a set of edges.
      # @param edges [Set<Edge>]
      # @return [Boolean]
      def converging_junctions?(edges)
        edges.any?(&:converges?)
      end

      # Checks whether the GraphWalker is synchronised with the current graph
      # model. If not then {#walk!} will need to be called to update the
      # walker's state.
      # @return [Boolean] True if the graph has been walked since the latest
      #   graph updates. False if the graph has not yet been walked, or if graph
      #   has been updated since the last walk.
      def stale?
        @graph_version != @graph.version
      end

      # Reads the system clock.
      # @return [integer]
      def time
        Process.clock_gettime(Process::CLOCK_MONOTONIC, :microsecond)
      end

      # Increments a statistics counter, if statistics are being collected.
      # @param key [Label]
      # @param group [Label, nil]
      # @return [integer, nil] The value of the counter or nil if stats are not
      #   being collected.
      def increment_stats(key, group = nil)
        return unless @stats

        if group
          @stats[group][key] += 1
        else
          @stats[key] += 1
        end
      end

      # Increments the statistics showing why an edge was skipped, if statistics
      # are being collected. This returns nil so this method can be used for its
      # side effects in a chain: `next skip_edge(reason) if blocked?`.
      # @param reason [Label] The key for the statistics hash.
      # @return nil
      def skip_edge(reason)
        increment_stats(reason, :edges_skipped)
        nil
      end

      # Increments the statistics showing why an edge was skipped, if statistics
      # are being collected. This returns nil so this method can be used for its
      # side effects in a chain: `return skip_vertex(reason) if blocked?`.
      # @param reason [Label] The key for the statistics hash.
      # @return nil
      def skip_vertex(reason)
        increment_stats(reason, :skipped)
        nil
      end
    end

    # The result of a single stage's graph walk: the vertices and edges that
    # were reached.
    Found = Struct.new(:vertices, :edges) do
      # @param vertices [Set<Vertex>]
      # @param edges [Set<Edge>]
      # @return [Found]
      def initialize(vertices = Set[], edges = Set[])
        super
      end
    end

    # State carried down one DFS branch: the whole-walk set of visited locations
    # and the route stacks.
    #
    # The stacks are items encountered whilst building a route from a home node.
    # These are used for rules enforcement, to check that the current route
    # being built is legal.
    #
    # These stacks have a push on entry/pop on exit lifecycle. They describe
    # the route from the home node to the current exploration tip. As the
    # DFS algorithm backtracks the removal of items from these stacks means
    # that alternate routes being explored from the same home node can
    # revisit the same vertices/edges that were explored earlier.
    class WalkState
      # This accumulates the set of visited locations that have been been
      # explored from a home node.
      # @return [Set<Array<Vertex, Edge>]
      attr_reader :walk_explored

      # {HexExit HexExits} that have been crossed.
      # @return [Set<HexExit>]
      attr_reader :stack_exits

      # {Edge Edges} that have been walked.
      # @return [Set<Edge>]
      attr_reader :stack_edges

      # {NodeVertex Node vertices} that have been visited.
      # @return [Set<NodeVertex>]
      attr_reader :stack_nodes

      # The lifecycle of the {#walk_explored} visited set.
      #   - `:backtracking` (stage 1) — the visited set is keyed on the vertex
      #     alone and the route stacks are not populated, so the route-local
      #     gates ({#arrival_blocked?}, the track-reuse check in {#edge_blocked?},
      #     converging-junction backtracking) no-op. Yields the lax upper bound
      #     L: backtracking at converging junctions is allowed and towns may be
      #     re-entered. Static gates (terminal track, blocked cities, reversal)
      #     still fire.
      #   - `:whole_walk` (stage 2) — the visited set is keyed on
      #     `[vertex, incoming]` and persists for the whole walk from a home
      #     node: the leave hook is a no-op, so entries survive after the
      #     subtree returns. Linear on plain track, but unsound inside a loop
      #     (a cached subtree can hide a valid route).
      #   - `:route_local` (stage 3) — the visited set is keyed on
      #     `[vertex, incoming]` and cleared on backtrack: the leave hook
      #     removes the entry, so each route re-explores the subtree under its
      #     own context. Exact but exponential in the number of routes through
      #     the loop; only used when stage 2 demonstrably under-reached.
      # @return [Label]
      attr_reader :mode

      # @param mode [Symbol] Controls the lifecycle of the {#walk_explored}
      #   visited set.
      # @see #mode
      def initialize(mode)
        @mode = mode
        # NOTE: These stacks are maintained as sets. This works because they are
        # all being used to prevent an edge/node/hex exit from being revisited,
        # so there is never an attempt to add an item that is already in the set
        # -- this is prevented by the guard that checks the stack. If there is a
        # change that removes or relaxes the guard then the stack should be
        # changed to be a counter (`Hash.new(0)`) so that it can track multiple
        # visits to the same item.
        @walk_explored = Set[]
        @stack_exits = Set[]
        @stack_edges = Set[]
        @stack_nodes = Set[]
      end

      # Clears the per-route state between home nodes.
      def reset!
        @walk_explored.clear
        @stack_exits.clear
        @stack_edges.clear
        @stack_nodes.clear
      end

      def explored?(vertex, edge)
        @walk_explored.include?(key(vertex, edge))
      end

      def on_explored_enter(vertex, edge)
        @walk_explored << key(vertex, edge)
      end

      def on_explored_leave(vertex, edge)
        return unless @mode == :route_local

        @walk_explored.delete(key(vertex, edge))
      end

      # Route-stack push/pop. These are no-ops in `:backtracking` mode so the
      # gates that read these stacks will always return false (testing against
      # empty sets).

      def push_node(vertex)
        @stack_nodes << vertex unless @mode == :backtracking
      end

      def pop_node(vertex)
        @stack_nodes.delete(vertex) unless @mode == :backtracking
      end

      def push_edge(edge)
        @stack_edges << edge unless @mode == :backtracking
      end

      def pop_edge(edge)
        @stack_edges.delete(edge) unless @mode == :backtracking
      end

      def push_exit(vertex, edge)
        return if @mode == :backtracking
        return unless vertex.is_a?(HexEdgeVertex)

        hex_exit = vertex.exit_for_edge(edge)
        @stack_exits << hex_exit if hex_exit
      end

      def pop_exit(vertex, edge)
        return if @mode == :backtracking
        return unless vertex.is_a?(HexEdgeVertex)

        @stack_exits.delete(vertex.exit_for_edge(edge))
      end

      private

      # The DFS visited set key. Stage 1 (`:backtracking`) keys on the vertex
      # alone; stages 2 and 3 key on `[vertex, incoming edge]`.
      def key(vertex, edge)
        @mode == :backtracking ? vertex : [vertex, edge]
      end
    end
  end
end
