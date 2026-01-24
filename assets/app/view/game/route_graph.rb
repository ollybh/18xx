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
            @game.route_graph.walk(corp)
          end

          children << h(:button, { on: { click: walk_graph } }, corp.id)
        end

        h(:div, children)
      end
    end
  end
end
