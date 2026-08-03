# frozen_string_literal: true

module Engine
  module RouteGraph
    # Shared scaffold for GraphWalker specs.
    shared_context 'GraphWalker spec setup' do
      # `graph` and `walker` are deliberately lazy: they must not be
      # materialized until all tile-laying and token-placement for the current
      # test is complete. Tests that lay tiles or place tokens inside their `it`
      # body rely on `walker` being first referenced *after* that setup. Do not
      # reference `graph`/`walker` in a `before` block.
      subject(:walker)   { Engine::RouteGraph::GraphWalker.new(graph, alpha) }
      # `hexes` and `tiles` need to be defined at the example group or test level.
      let(:game)         { Game::Sandbox::Game.new(players, hexes: hexes, tiles: tiles, corporations: corporations) }
      let(:graph)        { Engine::RouteGraph::Graph.new(game) }
      let(:players)      { %w[Alice] }
      let(:corporations) { nil } # defaults to the Sandbox CORPORATIONS constant
      let(:alpha)        { game.corporation_by_id('α') }

      # Helper methods.
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
    end
  end
end
