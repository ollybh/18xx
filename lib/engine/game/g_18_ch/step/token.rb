# frozen_string_literal: true

require_relative '../../g_1858/step/token'

module Engine
  module Game
    module G18CH
      module Step
        class Token < G1858::Step::Token
          # These are the number of provincial borders crossed when travelling between cities.
          # This is done as a 2D hash of city coordinates. The rows and columns are ordered
          # by province:
          #   1. Genève (Genève)
          #   2. Vaud (Lausanne)
          #   3. Bern (Bern)
          #   4. Basel (Basel)
          #   5. Zürich (Zürich and Winterthur)
          #   6. Luzern (Luzern)
          #   7. Ticino (Lugano)
          #   8. St Gallen (St Gallen)
          # rubocop: disable Layout/HashAlignment
          DISTANCES = {
            'A12' => { 'A12' => 0, 'C10' => 1, 'E8' => 2, 'E4' => 3, 'H5' => 4, 'I4' => 4, 'H7' => 3, 'I14' => 3, 'J5' => 4 },
            'C10' => { 'A12' => 1, 'C10' => 0, 'E8' => 1, 'E4' => 2, 'H5' => 3, 'I4' => 3, 'H7' => 2, 'I14' => 2, 'J5' => 3 },
            'E8'  => { 'A12' => 2, 'C10' => 1, 'E8' => 0, 'E4' => 1, 'H5' => 2, 'I4' => 2, 'H7' => 1, 'I14' => 2, 'J5' => 2 },
            'E4'  => { 'A12' => 3, 'C10' => 2, 'E8' => 1, 'E4' => 0, 'H5' => 1, 'I4' => 1, 'H7' => 1, 'I14' => 3, 'J5' => 2 },
            'H5'  => { 'A12' => 4, 'C10' => 3, 'E8' => 2, 'E4' => 1, 'H5' => 0, 'I4' => 0, 'H7' => 1, 'I14' => 3, 'J5' => 1 },
            'I4'  => { 'A12' => 4, 'C10' => 3, 'E8' => 2, 'E4' => 1, 'H5' => 0, 'I4' => 0, 'H7' => 1, 'I14' => 3, 'J5' => 1 },
            'H7'  => { 'A12' => 3, 'C10' => 2, 'E8' => 1, 'E4' => 1, 'H5' => 1, 'I4' => 1, 'H7' => 0, 'I14' => 2, 'J5' => 1 },
            'I14' => { 'A12' => 3, 'C10' => 2, 'E8' => 2, 'E4' => 3, 'H5' => 3, 'I4' => 3, 'H7' => 2, 'I14' => 0, 'J5' => 2 },
            'J5'  => { 'A12' => 4, 'C10' => 3, 'E8' => 2, 'E4' => 2, 'H5' => 1, 'I4' => 1, 'H7' => 1, 'I14' => 2, 'J5' => 0 },
          }.freeze
          # rubocop: enable Layout/HashAlignment
        end
      end
    end
  end
end
