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
    #   - {#can_walk?} controls whether the walker may proceed along an edge.
    #     This checks for terminal paths and incompatible gauges.
    #   - {#can_enter?} controls whether a walker may explore a new vertex that
    #     is found. This checks for node re-entry.
    #   - {#can_traverse?} controls whether switching from an incoming edge to
    #     an outgoing edge is allowed at a vertex. This checks for track reuse
    #     at converging junctions.
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
        @stats = {} if statistics
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
      # @return [Hash{Engine::Hex => Array<integer>}]
      #   Returns a hash mapping each {Engine::Hex} that is reachable from the
      #   corporation's tokens to an array of integer edge numbers (0 to 5)
      #   indicating which sides of the hex are connected.
      #   Returns an empty hash if there are no reachable hexes.
      def connected_hexes
        walk! if stale?

        # TODO: implement this.
        @connected_hexes ||= {}
      end

      # Nodes (cities, towns, offboards) that can be reached. Used to determine
      # where a corporation can place a token, merge, or establish connectivity
      # for other purposes (eg teleport abilities).
      #
      # @return [Set<Engine::Part::Node>]
      #   Returns a set containing each {Engine::Part::Node} that is reachable.
      def connected_nodes
        walk! if stale?

        @connected_nodes ||= @found_vertices.grep(NodeVertex).to_set.freeze
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

        @connected_paths ||= @walked_edges.flat_map(&:paths).to_set.freeze
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

        @reachable_hexes ||= @walked_edges.flat_map(&:paths).to_set(&:hex).freeze
      end

      # @!endgroup

      # Allows access to the instrumentation statistics collected when walking
      # the graph.
      #
      # @return [Hash]
      #   - :time [integer] The time taken to walk the graph, in microseconds.
      def statistics
        return {} unless @stats

        {
          time: @stats[:time],
        }
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
      end

      # Tests whether the walker is allowed to walk along an edge to reach the
      # vertex at the other end. This is usually going to return true, but might
      # be false if the edge is marked as a terminal path, or the track gauge is
      # incompatible.
      #
      # @param edge [RouteGraph::Edge] The edge being walked.
      # @return [Boolean] True if the edge may be walked, false if not.
      def can_walk?(edge)
        !edge.terminal?
      end

      # Tests whether the walker, entering `vertex` on edge `from_edge` is
      # allowed to leave on edge `to_edge`.
      #
      # @param vertex [RouteGraph::Vertex] The vertex the walker is currently
      #   exploring.
      # @param from_edge [RouteGraph::Edge, nil] The last edge to have been
      #   walked. nil if the walk is starting at this vertex.
      # @param to_edge [RouteGraph::Edge] The edge to be tested.
      # @return [Boolean] True if the walker may leave this vertex along
      #   `to_edge`.
      def can_traverse?(vertex, from_edge, _to_edge)
        return true unless from_edge

        case vertex
        when HexEdgeVertex, JunctionVertex
          true
        when NodeVertex
          !vertex.node.blocks?(@entity)
        end
      end

      # Tests whether the walker when walking an edge is allowed to reach the
      # vertex at the other end of the edge. This will usually return true. This
      # could return false if entry to a hex is blocked (eg 1861/1867/1807
      # blocking reentry to a hex where a route has already passed through a
      # city on the same hex).
      #
      # This is not the same test as {#can_traverse?}: that method is
      # called once the vertex has been reached and we are checking which edges
      # the walk can continue along. This method is called before vertex is
      # added to the set of explored vertices, if it returns false the vertex
      # will not be added.
      #
      # @param vertex [RouteGraph::Vertex] The vertex the walk is about to reach.
      # @param from_edge [RouteGraph::Edge] The edge being walked.
      # @return [Boolean] True if vertex can be explored, false if entry is
      #   blocked.
      def can_enter?(_vertex, _from_edge)
        true
      end

      # @!endgroup

      private

      # Walks the graph. Generally {#stale?} should be called first to check
      # whether the walker state is already up to date. This method will be
      # called automatically from the public node/hex/path accessor methods if
      # the walker is stale.
      # @return [void]
      def walk!
        @explored = Set[]
        @found_vertices = Set[]
        @walked_edges = Set[]
        start = time if @stats

        home_nodes.each do |node|
          vertex = @graph.vertices.find { |v| v.id == node.id }
          dfs(vertex)
        end

        @stats[:time] = time - start if @stats
      end

      # The core depth-first search algorithm for walking the graph.
      # This calls itself recursively for each new vertex it encounters.
      # @param vertex [RouteGraph::Vertex] The vertex to be explored.
      # @param incoming [RouteGraph::Edge] The edge which was walked to reach
      #   this vertex. nil if the walk is starting at this vertex.
      # @return [void]
      def dfs(vertex, incoming = nil)
        return unless can_enter?(vertex, incoming)
        return if @explored.include?([vertex, incoming])

        @explored << [vertex, incoming]
        @found_vertices << vertex
        vertex.edges.each do |edge|
          next unless can_traverse?(vertex, incoming, edge)
          next unless can_walk?(edge)

          @walked_edges << edge
          destination = edge.other_end(vertex)
          dfs(destination, edge)
        end
      end

      # Checks whether the GraphWalker is synchronised with the current graph
      # model. If not then {#walk!} will need to be called to update the
      # walker's state.
      # @return [Boolean] True if the graph has been walked since the latest
      #   graph updates. False if the graph has not yet been walked, or if graph
      #   has been updated since the last walk.
      def stale?
        # TODO: implement this. At the moment the graph will be worked each time
        # any of the connected/reachable methods is called. This will ensure
        # that the results are correct, but at the cost of re-walking the graph.
        true
      end

      # Reads the system clock.
      # @return [integer]
      def time
        Process.clock_gettime(Process::CLOCK_MONOTONIC, :microsecond)
      end
    end
  end
end
