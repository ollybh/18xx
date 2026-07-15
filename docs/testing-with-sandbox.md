# Testing with `Game::Sandbox`

The `Game::Sandbox` module provides a minimal 18xx game that can be instantiated
directly in RSpec without needing any fixtures, saved games, or database. It is
designed for unit testing engine components — including but not limited to
`Engine::RouteGraph::Graph` — by letting you set up game state programmatically.

---

## Sandbox Reference

This section covers everything you need to use the sandbox itself: its default
game state, how to customise it, how to place tiles and tokens, and how to work
with hex geometry.


### Game Overview

#### Map

The default map is a small `:flat` grid (no pointy-top hexes). The hex
coordinates are single-letter/digit pairs (`A1`, `A3`, …, `H10`). Initial white
hexes have no tracks or cities built yet.

Some hexes start with cities or towns:

| Hex         | Features            |
|-------------|---------------------|
| A1 A5 C1 C5 | 1 city              |
| G3          | 1 city (Y label)    |
| E7          | 2 cities (OO label) |
| B8 F8 G5    | 1 town              |
| E3          | 2 towns             |

All other hexes start as blank white.

No hexes have any track paths.


#### Tiles

All yellow, green, brown, and gray tiles from `Config::Tile` are available as
`unlimited` (the game creates fresh copies on demand). However, due to how
`init_tiles` works, **only one copy of each tile type exists initially**. If you
need the same tile type in two different hexes you will need to specify a
custom `tiles` argument to the constructor.

Use `game.tile_by_id("#{name}-#{index}")` to retrieve a tile, for example:

```ruby
tile5 = game.tile_by_id('5-0')  # tile name "5", copy 0
tile9 = game.tile_by_id('9-0')  # tile name "9", copy 0
```

When supplying custom tiles via the `tiles:` keyword argument (see
[Customising the Game](#customising-the-game)), you can specify an explicit count
(`'5' => 3` for three copies of tile `'5'`) so that multiple copies of the
tiles are available.


#### Corporations

Three corporations exist, each with 10 tokens, 100% float, and 1 IPO share:

| ID  | Name  |
|-----|-------|
| `α` | Alpha |
| `β` | Bravo |
| `γ` | Gamma |

---

### Customising the Game

The `hexes:` and `tiles:` keyword arguments to `Sandbox::Game.new` let you
replace the default `HEXES` and `TILES` constants with your own data.  This is
useful when you need a minimal map (faster setup) or hexes/tiles that don't
exist in the defaults.

See the YARD documentation on `Game::Sandbox::Game#initialize` for the
accepted value formats.  The examples below show the main usage patterns.

#### Examples

**Custom hexes only** — the default tile pool is still available:

```ruby
TINY_HEXES = {
  white: {
    %w[A1 A3] => '',
    %w[B2] => 'city=revenue:0;',
  },
}.freeze

game = Sandbox::Game.new(%w[Alice Bob], hexes: TINY_HEXES)
game.hex_by_id('B2')        # exists
game.hex_by_id('E7')        # nil (not in the custom set)
game.tile_by_id('5-0')      # still works — default tiles are loaded
```

**Custom tiles only** — the default map is still available:

```ruby
# Integer count: three copies of tile '5', two copies of tile '9'.
# Tile names must be known to Tile.for (i.e. defined in Config::Tile).
CUSTOM_TILES = {
  '5' => 3,
  '9' => 2,
}.freeze

game = Sandbox::Game.new(%w[Alice Bob], tiles: CUSTOM_TILES)
game.tile_by_id('5-0')       # exists
game.tile_by_id('5-1')       # exists (second copy)
game.tile_by_id('5-2')       # exists (third copy)
game.tile_by_id('5-3')       # nil (index out of range)
game.tile_by_id('9-0')       # exists
game.tile_by_id('6-0')       # nil (not in the custom set)
game.hex_by_id('A1')         # still works — default hexes are loaded
```

**Both customised:**

```ruby
CUSTOM_HEXES = {
  white: {
    %w[C3 C5] => '',
    %w[D4] => 'city=revenue:0;',
  },
}.freeze

# Tile 'Z' defined via code hash (novel name not in Config::Tile).
# Two copies are created so both C3 and C5 can receive one.
CUSTOM_TILES = {
  'Z' => { 'count' => 2, 'color' => 'yellow',
           'code' => 'path=a:0,b:3' },
}.freeze

game = Sandbox::Game.new(%w[Alice], hexes: CUSTOM_HEXES, tiles: CUSTOM_TILES)
game.hex_by_id('C3')          # exists
game.hex_by_id('A1')          # nil
game.tile_by_id('Z-0')        # exists
game.tile_by_id('Z-1')        # exists (second copy)
game.tile_by_id('5-0')        # nil

# Lay the two copies of tile 'Z' on both custom hexes:
h1 = game.hex_by_id('C3')
h2 = game.hex_by_id('C5')
t1 = game.tile_by_id('Z-0')
t2 = game.tile_by_id('Z-1')
t1.rotate!(0)
t2.rotate!(0)
h1.lay(t1)
h2.lay(t2)
```

#### Notes

- Passing `hexes: {}` (empty hash) produces a game with **no hexes** at all.
  This can be useful if you only need the game's tile pool or corporation
  registry for other kinds of tests.
- Passing `tiles: {}` produces a game with **no tiles** in the pool — you
  will not be able to call `game.tile_by_id` successfully.  Hexes on the map
  still have their preprinted tiles.

---

### Core Pattern: Laying Tiles Directly

The quickest way to set up the map is to call `Hex#lay(tile)` directly,
**bypassing the game round system entirely**.

```ruby
def hex(id)
  game.hex_by_id(id)
end

def tile(name, index = 0)
  game.tile_by_id("#{name}-#{index}")
end

def lay_tile(hex_id, tile_name, rotation = 0)
  h = hex(hex_id)
  t = tile(tile_name)
  t.rotate!(rotation)
  h.lay(t)
end
```

---

### Hex Geometry (Flat Layout)

For a `:flat` layout, edges are numbered clockwise starting from the south side:

| Edge | Direction |
|------|-----------|
| 0    | South (↓) |
| 1    | South-west |
| 2    | North-west |
| 3    | North (↑) |
| 4    | North-east |
| 5    | South-east |

Two adjacent hexes always have opposite edge numbers: A1's edge 0 (south) connects to
A3's edge 3 (north).

#### Finding neighbours

```ruby
hex('A1').neighbors
# => {0 => #<Hex A3>,       5 => #<Hex B2>}
#     (south)                   (south-east)
```

#### Tile rotation

When you retrieve a tile from the pool its rotation is 0.  Call
`tile.rotate!(n)` to rotate by `n` positions **before** laying it:

```ruby
tile5.rotate!(3)  # shift all exits by +3 mod 6
```

---

### Placing Tokens

Tokens can be placed directly on city nodes (bypassing the round system):

```ruby
alpha = game.corporations.find { |c| c.id == 'α' }
city  = hex('A1').tile.cities.first
city.place_token(alpha, alpha.tokens.first, free: true)
```

---

### Common Tile Reference

Below are tiles useful for building test configurations.  Exits refer to the
edge numbers at rotation 0.

#### Yellow tiles (plain track)

| Tile | Description        | Exits   | Notes                   |
|------|--------------------|---------|-------------------------|
| `7`  | Tight curve        | `[0,1]` | South to south-west     |
| `8`  | Gentle curve       | `[0,2]` | South to north-west     |
| `9`  | Straight           | `[0,3]` | South to north          |

Edges `[0,3]` and `[0,2]` are different:
- `[0,3]`: goes from south to north (through the centre) — a straight line.
- `[0,2]`: goes from south to north-west — a curve.

#### Yellow tiles (with cities/towns)

| Tile  | Description        | Exits / Nodes        | Notes                                      |
|-------|--------------------|----------------------|--------------------------------------------|
| `3`   | Town               | `a:0,b:_0; a:_0,b:1` | Town on tight curve (south to south-west)  |
| `4`   | Town               | `a:0,b:_0; a:_0,b:3` | Town on straight (south to north)          |
| `58`  | Town               | `a:0,b:_0; a:_0,b:2` | Town on gentle curve (south to north-west) |
| `5`   | City (edges 0, 1)  | `a:0,b:_0; a:1,b:_0` | Single city, south and south-west          |
| `6`   | City (edges 0, 2)  | `a:0,b:_0; a:2,b:_0` | Single city, south and north-west          |
| `57`  | City (edges 0, 3)  | `a:0,b:_0; a:_0,b:3` | Single city, south and north               |
| `115` | City (edge 0)      | `a:0,b:_0;`          | 'Lollipop' city, south only                |

For green/brown/gray tiles, look at `Config::Tile::GREEN`, etc. in
`lib/engine/config/tile.rb`.

---

### Using Through the Round System (Alternative)

If you want to test the full game pipeline (including round transitions, action
validation, and the graph), you can process actions through the rounds.

If you still need to use the round system, the sequence is:

```ruby
# 1. Par a corporation
player = game.players.first
alpha  = game.corporations.find { |c| c.id == 'α' }
price  = game.stock_market.par_prices.first
game.process_action(Action::Par.new(player, corporation: alpha, share_price: price))

# 2. Pass through the rest of the stock round
3.times { game.process_action(Action::Pass.new(game.current_entity)) }

# 3. Place the home token
a1_city = hex('A1').tile.cities.first
game.process_action(Action::PlaceToken.new(alpha, city: a1_city))

# 4. Lay track (only works if the hex has a tile with paths to the edge,
#    because the old graph checks reachability)
tile9 = game.tile_by_id('9-0')
game.process_action(Action::LayTile.new(alpha, tile: tile9, hex: hex('A3'), rotation: 0))
```

---

## Testing the RouteGraph

This section covers using the sandbox specifically to test
`Engine::RouteGraph::Graph`.

### Quick Start

```ruby
require 'spec_helper'

module Engine
  module RouteGraph
    describe Graph do
      let(:players) { %w[Alice Bob Charlie] }
      let(:game)    { Game::Sandbox::Game.new(players) }

      subject(:graph) { game.route_graph }

      # ... tests ...
    end
  end
end
```

### RouteGraph Concepts

#### Vertices

Three vertex types, all found in `lib/engine/route_graph/vertex.rb`:

| Class           | Represents                              | Mergeable? |
|-----------------|-----------------------------------------|------------|
| `NodeVertex`    | City, town or halt                      | No         |
| `HexEdgeVertex` | Point where track meets a hex edge      | Yes (when two paths meet at the same hex edge with matching gauge) |
| `JunctionVertex`| Lawson-style track junction             | Yes        |

#### Edges

An `Edge` connects two vertices and carries one or more `Path` objects (from
the tile system). After `join_edges!`, a single edge can span multiple tiles.

#### GraphWalker

Created via `graph.walker(entity)`:
- Starts from all tokens the entity has placed
- Performs DFS through the graph
- Returns connected nodes/cities via `connected_nodes`

After placing a token:

```ruby
walker = graph.walker(alpha)
walker.walk
puts walker.connected_nodes.map(&:id)  # e.g. ["5-0-0", "6-0-0"]
```

Tokens are **not** needed for the route graph to be built; the graph is
computed from all track on the map regardless of tokens. The walker just uses
tokens as starting points.

---

### Example: Two Cities Connected Through Track

```
A1: tile 5 (yellow city, edges 0 & 1)  rot 0 → edges 0, 1
A3: tile 9 (straight track, edges 0 & 3) rot 0 → edges 0, 3

Connection: A1(e0/south) ↔ A3(e3/north) ↔ A3(e0/south)—(dead end at A5's edge)
```

```ruby
before :each do
  lay_tile('A1', '5', 0)   # city
  lay_tile('A3', '9', 0)   # straight north-south track
end

it 'has the right number of edges' do
  expect(graph.edges.size).to eq(2)
end
```

#### Two cities linked through a third hex

```
A1: tile 5  rot 0 → edges 0, 1   (city, south & south-west)
A3: tile 9  rot 0 → edges 0, 3   (straight north-south track)
A5: tile 6  rot 3 → edges 3, 5   (city, north & south-east)

Connection: A1(e0/south) ↔ A3(e3/north) ↔ A3(e0/south) ↔ A5(e3/north)
```

After `join_edges!` the intermediate hex-edge vertices are merged, producing a
direct edge between the two city nodes:

```ruby
it 'produces a single merged edge connecting both cities' do
  city_edge = graph.edges.find do |e|
    e.left.is_a?(NodeVertex) && e.right.is_a?(NodeVertex)
  end
  expect(city_edge).not_to be_nil
  expect(city_edge.paths.size).to eq(3)  # A1 path + A3 path + A5 path
end
```

---

### Reference: Full Example Test File

See `spec/lib/engine/route_graph/graph_spec.rb` for a complete set of example
tests covering:
- Single city tile
- Two cities connected by track (merged edge)
- Token placement and GraphWalker
- Branching track (dead-end hex edge)
- Town tiles
- `to_d3` output format
- Corporation with no token (empty walk)

### RouteGraph Notes

**`join_edges!`** runs automatically when the graph is
constructed. Intermediate hex-edge vertices with exactly two edges of the
same gauge are removed and their edges merged.

---

## Writing Robust Tests

1. **Prefer direct tile laying** (`Hex#lay`) over the round system. It is
   faster, more predictable, and avoids the graph's reliance on corporation
   coordinates.

2. **Use custom hexes and tiles** in your tests rather than relying on the
   sandbox's defaults. This protects your tests from future changes to
   `Game::Sandbox::HEXES` and `Game::Sandbox::TILES`, and keeps test
   setup minimal and self-documenting.

3. **Use different tile names** when you need multiple hexes with cities
   (e.g. tile `'5'` on A1 and tile `'6'` on A5). There is only one copy of
   each tile name initially, unless you specify a custom count.

4. **Check the hex neighbour map** before designing tracks. Run this snippet
   to see what connects to what:

   ```ruby
   game.hexes.each do |h|
     puts "#{h.coordinates}: #{h.neighbors.sort.map { |k,v| [k, v.coordinates] }}"
   end
   ```
