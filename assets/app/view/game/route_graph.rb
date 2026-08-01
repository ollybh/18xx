# frozen_string_literal: true

require 'engine/route_graph/comparator'

module View
  module Game
    class RouteGraph < Snabberb::Component
      needs :game
      needs :production, default: false

      def render
        return h('div#route_graph') if @production

        add_graph = lambda do
          graph = @game.route_graph
          log("Graph built in #{comma_number(graph.statistics[:time])} µs.")

          parent = Native(`document.getElementById('route_graph')`)
          width = parent.clientWidth
          height = parent.clientHeight
          Native(`showD3Graph`).call(graph.to_d3(width, height))
        end
        props = { hook: { insert: ->(_vnode) { add_graph.call } } }

        children = [
          render_buttons,
          h('div#graph_log'),
          h('svg#d3_graph'),
        ]

        h('div#route_graph', props, children)
      end

      def render_buttons
        corps = @game.corporations.reject(&:closed?).select(&:floated?).sort_by(&:id)
        buttons = corps.map do |corp|
          props = { on: { click: -> { walk_graph(corp) } } }
          h(:button, props, corp.id)
        end
        buttons << h(:button, { on: { click: -> { clear_graph } } }, 'Clear')

        h('div#graph_buttons', buttons)
      end

      private

      def walk_graph(corp)
        walker = @game.graph_walker(corp)
        _ = walker.reachable_hexes
        log("Graph walked for #{corp.id} in #{comma_number(walker.statistics[:time])} µs")

        c = Engine::RouteGraph::Comparator.compare(@game, corp)
        c.each { |k, v| log("#{k}: #{v}") }

        ids = @game.route_graph.d3_highlight(walker)
        Native(`highlightConnected`).call(ids[:nodes].to_n, ids[:links].to_n)
      end

      # Remove the current highlight without re-walking. Toggles the
      # +.highlight+ class off every node and link.
      def clear_graph
        Native(`highlightConnected`).call([].to_n, [].to_n)
      end

      def log(text)
        Native(`d3.select('#graph_log')`).append('div').text(text)
      end

      # Adds thousand separators to an integer.
      def comma_number(n)
        n.to_s.gsub(/(\d)(?=(?:\d{3})+$)/, '\1,')
      end
    end
  end
end
