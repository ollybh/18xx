# frozen_string_literal: true

require 'spec_helper'
require_relative 'graph_walker/context'
require_relative 'graph_walker/graph_walker'
require_relative 'graph_walker/converging'
require_relative 'graph_walker/highly_connected'
require_relative 'graph_walker/teleport'
require_relative 'graph_walker/terminal'

module Engine
  module RouteGraph
    describe GraphWalker, :graph do
      include_context 'GraphWalker spec setup'

      it_behaves_like 'a GraphWalker'
      it_behaves_like 'a GraphWalker on converging junctions'
      it_behaves_like 'a GraphWalker on highly connected maps'
      it_behaves_like 'a GraphWalker with teleport token abilities'
      it_behaves_like 'a GraphWalker on terminal track'
    end
  end
end
