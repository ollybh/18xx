# frozen_string_literal: true

require_relative '../meta'

module Engine
  module Game
    module Sandbox
      module Meta
        include Game::Meta

        GAME_TITLE = 'Sandbox'
        GAME_LOCATION = 'The sandbox'
        DEV_STAGE = :prealpha
        PROTOTYPE = true
        PLAYER_RANGE = [1, 20].freeze
      end
    end
  end
end
