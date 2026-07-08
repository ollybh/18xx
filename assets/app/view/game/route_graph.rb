# frozen_string_literal: true

module View
  module Game
    class RouteGraph < Snabberb::Component
      needs :game

      def render
        add_graph = lambda do
          Native(`showD3Graph`).call(@game.route_graph.to_d3)
        end

        props = { hook: { insert: ->(_vnode) { add_graph.call } } }
        children = [render_buttons, h('svg#d3_graph')]

        h('div#route_graph', props, children)
      end

      def render_buttons
        corps = @game.corporations.reject(&:closed?).select(&:floated?).sort_by(&:id)
        buttons = corps.map do |corp|
          props = { on: { click: -> { walk_graph(corp) } } }
          h(:button, props, corp.id)
        end

        h(:div, buttons)
      end

      private

      def walk_graph(corp)
        walker = @game.route_graph.walker(corp)
        benchmark { walker.walk }
        puts walker.debug
      end

      def benchmark
        t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        yield
        t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        puts "Real: #{t1 - t0}"
      end
    end
  end
end
