# frozen_string_literal: true

require_relative 'entities'
require_relative 'map'
require_relative 'meta'
require_relative '../g_1858/game'

module Engine
  module Game
    module G18CH
      class Game < G1858::Game
        include_meta(G18CH::Meta)
        include Entities
        include Map

        CURRENCY_FORMAT_STR = '%sfr'
      end
    end
  end
end
