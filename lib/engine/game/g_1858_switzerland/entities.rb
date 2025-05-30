# frozen_string_literal: true

module Engine
  module Game
    module G1858Switzerland
      module Entities
        CORPORATIONS = [
          {
            sym: 'AB',
            name: 'Appenzeller Bahn',
            color: 'green',
            text_color: 'white',
            logo: '1858_switzerland/AB',
            float_percent: 40,
            type: '5-share',
            shares: [40, 20, 20, 20],
            always_market_price: true,
            capitalization: :incremental,
            tokens: [0, 20, 20],
          },
          {
            sym: 'STB',
            name: 'Sensetalbahn',
            logo: '1858_switzerland/STB',
            color: 'blue',
            text_color: 'white',
            float_percent: 40,
            type: '5-share',
            shares: [40, 20, 20, 20],
            always_market_price: true,
            capitalization: :incremental,
            tokens: [0, 20, 20],
            city: 2,
          },
          {
            sym: 'RhB',
            name: 'Rhätische Bahn',
            logo: '1858_switzerland/RhB',
            color: 'red',
            text_color: 'black',
            float_percent: 40,
            type: '5-share',
            shares: [40, 20, 20, 20],
            always_market_price: true,
            capitalization: :incremental,
            tokens: [0, 20, 20],
          },
          {
            sym: 'BLS',
            name: 'Bern Lötschberg Simplon',
            logo: '1858_switzerland/BLS',
            color: 'yellow',
            text_color: 'black',
            float_percent: 40,
            type: '5-share',
            shares: [40, 20, 20, 20],
            always_market_price: true,
            capitalization: :incremental,
            tokens: [0, 20, 20],
          },
          {
            sym: 'MOB',
            name: 'Montreux Oberland Bernois',
            logo: '1858_switzerland/MOB',
            color: 'saddlebrown',
            text_color: 'white',
            float_percent: 40,
            type: '5-share',
            shares: [40, 20, 20, 20],
            always_market_price: true,
            capitalization: :incremental,
            tokens: [0, 20, 20],
          },
          {
            sym: 'SBB',
            name: 'Schweizerische Bundesbahnen',
            logo: '1858_switzerland/SBB',
            color: 'red',
            text_color: 'black',
            floatable: false,
            type: 'national',
            hide_shares: true,
            capitalization: :none,
            tokens: [0, 0, 0, 0, 0],
          },
        ].freeze

        COMPANIES = [
          {
            sym: 'NB',
            name: 'Nordbahn',
            type: 'private_batch1',
            desc: 'P1. Revenue 14/21, face value 70. Home hexes are G4 and H5. ' \
                  'Can be used to start a public company in Zürich.',
            value: 70,
            discount: 15,
            revenue: 14,
            color: :yellow,
            text_color: :black,
            city: 1,
            abilities: [
              { type: 'no_buy' },
              { type: 'revenue_change', revenue: 21, on_phase: '3' },
              { type: 'reservation', hex: 'H5', city: 1 },
              {
                type: 'exchange',
                owner_type: 'player',
                when: 'owning_player_sr_turn',
                corporations: 'any',
                from: 'ipo',
              },
            ],
          },
          {
            sym: 'NOB',
            name: 'Nordostbahn',
            type: 'private_batch1',
            desc: 'P2. Revenue 24/36, face value 120. Home hexes are H3 and H5. ' \
                  'Can be used to start a public company in Zürich.',
            value: 120,
            discount: 25,
            revenue: 24,
            color: :yellow,
            text_color: :black,
            city: 0,
            abilities: [
              { type: 'no_buy' },
              { type: 'revenue_change', revenue: 36, on_phase: '3' },
              { type: 'reservation', hex: 'H5', city: 0 },
              {
                type: 'exchange',
                owner_type: 'player',
                when: 'owning_player_sr_turn',
                corporations: 'any',
                from: 'ipo',
              },
            ],
          },
          {
            sym: 'SCB',
            name: 'Centralbahn',
            type: 'private_batch1',
            desc: 'P3. Revenue 23/35, face value 115. Home hexes are E4, F5 and G6. ' \
                  'Can be used to start a public company in Basel.',
            value: 115,
            discount: 25,
            revenue: 23,
            color: :yellow,
            text_color: :black,
            abilities: [
              { type: 'no_buy' },
              { type: 'revenue_change', revenue: 35, on_phase: '3' },
              { type: 'reservation', hex: 'E4' },
              {
                type: 'exchange',
                owner_type: 'player',
                when: 'owning_player_sr_turn',
                corporations: 'any',
                from: 'ipo',
              },
            ],
          },
          {
            sym: 'VSB',
            name: 'Vereingtebahn',
            type: 'private_batch1',
            desc: 'P4. Revenue 21/32, face value 105. Home hexes are J5 and K4. ' \
                  'Can be used to start a public company in St Gallen.',
            value: 105,
            discount: 20,
            revenue: 21,
            color: :yellow,
            text_color: :black,
            abilities: [
              { type: 'no_buy' },
              { type: 'revenue_change', revenue: 32, on_phase: '3' },
              { type: 'reservation', hex: 'J5' },
              {
                type: 'exchange',
                owner_type: 'player',
                when: 'owning_player_sr_turn',
                corporations: 'any',
                from: 'ipo',
              },
            ],
          },
          {
            sym: 'LFB',
            name: 'Lausanne-Fribourg-Berne',
            type: 'private_batch1',
            desc: 'P5. Revenue 22/33, face value 110. Home hexes are C10 and D9. ' \
                  'Can be used to start a public company in Lausanne.',
            value: 110,
            discount: 20,
            revenue: 22,
            color: :yellow,
            text_color: :black,
            abilities: [
              { type: 'no_buy' },
              { type: 'revenue_change', revenue: 33, on_phase: '3' },
              { type: 'reservation', hex: 'C10' },
              {
                type: 'exchange',
                owner_type: 'player',
                when: 'owning_player_sr_turn',
                corporations: 'any',
                from: 'ipo',
              },
            ],
          },
          {
            sym: 'OS',
            name: 'Ouest Suisse',
            type: 'private_batch1',
            desc: 'P6. Revenue 16/24, face value 80. Home hexes are A12 and B11. ' \
                  'Can be used to start a public company in Genève.',
            value: 80,
            discount: 15,
            revenue: 16,
            color: :yellow,
            text_color: :black,
            abilities: [
              { type: 'no_buy' },
              { type: 'revenue_change', revenue: 24, on_phase: '3' },
              { type: 'reservation', hex: 'A12', slot: 0 },
              {
                type: 'exchange',
                owner_type: 'player',
                when: 'owning_player_sr_turn',
                corporations: 'any',
                from: 'ipo',
              },
            ],
          },
          {
            sym: 'BSB',
            name: 'Bernische Staatsbahn',
            type: 'private_batch1',
            desc: 'P7. Revenue 20/30, face value 100. Home hex is E8. ' \
                  'Can be used to start a public company in Bern.',
            value: 100,
            discount: 20,
            revenue: 20,
            color: :yellow,
            text_color: :black,
            abilities: [
              { type: 'no_buy' },
              { type: 'revenue_change', revenue: 30, on_phase: '3' },
              { type: 'reservation', hex: 'E8' },
              {
                type: 'exchange',
                owner_type: 'player',
                when: 'owning_player_sr_turn',
                corporations: 'any',
                from: 'ipo',
              },
            ],
          },
          {
            sym: 'BB',
            name: 'Bodelibahn',
            type: 'private_batch1',
            desc: 'P8. Revenue 12/18, face value 60. Home hex is F9. ' \
                  'Cannot be used to start a public company.',
            value: 60,
            discount: 10,
            revenue: 12,
            color: :yellow,
            text_color: :black,
            abilities: [
              { type: 'no_buy' },
              { type: 'revenue_change', revenue: 18, on_phase: '3' },
            ],
          },
          {
            sym: 'GB',
            name: 'Gotthardbahn',
            type: 'private_batch1',
            desc: 'P9. Revenue 13/20, face value 65. Home hexes are H9 and H11. ' \
                  'Cannot be used to start a public company.',
            value: 65,
            discount: 15,
            revenue: 13,
            color: :yellow,
            text_color: :black,
            abilities: [
              { type: 'no_buy' },
              { type: 'revenue_change', revenue: 20, on_phase: '3' },
            ],
          },
          {
            sym: 'BLB',
            name: 'Bern-Luzern-Bahn',
            type: 'private_batch1',
            desc: 'P10. Revenue 18/27, face value 90. Home hex is H7. ' \
                  'Can be used to start a public company in Luzern.',
            value: 90,
            discount: 20,
            revenue: 18,
            color: :yellow,
            text_color: :black,
            abilities: [
              { type: 'no_buy' },
              { type: 'revenue_change', revenue: 27, on_phase: '3' },
              { type: 'reservation', hex: 'H7' },
              {
                type: 'exchange',
                owner_type: 'player',
                when: 'owning_player_sr_turn',
                corporations: 'any',
                from: 'ipo',
              },
            ],
          },
          {
            sym: 'EB',
            name: 'Emmentalbahn',
            type: 'private_batch1',
            desc: 'P11. Revenue 11/17, face value 55. Home hex is E6. ' \
                  'Cannot be used to start a public company.',
            value: 55,
            discount: 10,
            revenue: 11,
            color: :yellow,
            text_color: :black,
            abilities: [
              { type: 'no_buy' },
              { type: 'revenue_change', revenue: 17, on_phase: '3' },
            ],
          },
          {
            sym: 'AFAI',
            name: 'Alta Italia',
            type: 'private_batch2',
            desc: 'P12. Revenue 40, face value 135. Home hex is I14. ' \
                  'Can be used to start a public company in Lugano.',
            value: 135,
            discount: 0,
            revenue: 40,
            color: :green,
            text_color: :black,
            abilities: [
              { type: 'no_buy' },
              { type: 'reservation', hex: 'I14' },
              {
                type: 'exchange',
                owner_type: 'player',
                when: 'owning_player_sr_turn',
                corporations: 'any',
                from: 'ipo',
              },
            ],
          },
          {
            sym: 'JN',
            name: 'Jura neuchatelois',
            type: 'private_batch2',
            desc: 'P13. Revenue 25, face value 85. Home hex is D7. ' \
                  'Cannot be used to start a public company.',
            value: 85,
            discount: 0,
            revenue: 25,
            color: :green,
            text_color: :black,
            abilities: [{ type: 'no_buy' }],
          },
          {
            sym: 'VZ',
            name: 'Visp-Zermatt',
            type: 'private_batch2',
            desc: 'P14. Revenue 22, face value 75. Home hexes are D13 and E12. ' \
                  'Cannot be used to start a public company.',
            value: 75,
            discount: 0,
            revenue: 22,
            color: :green,
            text_color: :black,
            abilities: [{ type: 'no_buy' }],
          },
          {
            sym: 'S',
            name: 'Simplon',
            type: 'private_batch3',
            desc: 'P15. Revenue 22, face value 55. Home hex is G14. ' \
                  'Cannot be used to start a public company.',
            value: 55,
            discount: 0,
            revenue: 22,
            color: :lightblue,
            text_color: :black,
            abilities: [{ type: 'no_buy' }],
          },
          {
            sym: 'L',
            name: 'Lötschberg',
            type: 'private_batch3',
            desc: 'P16. Revenue 26, face value 65. Home hex is F11. ' \
                  'Cannot be used to start a public company.',
            value: 65,
            discount: 0,
            revenue: 26,
            color: :lightblue,
            text_color: :black,
            abilities: [{ type: 'no_buy' }],
          },
          {
            sym: 'ChA',
            name: 'Chur-Arosa',
            type: 'private_batch3',
            desc: 'P17. Revenue 24, face value 60. Home hex is K8. ' \
                  'Cannot be used to start a public company.',
            value: 60,
            discount: 0,
            revenue: 24,
            color: :lightblue,
            text_color: :black,
            abilities: [{ type: 'no_buy' }],
          },
          {
            sym: 'FOB',
            name: 'Furka Oberalpbahn',
            type: 'private_batch3',
            desc: 'P18. Revenue 28, face value 70. Home hexes are G12, H11 and I10. ' \
                  'Cannot be used to start a public company.',
            value: 70,
            discount: 0,
            revenue: 28,
            color: :lightblue,
            text_color: :black,
            abilities: [{ type: 'no_buy' }],
          },
        ].freeze

        MINORS = [
          {
            sym: 'NB',
            name: 'Nordbahn',
            tokens: [],
            color: :yellow,
            text_color: :black,
            logo: '1858_switzerland/NB',
            coordinates: %w[H5 G4],
            city: 1,
            abilities: [
              { type: 'blocks_hexes', hexes: %w[G4], hidden: true },
              {
                type: 'exchange',
                owner_type: 'player',
                when: 'owning_player_sr_turn',
                corporations: 'ipoed',
                from: 'ipo',
              },
            ],
          },
          {
            sym: 'NOB',
            name: 'Nordostbahn',
            tokens: [],
            color: :yellow,
            text_color: :black,
            logo: '1858_switzerland/NOB',
            coordinates: %w[H5 H3],
            city: 0,
            abilities: [
              { type: 'blocks_hexes', hexes: %w[H3], hidden: true },
              {
                type: 'exchange',
                owner_type: 'player',
                when: 'owning_player_sr_turn',
                corporations: 'ipoed',
                from: 'ipo',
              },
            ],
          },
          {
            sym: 'SCB',
            name: 'Centralbahn',
            tokens: [],
            color: :yellow,
            text_color: :black,
            logo: '1858_switzerland/SCB',
            coordinates: %w[E4 F5 G6],
            abilities: [
              { type: 'blocks_hexes', hexes: %w[E4 F5 G6], hidden: true },
              {
                type: 'exchange',
                owner_type: 'player',
                when: 'owning_player_sr_turn',
                corporations: 'ipoed',
                from: 'ipo',
              },
            ],
          },
          {
            sym: 'VSB',
            name: 'Vereingtebahn',
            tokens: [],
            color: :yellow,
            text_color: :black,
            logo: '1858_switzerland/VSB',
            coordinates: %w[J5 K4],
            abilities: [
              { type: 'blocks_hexes', hexes: %w[J5 K4], hidden: true },
              {
                type: 'exchange',
                owner_type: 'player',
                when: 'owning_player_sr_turn',
                corporations: 'ipoed',
                from: 'ipo',
              },
            ],
          },
          {
            sym: 'LFB',
            name: 'Lausanne-Fribourg-Berne',
            tokens: [],
            color: :yellow,
            text_color: :black,
            logo: '1858_switzerland/LFB',
            coordinates: %w[C10 D9],
            abilities: [
              { type: 'blocks_hexes', hexes: %w[C10 D9], hidden: true },
              {
                type: 'exchange',
                owner_type: 'player',
                when: 'owning_player_sr_turn',
                corporations: 'ipoed',
                from: 'ipo',
              },
            ],
          },
          {
            sym: 'OS',
            name: 'Ouest Suisse',
            tokens: [],
            color: :yellow,
            text_color: :black,
            logo: '1858_switzerland/OS',
            coordinates: %w[A12 B11],
            abilities: [
              { type: 'blocks_hexes', hexes: %w[A12 B11], hidden: true },
              {
                type: 'exchange',
                owner_type: 'player',
                when: 'owning_player_sr_turn',
                corporations: 'ipoed',
                from: 'ipo',
              },
            ],
          },
          {
            sym: 'BSB',
            name: 'Bernische Staatsbahn',
            tokens: [],
            color: :yellow,
            text_color: :black,
            logo: '1858_switzerland/BSB',
            coordinates: %w[E8],
            abilities: [
              { type: 'blocks_hexes', hexes: %w[E8], hidden: true },
              {
                type: 'exchange',
                owner_type: 'player',
                when: 'owning_player_sr_turn',
                corporations: 'ipoed',
                from: 'ipo',
              },
            ],
          },
          {
            sym: 'BB',
            name: 'Bodelibahn',
            tokens: [],
            color: :yellow,
            text_color: :black,
            logo: '1858_switzerland/BB',
            coordinates: %w[F9],
            abilities: [
              { type: 'blocks_hexes', hexes: %w[F9], hidden: true },
              {
                type: 'exchange',
                owner_type: 'player',
                when: 'owning_player_sr_turn',
                corporations: 'ipoed',
                from: 'ipo',
              },
            ],
          },
          {
            sym: 'GB',
            name: 'Gotthardbahn',
            tokens: [],
            color: :yellow,
            text_color: :black,
            logo: '1858_switzerland/GB',
            coordinates: %w[H9 H11],
            abilities: [
              { type: 'blocks_hexes', hexes: %w[H9 H11], hidden: true },
              {
                type: 'exchange',
                owner_type: 'player',
                when: 'owning_player_sr_turn',
                corporations: 'ipoed',
                from: 'ipo',
              },
            ],
          },
          {
            sym: 'BLB',
            name: 'Bern-Luzern-Bahn',
            tokens: [],
            color: :yellow,
            text_color: :black,
            logo: '1858_switzerland/BLB',
            coordinates: %w[H7],
            abilities: [
              { type: 'blocks_hexes', hexes: %w[H7], hidden: true },
              {
                type: 'exchange',
                owner_type: 'player',
                when: 'owning_player_sr_turn',
                corporations: 'ipoed',
                from: 'ipo',
              },
            ],
          },
          {
            sym: 'EB',
            name: 'Emmentalbahn',
            tokens: [],
            color: :yellow,
            text_color: :black,
            logo: '1858_switzerland/EB',
            coordinates: %w[E6],
            abilities: [
              { type: 'blocks_hexes', hexes: %w[E6], hidden: true },
              {
                type: 'exchange',
                owner_type: 'player',
                when: 'owning_player_sr_turn',
                corporations: 'ipoed',
                from: 'ipo',
              },
            ],
          },
          {
            sym: 'AFAI',
            name: 'Alta Italia',
            tokens: [],
            color: :green,
            text_color: :black,
            logo: '1858_switzerland/AFAI',
            coordinates: %w[I14],
            abilities: [
              { type: 'blocks_hexes', hexes: %w[I14], hidden: true },
              {
                type: 'exchange',
                owner_type: 'player',
                when: 'owning_player_sr_turn',
                corporations: 'ipoed',
                from: 'ipo',
              },
            ],
          },
          {
            sym: 'JN',
            name: 'Jura neuchatelois',
            tokens: [],
            color: :green,
            text_color: :black,
            logo: '1858_switzerland/JN',
            coordinates: %w[D7],
            abilities: [
              { type: 'blocks_hexes', hexes: %w[D7], hidden: true },
              {
                type: 'exchange',
                owner_type: 'player',
                when: 'owning_player_sr_turn',
                corporations: 'ipoed',
                from: 'ipo',
              },
            ],
          },
          {
            sym: 'VZ',
            name: 'Visp-Zermatt',
            tokens: [],
            color: :green,
            text_color: :black,
            logo: '1858_switzerland/VZ',
            coordinates: %w[D13 E12],
            abilities: [
              { type: 'blocks_hexes', hexes: %w[D13 E12], hidden: true },
              {
                type: 'exchange',
                owner_type: 'player',
                when: 'owning_player_sr_turn',
                corporations: 'ipoed',
                from: 'ipo',
              },
            ],
          },
          {
            sym: 'S',
            name: 'Simplon',
            tokens: [],
            color: :lightblue,
            text_color: :black,
            logo: '1858_switzerland/S',
            coordinates: %w[G14],
            abilities: [
              { type: 'blocks_hexes', hexes: %w[G14], hidden: true },
              {
                type: 'exchange',
                owner_type: 'player',
                when: 'owning_player_sr_turn',
                corporations: 'ipoed',
                from: 'ipo',
              },
            ],
          },
          {
            sym: 'L',
            name: 'Lötschberg',
            tokens: [],
            color: :lightblue,
            text_color: :black,
            logo: '1858_switzerland/L',
            coordinates: %w[F11],
            abilities: [
              { type: 'blocks_hexes', hexes: %w[F11], hidden: true },
              {
                type: 'exchange',
                owner_type: 'player',
                when: 'owning_player_sr_turn',
                corporations: 'ipoed',
                from: 'ipo',
              },
            ],
          },
          {
            sym: 'ChA',
            name: 'Chur-Arosa',
            tokens: [],
            color: :lightblue,
            text_color: :black,
            logo: '1858_switzerland/ChA',
            coordinates: %w[K8],
            abilities: [
              { type: 'blocks_hexes', hexes: %w[K8], hidden: true },
              {
                type: 'exchange',
                owner_type: 'player',
                when: 'owning_player_sr_turn',
                corporations: 'ipoed',
                from: 'ipo',
              },
            ],
          },
          {
            sym: 'FOB',
            name: 'Furka Overalpbahn',
            tokens: [],
            color: :lightblue,
            text_color: :black,
            logo: '1858_switzerland/FOB',
            coordinates: %w[G12 H11 I10],
            abilities: [
              { type: 'blocks_hexes', hexes: %w[G12 I10], hidden: true },
              {
                type: 'exchange',
                owner_type: 'player',
                when: 'owning_player_sr_turn',
                corporations: 'ipoed',
                from: 'ipo',
              },
            ],
          },
        ].freeze

        PRIVATE_ORDER = {
          'NB' => 1,
          'NOB' => 2,
          'SCB' => 3,
          'VSB' => 4,
          'LFB' => 5,
          'OS' => 6,
          'BSB' => 7,
          'BB' => 8,
          'GB' => 9,
          'BLB' => 10,
          'EB' => 11,
          'AFAI' => 12,
          'JN' => 13,
          'VZ' => 14,
          'S' => 15,
          'L' => 16,
          'ChA' => 17,
          'FOB' => 18,
        }.freeze
      end
    end
  end
end
