---
name: testing-route-graph
description: >-
  Write and debug unit tests for Engine::RouteGraph::Graph using Game::Sandbox.
  Covers setup, tile laying, token placement, hex geometry, and the GraphWalker.
  Load when working on graph_spec.rb or related route graph tests.
---

# Testing the RouteGraph with `Game::Sandbox`

Full reference: `docs/testing-with-sandbox.md` (the **Testing the RouteGraph** section).

## Quick Start

```ruby
require 'spec_helper'

module Engine
  module RouteGraph
    describe Graph do
      # Custom hexes: only include hexes the tests need.
      # Neighbors are computed automatically by connect_hexes.
      TEST_HEXES = {
        white: {
          %w[A1 A3 A5 B2 B6] => '',
        },
      }.freeze

      # Provide explicit counts so tile name reuse is not required.
      TEST_TILES = {
        '5' => 2,
        '9' => 2,
        '6' => 1,
        '8' => 3,
        '3' => 1,
      }.freeze

      let(:players) { %w[Alice Bob Charlie] }
      let(:game) { Game::Sandbox::Game.new(players, hexes: TEST_HEXES, tiles: TEST_TILES) }
      subject(:graph) { game.route_graph }
    end
  end
end
```

## Tile Helpers

```ruby
def hex(id)
  game.hex_by_id(id)
end

def tile(name, index = 0)
  game.tile_by_id("#{name}-#{index}")
end

def lay_tile(hex_id, tile_name, rotation = 0, index = 0)
  h = hex(hex_id)
  t = tile(tile_name, index)
  t.rotate!(rotation)
  h.lay(t)
end
```

## Hex Geometry (`:flat` layout)

| Edge | Direction |
|------|-----------|
| 0    | South (↓) |
| 1    | South-west |
| 2    | North-west |
| 3    | North (↑) |
| 4    | North-east |
| 5    | South-east |

Neighbours have opposite edges: A1's edge 0 (south) ↔ A3's edge 3 (north).

## Common Tiles

Straight track: tile `'9'` (exits 0→3, south–north).
Curve: tile `'8'` (exits 0→2, south–north-west), tile `'7'` (exits 0→1, south–south-west).
City (two exits): tile `'5'` (edges 0,1), tile `'6'` (edges 0,2).
City (one exit): tile `'57'` (edges 0,3, south–north).
Town: tile `'4'` (edges 0,3), tile `'3'` (edges 0,1), tile `'58'` (edges 0,2).

## Token Placement

```ruby
corp = game.corporations.find { |c| c.id == 'α' }
city = hex('A1').tile.cities.first
city.place_token(corp, corp.tokens.first, free: true)
```

## GraphWalker

```ruby
walker = graph.walker(corp)
walker.walk
walker.connected_nodes  # => set of NodeVertex IDs
```

## Custom Tiles

Tiles not in the standard config can be added to the tile pool via the `tiles:` hash using a full definition:

```ruby
tiles = {
  # standard tile, 1 copy
  '5' => 1,
  # custom: 2 parallel tracks
  'ML_STRAIGHT' => {
    'count' => 2,
    'color' => 'yellow',
    'code' => 'path=a:0,b:3,lanes:2',
  },
  # city + 2 lanes
  'ML_CITY' => {
    'count' => 1,
    'color' => 'yellow',
    'code' => 'city=revenue:0;path=a:0,b:_0,lanes:2',
  },
}
Game::Sandbox::Game.new(players, hexes: hexes, tiles: tiles)
```

`init_tile` calls `Tile.from_code(name, color, code, index: i, ...)` for each copy, so a count of 2 produces `"ML_STRAIGHT-0"` and `"ML_STRAIGHT-1"`. Use the `index` parameter of `lay_tile` / `tile` to access specific copies:

```ruby
lay_tile('A2', 'ML_STRAIGHT', 0, 0)  # copy 0
lay_tile('A4', 'ML_STRAIGHT', 0, 1)  # copy 1
```

Standard tiles in the same hex set still work via their name:

```ruby
tiles = {
  '9' => 1,
  'ML_STRAIGHT' => { 'count' => 1, 'color' => 'yellow', 'code' => 'path=a:0,b:3,lanes:2' },
}
# then:
lay_tile('A2', '9', 0)            # standard tile 9
lay_tile('A4', 'ML_STRAIGHT', 0, 0)  # custom
```

## Running Graph Tests

All graph-related specs (graph construction, walker, edge, hex exit) use the `:graph` metadata
tag so they can be run in isolation:

```bash
# Run only graph/walker tests through docker
docker compose exec rack rspec spec --tag graph

# Run all specs
bundle exec rspec
```

Add `:graph` to every `describe` block (or individual example) that exercises graph code so the
filter stays reliable.

## Key Reminders

- Use `Hex#lay` directly, bypass the round system.
- Provide custom `hexes:` and/or `tiles:` to `Sandbox::Game.new` to protect tests from future changes to sandbox defaults.
- `join_edges!` runs automatically on graph construction.
- See `docs/testing-with-sandbox.md` for customisation examples and full reference.

## Implementation Details

### How hex neighbours are set up

`Game::Base#connect_hexes` (called during `initialize`) builds a `{ [x, y] => hex }` lookup from `@hexes`, then iterates each hex's `DIRECTIONS[layout]` (the delta-map in `lib/engine/hex.rb`) to populate `all_neighbors` and `neighbors`.

**Only hexes that exist in the custom hex set are linked.** If a neighbour is missing, `all_neighbors[edge]` stays nil. This affects `HexEdgeCrossing` IDs — a crossing with only one side produces a bare ID like `A1_0_0` instead of the two-sided `A1_0_0|A3_3_0`. Always include every hex that appears in expected vertex IDs.

### Vertex ID conventions

| Vertex type | ID format | Example |
|---|---|---|
| `NodeVertex` | `node.id` (the part's ID) | `5-0-0` (tile "5", copy 0, city index 0) |
| `HexEdgeVertex` | `crossing.id` = `hex_edge_lane` joined by `\|` | `A1_0_0|A3_3_0` |

`HexEdgeCrossing` uses `all_neighbors` (not `neighbors`) to find the opposite hex, so crossings exist even when borders make a hex impassable.

### Lanes and multi-lane tiles

The `lanes:` parameter on a path creates multiple parallel path instances with mirrored lane indices:

```ruby
# Config string:  'path=a:0,b:3,lanes:2'
# Creates 2 paths:
#   Path 0: lanes [[2,0],[2,1]]  → a_lane [2,0], b_lane [2,1]
#   Path 1: lanes [[2,1],[2,0]]  → a_lane [2,1], b_lane [2,0]
```

Each lane spec `[lanes, index]` produces an offset: `lanes - 1 - (index * 2)`:

| Spec   | lanes | index | offset |
|--------|-------|-------|--------|
| [1, 0] | 1     | 0     | 0      |
| [2, 0] | 2     | 0     | +1     |
| [2, 1] | 2     | 1     | −1     |
| [3, 0] | 3     | 0     | +2     |
| [3, 1] | 3     | 1     | 0      |
| [3, 2] | 3     | 2     | −2     |

At a hex border, `HexExit#connects_to?` requires opposite lane offsets (one +N, the other −N). This happens automatically for edge-to-edge paths because `make_lanes` mirrors the lane indices (`b_lanes = [lanes, lanes - index - 1]`). For edge-to-city or edge-to-town paths, `b_lanes = a_lanes` (no mirror), so both sides get the same offset and won't connect across the border unless both offsets are 0 (single lane).

### Tile code → paths

Tile config strings use the format `'path=a:N,b:M'` to connect tile edges N and M. At rotation 0 these map directly to hex edges. `rotate!(n)` shifts by `+n mod 6`.

Key tiles for tests:
- `'7'` = `path=a:0,b:1` → edges 0→1 (south→south-west)
- `'8'` = `path=a:0,b:2` → edges 0→2 (south→north-west)
- `'9'` = `path=a:0,b:3` → edges 0→3 (south→north, straight)
- `'5'` = `city=revenue:20;path=a:0,b:_0;path=a:1,b:_0` → city at edges 0,1
- `'6'` = `city=revenue:20;path=a:0,b:_0;path=a:2,b:_0` → city at edges 0,2

### Sandbox tile pool

Despite the `'unlimited'` constant in `Game::Sandbox::Game::TILES`, `init_tiles` creates **only one copy** of each tile. Custom tile configs with integer counts (`'5' => 3`) create exactly that many copies, accessible as `tile('5', 0)`, `tile('5', 1)`, etc.

### Hex neighbour reference (for the custom hexes above)

| Hex | Neighbours |
|-----|------------|
| A1 | edge 0 (south) → A3, edge 5 (south-east) → B2 |
| A3 | edge 3 (north) → A1, edge 0 (south) → A5 |
| A5 | edge 3 (north) → A3, edge 5 (south-east) → B6 |
| B2 | edge 2 (north-west) → A1 |
| B6 | edge 2 (north-west) → A5 |

### Sandbox default hexes

The sandbox default `HEXES` includes preprinted cities on A1, A5, C1, C5 (single cities), E7 (OO, two cities), and G3 (Y, one city). It has towns on B8, F8, G5 (single towns), and E3 (two cities) When using custom hexes you must add cities and towns explicitly if needed, or use blank `''` tiles.
