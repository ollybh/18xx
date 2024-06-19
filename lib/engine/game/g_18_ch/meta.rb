# frozen_string_literal: true

require_relative '../meta'

module Engine
  module Game
    module G18CH
      module Meta
        include Game::Meta

        DEV_STAGE = :prealpha
        PROTOTYPE = true
        DEPENDS_ON = '1858'

        GAME_TITLE = '18CH'
        GAME_SUBTITLE = 'The Railways of Switzerland'
        GAME_DESIGNER = 'Ian D Wilson'
        GAME_LOCATION = 'Switzerland'
        GAME_INFO_URL = 'https://github.com/tobymao/18xx/wiki/18CH'
        GAME_IMPLEMENTER = 'Oliver Burnett-Hall'

        PLAYER_RANGE = [3, 6].freeze
      end
    end
  end
end
