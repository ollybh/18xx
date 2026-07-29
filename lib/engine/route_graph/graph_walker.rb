# frozen_string_literal: true

require_relative 'graph'
require_relative 'edge'
require_relative 'vertex'

module Engine
  module RouteGraph
    # A GraphWalker walks the {RouteGraph::Graph} for a specific entity,
    # calculating which of the graph’s {RouteGraph::Vertex vertices} and
    # {RouteGraph::Edge edges} can be reached. These are then used to calculate
    # the maps parts that are accessible: {Engine::Hex hexes}, {Part::Node nodes}
    # and {Part::Path paths}.
    #
    # The {RouteGraph::Graph} is an abstract representation of the game map's
    # topology. The GraphWalker is where the game rules are enforced, ensuring
    # that routes cannot reuse track or pass through tokened out cities.
    #
    # The walk is triggered lazily: creating a GraphWalker stores references to
    # the graph and entity but does not carry out any computation. The first
    # call to any of the query methods will trigger the DFS graph walk.
    # Subsequent calls to the query methods will returned cached data, until a
    # change in the underlying graph is detected. At this point the graph will
    # be re-run transparently. Callers never need to directly invoke the walk.
    #
    # The class is designed to be extensible: if a game needs different rules
    # for route finding then a GraphWalker subclass can be created, overriding a
    # few key methods to produce the desired behaviour:
    # - {#home_nodes} determines the starting locations for walking the graph.
    # - Then, once the walk is underway:
    #   - {#edge_blocked?} controls whether the walker may proceed along an edge.
    #     This blocks edges that are terminal, of an incompatible gauge, or
    #     already on the current route (track reuse via a non-immediate loop).
    #   - {#arrival_blocked?} controls whether a walker may explore a new vertex that
    #     is found. This blocks re-entry to a city/town already on the current
    #     route, and is also the hook for hex-entry restrictions.
    #   - {#departure_blocked?} controls whether switching from an incoming edge to
    #     an outgoing edge is allowed at a vertex. This prevents immediate
    #     reversal and checks for blocked cities.
    class GraphWalker
      # Creates a new GraphWalker object.
      # @param graph [RouteGraph::Graph] The route graph to be walked.
      # @param entity [Operator] The entity whose routes will be calculated by
      #   the GraphWalker.
      # @param statistics [Boolean] If true then walk instrumentation statistics
      #   will be collected.
      # @return [RouteGraph::GraphWalker] The new GraphWalker.
      def initialize(graph, entity, statistics: false)
        @graph = graph
        @entity = entity
        @graph_version = nil
        @stats = if statistics
                   {
                     dfs_calls: 0,
                     skipped: Hash.new(0),
                     edges_traversed: 0,
                     edges_skipped: Hash.new(0),
                   }
                 end

        # These two variables accumulate the final results of the graph walk:
        # the vertices and edges that are reachable by @entity.
        @connected_vertices = Set[]
        @connected_edges = Set[]

        # This accumulates the `[vertex, edge]` tuples that have been explored
        # from a home node when {#walk!} is called. This prevents the walker
        # getting stuck in infinite loops.
        @walk_explored = Set[]

        # These variables are stacks of items encountered whilst building a
        # route from a home node. These are used for rules enforcement, to check
        # that the current route being built is legal.
        #
        # These stacks have a push on entry/pop on exit lifecycle. They describe
        # the route from the home node to the current exploration tip. As the
        # DFS algorithm backtracks the removal of items from these stacks means
        # that alternate routes being explored from the same home node can
        # revisit the same vertices/edges that were explored earlier.
        #
        # Note: These stacks are maintained as sets. This works because they are
        # all being used to prevent an edge/node/hex exit from being revisited,
        # so there is never an attempt to add an item that is already in the set
        # -- this is prevented by the guard that checks the stack. If there is a
        # change that removes or relaxes the guard then the stack should be
        # changed to be a counter (`Hash.new(0)`) so that it can track multiple
        # visits to the same item.
        @stack_exits = Set[] # Hex exits crossed.
        @stack_edges = Set[] # Edges walked.
        @stack_nodes = Set[] # Node vertices visited.
      end

      # @!group Query Methods

      # Hexes where track can be laid.
      #
      # These hexes are a superset of those returned by {#reachable_hexes}. That
      # method finds the hexes that contain reachable track, this also includes:
      #  - Home hexes with no track.
      #  - Teleport destination hexes.
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

        extra_hexes = home_nodes.map(&:hex) # TODO: add teleport destinations
        extra_hexes.each { |hex| hexes_edges[hex] |= hex.neighbors.keys }

        @cache_hexes_edges = hexes_edges.freeze
      end

      # Nodes (cities, towns, offboards) that can be reached. Used to determine
      # where a corporation can place a token, merge, or establish connectivity
      # for other purposes (eg teleport abilities).
      #
      # @return [Set<Engine::Part::Node>]
      #   Returns a set containing each {Engine::Part::Node} that is reachable.
      def connected_nodes
        walk! if stale?

        @cache_nodes ||= @connected_vertices.grep(NodeVertex).to_set.freeze
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
      # unconnected home hexes and teleport token destinations.
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

      # Starting locations for walking the graph.
      # @return [Array<Engine::Part::Node>] The {Engine::Part::Node}s that are
      #   starting points for walking the graph.
      def home_nodes
        # TODO: This is just returning cities where @entity has a token. This
        # will be need to be enhanced as this isn't always going to be right.
        @entity.placed_tokens.map(&:city)

        # Code from Engine::Graph.compute to be included:
        # if @home_as_token && corporation.coordinates
        #   hexes.merge!(home_hexes(corporation))
        #   nodes.merge!(home_hex_nodes(corporation))
        # end
      end

      # Tests whether the walker is allowed to walk along an edge to reach the
      # vertex at the other end.
      #
      # Reasons why walking along the edge is blocked are:
      #  - The edge has already been walked on the current route.
      #  - The edge goes to a converging junction where one of the other paths
      #    has been walked.
      #  - The track path is terminal.
      #  - The track gauge is incompatible.
      #
      # @param edge [RouteGraph::Edge] The edge being walked.
      # @param from_vertex [RouteGraph::Vertex] The end that the walk is
      #   starting from.
      # @return [Boolean] True if the edge is blocked, false if it may be walked.
      def edge_blocked?(edge, from_vertex = nil)
        return true if edge.terminal?
        return true if @stack_edges.include?(edge)
        return true if backtracking_blocked?(edge, from_vertex)

        false
      end

      # Tests whether the walker, entering `vertex` on edge `from_edge` is
      # allowed to leave on edge `to_edge`.
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
          vertex.node.blocks?(@entity)
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
      # @param from_edge [RouteGraph::Edge] The edge being walked.
      # @return [Boolean] True if entry is blocked, false if it may be explored.
      def arrival_blocked?(vertex, _from_edge)
        return false unless vertex.is_a?(NodeVertex)

        @stack_nodes.include?(vertex)
      end

      # @!endgroup

      private

      # Walks the graph. Generally {#stale?} should be called first to check
      # whether the walker state is already up to date. This method will be
      # called automatically from the public node/hex/path accessor methods if
      # the walker is stale.
      # @return [void]
      def walk!
        @connected_vertices.clear
        @connected_edges.clear
        @cache_paths = nil
        @cache_nodes = nil
        @cache_hexes = nil
        @cache_hexes_edges = nil
        start = time if @stats

        home_nodes.each do |node|
          # TODO: Resetting @walk_explored here ensures that the graph is fully
          # walked from each home node, not stopping when previously walked
          # vertices/edges are encountered. Some games will not need this and
          # could get better performance by keeping the @walk_explored state.
          # This would only apply if there are no concerns like backtracking or
          # track gauges.
          @walk_explored.clear
          # Reset all the stacks. They *should* all be empty after the previous
          # walk finished, but there's almost no cost in doing this.
          @stack_exits.clear
          @stack_edges.clear
          @stack_nodes.clear

          vertex = @graph.vertices.find { |v| v.id == node.id }
          raise GameError, "Unable to find vertex for home node #{node.id}" unless vertex

          dfs(vertex)
        end

        # TODO: add extra nodes to @connected_vertices for :token and :teleport abilities.

        @graph_version = @graph.version
        @stats[:time] = time - start if @stats
      end

      # The core depth-first search algorithm for walking the graph.
      # This calls itself recursively for each new vertex it encounters.
      # @param vertex [RouteGraph::Vertex] The vertex to be explored.
      # @param incoming [RouteGraph::Edge, nil] The edge which was walked to
      #   reach this vertex. nil if the walk is starting at this vertex.
      # @return [void]
      def dfs(vertex, incoming = nil)
        @stats[:dfs_calls] += 1 if @stats
        if arrival_blocked?(vertex, incoming)
          @stats[:skipped][:arrival] += 1 if @stats
          return
        end
        if @walk_explored.include?([vertex, incoming])
          @stats[:skipped][:explored] += 1 if @stats
          return
        end

        @walk_explored << [vertex, incoming]
        @connected_vertices << vertex
        mark_crossed_exit(vertex, incoming)
        @stack_nodes << vertex if vertex.is_a?(NodeVertex)
        vertex.edges.each do |edge|
          if departure_blocked?(vertex, incoming, edge)
            @stats[:edges_skipped][:departure] += 1 if @stats
            next
          end
          if edge_blocked?(edge, vertex)
            @stats[:edges_skipped][:edge] += 1 if @stats
            next
          end

          @connected_edges << edge
          @stack_edges << edge
          @stats[:edges_traversed] += 1 if @stats
          dfs(edge.other_end(vertex), edge)
          @stack_edges.delete(edge)
        end
        @stack_nodes.delete(vertex) if vertex.is_a?(NodeVertex)
        unmark_crossed_exit(vertex, incoming)
      end

      # Checks whether walking an edge would involve crossing a HexExit that
      # is in on the crossed exits call stack. Crossing one of these exits
      # would involve revisiting a converging junction where one of the other
      # edges has already been walked in the current route being explored.
      #
      # A subclass that overrides this method to allow backtracking at
      # converging junctions will also need to override {#mark_crossed_exit} and
      # {#unmark_crossed_exit}. If this method allows revisiting HexExits then
      # the base implementation of {#mark_crossed_exit} will attempt to add a
      # duplicate to a set, leading to later corruption of the stack.
      #
      # @param edge [RouteGraph::Edge]
      # @param from_vertex [RouteGraph::Vertex]
      # @return [Boolean] True if traversal is blocked by an active exit.
      def backtracking_blocked?(edge, from_vertex)
        [from_vertex, edge.other_end(from_vertex)].any? do |vertex|
          next false unless vertex.is_a?(HexEdgeVertex)

          hex_exit = vertex.exit_for_edge(edge)
          hex_exit && @stack_exits.include?(hex_exit)
        end
      end

      # Marks a HexExit at a vertex as active on the call stack.
      # @param vertex [Vertex] The vertex being crossed.
      # @param edge [Edge] The edge that the walk has come from.
      def mark_crossed_exit(vertex, edge)
        return unless vertex.is_a?(HexEdgeVertex)

        hex_exit = vertex.exit_for_edge(edge)
        return unless hex_exit

        @stack_exits << hex_exit
      end

      # Unmarks a HexExit at a vertex after their subtree returns.
      # @param vertex [Vertex]
      # @param edge [Edge]
      def unmark_crossed_exit(vertex, edge)
        return unless vertex.is_a?(HexEdgeVertex)

        @stack_exits.delete(vertex.exit_for_edge(edge))
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
    end
  end
end
