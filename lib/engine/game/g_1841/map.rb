# frozen_string_literal: true

require_relative 'meta'
require_relative '../base'

module Engine
  module Game
    module G1841
      module Map
        LAYOUT = :flat

        # rubocop:disable Layout/LineLength
        def game_tiles
          tiles = {
            '1' => 1,
            '2' => 1,
            '3' => 3,
            '4' => 3,
            '5' => 4,
            '6' => 4,
            '7' => 8,
            '8' => 16,
            '9' => 11,
            '12' => 1,
            '13' => 1,
            '14' => 2,
            '15' => 2,
            '16' => 2,
            '17' => 2,
            '18' => 2,
            '19' => 2,
            '20' => 2,
            '21' => 2,
            '22' => 2,
            '23' => 3,
            '24' => 3,
            '25' => 3,
            '26' => 2,
            '27' => 2,
            '28' => 2,
            '29' => 2,
            '30' => 2,
            '31' => 2,
            '39' => 2,
            '40' => 2,
            '41' => 2,
            '42' => 2,
            '43' => 2,
            '44' => 2,
            '45' => 2,
            '46' => 2,
            '47' => 2,
            '55' => 1,
            '56' => 1,
            '57' => 4,
            '58' => 3,
            '63' => 3,
            '69' => 1,
            '70' => 2,
            '87' => 2,
            '88' => 2,
            '144' => 2,
            '201' => 2,
            '202' => 2,
            '204' => 2,
            '205' => 1,
            '206' => 1,
            '207' => 2,
            '208' => 2,
            '216' => 2,
            '601' =>
            {
              'count' => 1,
              'color' => 'yellow',
              'code' => 'city=revenue:10,loc:center;town=revenue:20;path=a:1,b:_0;path=a:_1,b:5;path=a:_0,b:_1;label=V',
            },
            '602' =>
            {
              'count' => 1,
              'color' => 'green',
              'code' => 'city=revenue:10,loc:center;town=revenue:30;path=a:0,b:_0;path=a:2,b:_0;path=a:3,b:_0;path=a:_1,b:4;path=a:_0,b:_1;label=V',
            },
            '603' =>
            {
              'count' => 1,
              'color' => 'brown',
              'code' => 'city=revenue:20,loc:center;town=revenue:30;path=a:0,b:_0;path=a:1,b:_0;path=a:2,b:_0;path=a:3,b:_0;path=a:5,b:_0;path=a:_1,b:4;path=a:_0,b:_1;label=V',
            },
            '604' => 1,
            '605' => 1,
            '606' => 1,
            '607' => 1,
            '608' =>
            {
              'count' => 1,
              'color' => 'green',
              'code' => 'city=revenue:40;path=a:0,b:_0;path=a:3,b:_0;label=G',
            },
            '609' => 1,
            '610' =>
            {
              'count' => 2,
              'color' => 'brown',
              'code' => 'pass=revenue:0,size:2;path=a:0,b:_0;path=a:3,b:_0',
            },
            '611' => 3,
            '612' => 1,
            '613' =>
            {
              'count' => 3,
              'color' => 'green',
              'code' => 'pass=revenue:0;path=a:0,b:_0;path=a:3,b:_0;upgrade=cost:50',
            },
            '614' =>
            {
              'count' => 4,
              'color' => 'green',
              'code' => 'pass=revenue:0;path=a:0,b:_0;path=a:2,b:_0;upgrade=cost:50',
            },
            '615' =>
            {
              'count' => 1,
              'color' => 'green',
              'code' => 'pass=revenue:0;path=a:0,b:_0;path=a:1,b:_0;upgrade=cost:50',
            },
            '616' =>
            {
              'count' => 1,
              'color' => 'brown',
              'code' => 'pass=revenue:0,slots:2;path=a:0,b:_0;path=a:1,b:_0;path=a:3,b:_0;path=a:4,b:_0',
            },
            '617' =>
            {
              'count' => 1,
              'color' => 'brown',
              'code' => 'pass=revenue:0,slots:2;path=a:0,b:_0;path=a:1,b:_0;path=a:2,b:_0;path=a:3,b:_0',
            },
            '618' =>
            {
              'count' => 1,
              'color' => 'brown',
              'code' => 'pass=revenue:0,slots:2;path=a:0,b:_0;path=a:2,b:_0;path=a:3,b:_0;path=a:4,b:_0',
            },
            '619' => 2,
            '621' => 2,
            '622' => 2,
            '623' => 2,
            '624' => 1,
            '625' => 1,
            '626' => 1,
            '627' => 2,
            '628' => 2,
            '629' => 2,
            '630' => 1,
            '631' => 1,
            '632' => 1,
            '633' => 1,
          }

          if version == 1
            tiles.delete('612')
          else
            tiles.delete('608')
          end

          tiles
        end
        # rubocop:enable Layout/LineLength

        NO_ROTATION_TILES = %w[
          601
        ].freeze

        def init_location_names
          location_names = {
            E1: 'Lyon',
            G1: 'Fréjus',
            E3: 'Aosta',
            M3: 'Cuneo',
            a4: 'Lausanne & Lötschberg',
            H4: 'Torino',
            P4: 'Marseille',
            A5: 'Simplon',
            I5: 'Asti',
            F6: 'Vercelli & Novara',
            J6: 'Alessandria',
            N6: 'Savona',
            A7: 'Gotthard',
            C7: 'Lugano',
            E7: 'Busto Arsizio',
            M7: 'Genova',
            D8: 'Como',
            F8: 'Milano',
            H8: 'Pavia',
            E9: 'Bergamo',
            I9: 'Piacenza',
            H10: 'Cremona',
            P10: 'La Spezia',
            A11: 'Tirano & Edolo',
            E11: 'Brescia',
            K11: 'Parma',
            H12: 'Mantova',
            L12: "Reggio nell'Emilia",
            C13: 'Trento & Brennero',
            G13: 'Verona',
            K13: 'Modena',
            F14: 'Vicenza',
            L14: 'Bologna',
            G15: 'Padova',
            I15: 'Rovigo',
            K15: 'Ferrara',
            F16: 'Venezia',
            D16: 'Treviso',
            L16: 'Ravenna',
            N16: 'Forli & Cesena',
            E17: 'East',
            O17: 'Adriatic Coast',
          }

          location_names[:O5] = 'Albenga' if version == 2

          unless lite?
            location_names.merge!(
              S11: 'Livorno',
              Q13: 'Pistoia & Prato',
              Q11: 'Pisa',
              P12: 'Lucca',
              R14: 'Firenze',
              S15: 'Arezzo',
              T14: 'Siena',
              U13: 'Roma',
            )
          end

          location_names[:P12] = 'Tuscana - Roma' if lite?

          location_names
        end

        def game_location_names
          @game_location_names ||= init_location_names
        end

        def location_name(coord)
          game_location_names[coord]
        end

        # rubocop:disable Layout/LineLength
        def game_hexes
          if version == 1
            firenze = 'city=revenue:30,loc:0;city=revenue:30,loc:3;path=a:_0,b:1;path=a:_1,b:2;label=Y'
            cuneo = 'city=revenue:0;upgrade=cost:50,terrain:mountain;label=Y;border=edge:0,type:impassable'
            o3 = 'pass=revenue:0;upgrade=cost:100;border=edge:3,type:impassable'
            n4 = 'upgrade=cost:50,terrain:mountain;border=edge:5,type:impassable'
            o5 = 'upgrade=cost:50,terrain:mountain;border=edge:2,type:impassable;border=edge:3,type:impassable'
          else
            firenze = 'city=revenue:30,loc:5;city=revenue:30,loc:2.5;path=a:_0,b:1;path=a:_0,b:5;path=a:_1,b:2;label=Y'
            cuneo = 'city=revenue:30;path=a:_0,b:3;path=a:_0,b:4;path=a:_0,b:5;upgrade=cost:50,terrain:mountain;label=Y'
            o3 = 'pass=revenue:0;upgrade=cost:100'
            n4 = 'upgrade=cost:50,terrain:mountain'
            o5 = 'town=revenue:0;upgrade=cost:50,terrain:mountain;border=edge:3,type:impassable'
          end

          ghexes = if !lite?
                     {
                       white: {
                         # no cities, towns
                         %w[D4 E5 E15 F10 G5 G7 G9 G11 H6 H14 H16 I3 I7 I11 I13 J4 J12 J14 K3 K5 L4 M15 R12 S13 T12] => '',
                         %w[I1 L2 J8 M13 O15 P16] => 'upgrade=cost:50,terrain:mountain',
                         %w[N4] => n4,
                         %w[K9] => 'border=edge:5,type:impassable;upgrade=cost:50,terrain:mountain',
                         %w[B16 J16] => 'upgrade=cost:50,terrain:swamp',
                         %w[A9 J10 N14] => 'border=edge:0,type:impassable',
                         %w[F4] => 'border=edge:2,type:impassable',
                         %w[D6] => 'border=edge:4,type:impassable',
                         %w[B6] => 'border=edge:5,type:impassable',
                         %w[B8] => 'border=edge:0,type:impassable;border=edge:1,type:impassable',
                         %w[F12 L10] => 'border=edge:2,type:impassable;border=edge:3,type:impassable',
                         %w[H2] => 'border=edge:2,type:impassable;border=edge:4,type:impassable;upgrade=cost:50,terrain:mountain',
                         %w[N8 O9] => 'border=edge:3,type:impassable;border=edge:4,type:impassable;upgrade=cost:50,terrain:mountain',
                         %w[G3] => 'border=edge:0,type:impassable;border=edge:1,type:impassable;border=edge:3,type:impassable',
                         %w[B10] => 'border=edge:0,type:impassable;border=edge:1,type:impassable;border=edge:5,type:impassable',
                         %w[C9] => 'border=edge:3,type:impassable;border=edge:4,type:impassable;border=edge:5,type:impassable',
                         %w[C11] => 'border=edge:2,type:impassable;border=edge:5,type:impassable;border=edge:0,type:impassable',
                         %w[E13] => 'border=edge:0,type:impassable;border=edge:2,type:impassable;border=edge:4,type:impassable;border=edge:5,type:impassable',
                         # towns
                         %w[I5 I9 I15] => 'town=revenue:0',
                         %w[L16] => 'town=revenue:0;upgrade=cost:50,terrain:swamp',
                         %w[N6] => 'town=revenue:0;upgrade=cost:50,terrain:mountain;border=edge:3,type:impassable',
                         %w[O5] => o5,
                         %w[P10 T14] => 'town=revenue:0;border=edge:4,type:impassable',
                         %w[S15] => 'town=revenue:0;border=edge:1,type:impassable;border=edge:3,type:impassable',
                         %w[F6 N16 Q13] => 'town=revenue:0;town=revenue:0',
                         # cities
                         %w[D16 E7 H8 H10 H12 J6 K11 K13 K15 L12 S11] => 'city=revenue:0',
                         %w[E9 G15 L14] => 'city=revenue:0;label=Y',
                         %w[F16] => 'city=revenue:0;town=revenue:0,loc:5;upgrade=cost:50,terrain:swamp;label=V',
                         %w[F14] => 'city=revenue:0;border=edge:2,type:impassable',
                         %w[D8] => 'city=revenue:0;border=edge:3,type:impassable',
                         %w[G13] => 'city=revenue:0;border=edge:3,type:impassable;label=Y',
                         %w[C7] => 'city=revenue:0;border=edge:1,type:impassable;border=edge:2,type:impassable;border=edge:4,type:impassable',
                         %w[E11] => 'city=revenue:0;border=edge:3,type:impassable;border=edge:5,type:impassable;label=Y',
                       },
                       yellow: {
                         # passes
                         %w[C15 K7 M11 N12] => 'pass=revenue:0;upgrade=cost:100',
                         %w[O3] => o3,
                         %w[D14] => 'pass=revenue:0;border=edge:1,type:impassable;upgrade=cost:100',
                         %w[L6 M5 Q15] => 'pass=revenue:0;border=edge:0,type:impassable;upgrade=cost:100',
                         %w[O13] => 'pass=revenue:0;border=edge:5,type:impassable;upgrade=cost:100',
                         %w[O11] => 'pass=revenue:0;border=edge:0,type:impassable;border=edge:1,type:impassable;upgrade=cost:100',
                         %w[N10] => 'pass=revenue:0;border=edge:1,type:impassable;border=edge:2,type:impassable;upgrade=cost:100',
                         %w[P14] => 'pass=revenue:0;border=edge:2,type:impassable;border=edge:3,type:impassable;upgrade=cost:100',
                         %w[D12] => 'pass=revenue:0;border=edge:0,type:impassable;border=edge:2,type:impassable;border=edge:5,type:impassable;upgrade=cost:100',
                         %w[L8] => 'pass=revenue:0;border=edge:0,type:impassable;border=edge:1,type:impassable;border=edge:5,type:impassable;upgrade=cost:100',
                         %w[M9] => 'pass=revenue:0;border=edge:0,type:impassable;border=edge:1,type:impassable;border=edge:2,type:impassable;border=edge:5,type:impassable;upgrade=cost:100',
                         # cities
                         %w[F8] => 'city=revenue:60;path=a:_0,b:3,terminal:1;path=a:_0,b:4,terminal:1;label=M',
                         %w[P12] => 'city=revenue:20;path=a:_0,b:1;path=a:_0,b:5',
                         %w[H4] => 'city=revenue:40,loc:1;city=revenue:40,loc:3.5;path=a:_0,b:1;path=a:_0,b:5;path=a:_1,b:4;label=T',
                         %w[R14] => firenze,
                         %w[M3] => cuneo,
                         %w[Q11] => 'city=revenue:20;path=a:_0,b:0;path=a:_0,b:5;path=a:_0,b:4;border=edge:3,type:impassable',
                         %w[M7] => 'city=revenue:0;border=edge:4,type:impassable;upgrade=cost:50,terrain:mountain;label=G',
                       },
                       green: {
                         %w[A5] => 'pass=revenue:0,size:2;upgrade=cost:200',
                         %w[G1] => 'pass=revenue:0,size:2;border=edge:5,type:impassable;upgrade=cost:200',
                       },
                       gray: {
                         %w[A11] => 'town=revenue:20;town=revenue:10;path=a:_0,b:1;path=a:_1,b:0',
                         %w[D10] => 'path=a:0,b:1;path=a:1,b:4;path=a:4,b:5;border=edge:2,type:impassable;border=edge:3,type:impassable',
                         %w[E3] => 'town=revenue:10;path=a:_0,b:4;border=edge:0,type:impassable;border=edge:5,type:impassable',
                       },
                       red: {
                         %w[a4] => 'offboard=revenue:white_0|gray_90|black_150;path=a:_0,b:5',
                         %w[A7] => 'offboard=revenue:white_20|gray_30|black_150;path=a:_0,b:0',
                         %w[C13] => 'offboard=revenue:white_20|gray_70|black_140,groups:Trento;path=a:_0,b:0;path=a:_0,b:1;path=a:_0,b:5',
                         %w[B14] => 'offboard=revenue:white_20|gray_70|black_140,groups:Trento,hide:1;path=a:_0,b:5',
                         %w[E1] => 'offboard=revenue:white_0|gray_140|black_200;path=a:_0,b:0',
                         %w[E17] => 'offboard=revenue:white_50|gray_80|black_120,groups:East;path=a:_0,b:1;path=a:_0,b:2',
                         %w[C17] => 'offboard=revenue:white_50|gray_80|black_120,groups:East,hide:1;path=a:_0,b:1',
                         %w[O17] => 'offboard=revenue:white_10|gray_70|black_150;path=a:_0,b:1;path=a:_0,b:2',
                         %w[P4] => 'offboard=revenue:white_60|gray_100|black_150,groups:Marseille',
                         %w[Q3 Q5] => 'offboard=revenue:white_60|gray_100|black_150,groups:Marseille,hide:1;path=a:_0,b:3',
                         %w[U13] => 'offboard=revenue:white_10|gray_40|black_200,groups:Roma',
                         %w[U15 V12 V14] => 'offboard=revenue:white_10|gray_40|black_200,groups:Roma,hide:1;path=a:_0,b:3',
                       },
                       blue: {
                         %w[G17] => 'town=revenue:40,route:never,loc:2;path=a:_0,b:2;icon=image:port',
                         %w[M17] => 'town=revenue:20,route:never,loc:2;path=a:_0,b:2;icon=image:port',
                         %w[O7] => 'town=revenue:70,route:never,loc:3;path=a:_0,b:3;icon=image:port',
                         %w[P6] => 'town=revenue:10,route:never,loc:3;path=a:_0,b:3;icon=image:port',
                         %w[Q9] => 'town=revenue:10,route:never,loc:4;path=a:_0,b:4;icon=image:port',
                         %w[T10] => 'town=revenue:20,route:never,loc:4;path=a:_0,b:4;icon=image:port',
                       },
                     }
                   else
                     # lite map
                     {
                       white: {
                         # no cities, towns
                         %w[D4 E5 E15 F10 G5 G7 G9 G11 H6 H14 H16 I3 I7 I11 I13 J4 J12 J14 K3 K5 L4 N14 M15] => '',
                         %w[I1 L2 J8 M13 O15 P16] => 'upgrade=cost:50,terrain:mountain',
                         %w[N4] => n4,
                         %w[K9] => 'border=edge:5,type:impassable;upgrade=cost:50,terrain:mountain',
                         %w[B16 J16] => 'upgrade=cost:50,terrain:swamp',
                         %w[A9 J10] => 'border=edge:0,type:impassable',
                         %w[F4] => 'border=edge:2,type:impassable',
                         %w[D6] => 'border=edge:4,type:impassable',
                         %w[B6] => 'border=edge:5,type:impassable',
                         %w[B8] => 'border=edge:0,type:impassable;border=edge:1,type:impassable',
                         %w[F12 L10] => 'border=edge:2,type:impassable;border=edge:3,type:impassable',
                         %w[H2] => 'border=edge:2,type:impassable;border=edge:4,type:impassable;upgrade=cost:50,terrain:mountain',
                         %w[N8 O9] => 'border=edge:3,type:impassable;border=edge:4,type:impassable;upgrade=cost:50,terrain:mountain',
                         %w[G3] => 'border=edge:0,type:impassable;border=edge:1,type:impassable;border=edge:3,type:impassable',
                         %w[B10] => 'border=edge:0,type:impassable;border=edge:1,type:impassable;border=edge:5,type:impassable',
                         %w[C9] => 'border=edge:3,type:impassable;border=edge:4,type:impassable;border=edge:5,type:impassable',
                         %w[C11] => 'border=edge:2,type:impassable;border=edge:5,type:impassable;border=edge:0,type:impassable',
                         %w[E13] => 'border=edge:0,type:impassable;border=edge:2,type:impassable;border=edge:4,type:impassable;border=edge:5,type:impassable',
                         # towns
                         %w[I5 I9 I15] => 'town=revenue:0',
                         %w[L16] => 'town=revenue:0;upgrade=cost:50,terrain:swamp',
                         %w[N6] => 'town=revenue:0;upgrade=cost:50,terrain:mountain;border=edge:3,type:impassable',
                         %w[O5] => o5,
                         %w[P10] => 'town=revenue:0;border=edge:4,type:impassable',
                         %w[F6 N16] => 'town=revenue:0;town=revenue:0',
                         # cities
                         %w[D16 E7 H8 H10 H12 J6 K11 K13 K15 L12] => 'city=revenue:0',
                         %w[E9 G15 L14] => 'city=revenue:0;label=Y',
                         %w[F16] => 'city=revenue:0;town=revenue:0,loc:5;upgrade=cost:50,terrain:swamp;label=V',
                         %w[F14] => 'city=revenue:0;border=edge:2,type:impassable',
                         %w[D8] => 'city=revenue:0;border=edge:3,type:impassable',
                         %w[G13] => 'city=revenue:0;border=edge:3,type:impassable;label=Y',
                         %w[C7] => 'city=revenue:0;border=edge:1,type:impassable;border=edge:2,type:impassable;border=edge:4,type:impassable',
                         %w[E11] => 'city=revenue:0;border=edge:3,type:impassable;border=edge:5,type:impassable;label=Y',
                       },
                       yellow: {
                         # passes
                         %w[C15 K7 M11 N12] => 'pass=revenue:0;upgrade=cost:100',
                         %w[O3] => o3,
                         %w[D14] => 'pass=revenue:0;border=edge:1,type:impassable;upgrade=cost:100',
                         %w[L6 M5] => 'pass=revenue:0;border=edge:0,type:impassable;upgrade=cost:100',
                         %w[O11] => 'pass=revenue:0;border=edge:1,type:impassable;upgrade=cost:100',
                         %w[N10] => 'pass=revenue:0;border=edge:1,type:impassable;border=edge:2,type:impassable;upgrade=cost:100',
                         %w[D12] => 'pass=revenue:0;border=edge:0,type:impassable;border=edge:2,type:impassable;border=edge:5,type:impassable;upgrade=cost:100',
                         %w[L8] => 'pass=revenue:0;border=edge:0,type:impassable;border=edge:1,type:impassable;border=edge:5,type:impassable;upgrade=cost:100',
                         %w[M9] => 'pass=revenue:0;border=edge:0,type:impassable;border=edge:1,type:impassable;border=edge:2,type:impassable;border=edge:5,type:impassable;upgrade=cost:100',
                         %w[O13] => 'pass=revenue:0;border=edge:5,type:impassable;upgrade=cost:100',
                         %w[P14] => 'pass=revenue:0;border=edge:2,type:impassable;border=edge:3,type:impassable;upgrade=cost:100',
                         %w[Q15] => 'pass=revenue:0;upgrade=cost:100',
                         # cities
                         %w[F8] => 'city=revenue:60;path=a:_0,b:3,terminal:1;path=a:_0,b:4,terminal:1;label=M',
                         %w[H4] => 'city=revenue:40,loc:1;city=revenue:40,loc:3.5;path=a:_0,b:1;path=a:_0,b:5;path=a:_1,b:4;label=T',
                         %w[M3] => cuneo,
                         %w[M7] => 'city=revenue:0;border=edge:4,type:impassable;upgrade=cost:50,terrain:mountain;label=G',
                       },
                       green: {
                         %w[A5] => 'pass=revenue:0,size:2;upgrade=cost:200',
                         %w[G1] => 'pass=revenue:0,size:2;border=edge:5,type:impassable;upgrade=cost:200',
                       },
                       gray: {
                         %w[A11] => 'town=revenue:20;town=revenue:10;path=a:_0,b:1;path=a:_1,b:0',
                         %w[D10] => 'path=a:0,b:1;path=a:1,b:4;path=a:4,b:5;border=edge:2,type:impassable;border=edge:3,type:impassable',
                         %w[E3] => 'town=revenue:10;path=a:_0,b:4;border=edge:0,type:impassable;border=edge:5,type:impassable',
                       },
                       red: {
                         %w[a4] => 'offboard=revenue:white_0|gray_90|black_150;path=a:_0,b:5',
                         %w[A7] => 'offboard=revenue:white_20|gray_30|black_150;path=a:_0,b:0',
                         %w[C13] => 'offboard=revenue:white_20|gray_70|black_140,groups:Trento;path=a:_0,b:0;path=a:_0,b:1;path=a:_0,b:5',
                         %w[B14] => 'offboard=revenue:white_20|gray_70|black_140,groups:Trento,hide:1;path=a:_0,b:5',
                         %w[E1] => 'offboard=revenue:white_0|gray_140|black_200;path=a:_0,b:0',
                         %w[E17] => 'offboard=revenue:white_50|gray_80|black_120,groups:East;path=a:_0,b:1;path=a:_0,b:2',
                         %w[C17] => 'offboard=revenue:white_50|gray_80|black_120,groups:East,hide:1;path=a:_0,b:1',
                         %w[O17] => 'offboard=revenue:white_10|gray_70|black_150;path=a:_0,b:1;path=a:_0,b:2',
                         %w[P4] => 'offboard=revenue:white_60|gray_100|black_150,groups:Marseille',
                         %w[Q3 Q5] => 'offboard=revenue:white_60|gray_100|black_150,groups:Marseille,hide:1;path=a:_0,b:3',
                         %w[P12] => 'offboard=revenue:white_50|gray_100|black_250,groups:Roma;path=a:_0,b:2;path=a:_0,b:3;path=a:_0,b:4',
                         %w[Q11] => 'offboard=revenue:white_50|gray_100|black_250,groups:Roma,hide:1;path=a:_0,b:2;path=a:_0,b:3',
                         %w[Q13 R14] => 'offboard=revenue:white_50|gray_100|black_250,groups:Roma,hide:1;path=a:_0,b:3;path=a:_0,b:4',
                       },
                       blue: {
                         %w[G17] => 'town=revenue:40,route:never,loc:2;path=a:_0,b:2;icon=image:port',
                         %w[M17] => 'town=revenue:20,route:never,loc:2;path=a:_0,b:2;icon=image:port',
                         %w[O7] => 'town=revenue:70,route:never,loc:3;path=a:_0,b:3;icon=image:port',
                         %w[P6] => 'town=revenue:10,route:never,loc:3;path=a:_0,b:3;icon=image:port',
                         %w[Q9] => 'town=revenue:10,route:never,loc:4;path=a:_0,b:4;icon=image:port',
                       },
                     }
                   end

          # move Cuneo from yellow to white for version 1
          if version == 1
            ghexes[:yellow].delete(['M3'])
            ghexes[:white][['M3']] = cuneo
          end

          ghexes
        end
        # rubocop:enable Layout/LineLength

        # just need the hex for one side - code will add the other
        def regions_by_phase
          if lite?
            {
              2 => {
                'C7' => [0, 5],
                'E7' => [1, 2],
                'G7' => [1, 2],
                'I7' => [0, 1, 2],
                'J8' => [0, 1, 5],
                'K9' => [1, 2],
                'I9' => [1, 2, 3, 4],
                'J10' => [3, 4],
                'I11' => [0],
                'J12' => [2, 3],
                'I13' => [2, 3, 4],
                'J14' => [3, 4],
                'K15' => [3],
                'J16' => [2, 3],
                'P10' => [3],
                'O15' => [2, 3, 4],
                'O13' => [2, 3, 4],
                'P16' => [3],
              },
              4 => {
                'C7' => [0, 5],
                'F12' => [1],
                'H12' => [0, 1, 2],
                'I13' => [2, 3, 4],
                'J14' => [3, 4],
                'K15' => [3],
                'J16' => [2, 3],
              },
              5 => {
                'C7' => [0, 5],
              },
            }
          else
            {
              2 => {
                'C7' => [0, 5],
                'E7' => [1, 2],
                'G7' => [1, 2],
                'I7' => [0, 1, 2],
                'J8' => [0, 1, 5],
                'K9' => [1, 2],
                'I9' => [1, 2, 3, 4],
                'J10' => [3, 4],
                'I11' => [0],
                'J12' => [2, 3],
                'I13' => [2, 3, 4],
                'J14' => [3, 4],
                'K15' => [3],
                'J16' => [2, 3],
                'P10' => [3, 5],
                'P12' => [2, 3],
                'O13' => [2, 3, 4],
                'O15' => [2, 3, 4],
                'P16' => [3],
              },
              4 => {
                'C7' => [0, 5],
                'F12' => [1],
                'H12' => [0, 1, 2],
                'I13' => [2, 3, 4],
                'J14' => [3, 4],
                'K15' => [3],
                'J16' => [2, 3],
              },
              5 => {
                'C7' => [0, 5],
              },
            }
          end
        end

        ZONES = [
          %w[H4 J6 M3 M7],               # 0 PIEDMONT
          %w[R14 P12 Q11 S11],           # 1 TUSCANY
          %w[K11 L12 K13 L14 K15],       # 2 CONSERVATIVE_ZONE
          %w[C7 D8 E7 F8 E9 H8 H10 E11], # 3 LOMBARDIA
          %w[H12 G13 F14 G15 F16 D16],   # 4 VENETO
        ].freeze

        MAJOR_CITIES = %w[L14 R14 M7 F8 H4 F16].freeze
        HISTORICAL_CITIES = %w[F8 F16 H4 J6 M3 R14 P12 Q11].freeze
        VENETO = %w[H12 G13 F14 G15 F16 D16 D14 C15].freeze
        TUSCAN_TOKEN_HEXES = %w[Q11 R14].freeze
        LUGANO = 'C7'
        FIRENZE = 'R14'
        MILANO = 'F8'

        AXES = { x: :number, y: :letter }.freeze
      end
    end
  end
end
