# frozen_string_literal: true

module View
  module Game
    class RouteGraph < Snabberb::Component
      needs :game

      def render
        h('div#route_graph', [render_buttons, h('svg#d3_graph')])
      end

      def render_buttons
        add_graph = lambda do
          Native(`showD3Graph`).call(@game.route_graph.to_d3)
        end

        children = [h(:button, { on: { click: add_graph } }, 'Show graph')]
        @game.corporations.sort_by(&:id).each do |corp|
          next if corp.closed?
          next unless corp.floated?

          walk_graph = lambda do
            walker = @game.route_graph.walker(corp)
            benchmark { walker.walk }
            puts walker.debug
          end

          children << h(:button, { on: { click: walk_graph } }, corp.id)
        end

        h(:div, children)
      end

      private

      def benchmark
        t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        yield
        t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        puts "Real: #{t1 - t0}"
      end
    end
  end
end
