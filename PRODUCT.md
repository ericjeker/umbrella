# Umbrella — Product

A 2D, top-down space fleet game in the spirit of Starsector's world and
EVE Online's command model: you don't fly the ships directly — you select
them and give orders (move here, attack that, orbit this), then watch the
simulation execute.

## Why this scope

A good fit for learning Zig because it exercises every system worth
learning (entities, orders, spatial math, rendering, simple AI, fixed
timestep) without the bottomless complexity of a real-time action game.
The "orders" loop is fun and teaches state machines and architecture
without needing animation, physics, or asset pipelines.

## Core design

- **2D, top-down.** Ships are simple shapes (triangles for starters),
  drawn with SDL3 primitive rendering (`SDL_RenderLines`,
  `SDL_RenderFillRect`). No sprites yet.
- **Orders, not direct control.** The player selects ships and issues
  orders; the simulation steers and fights. No WASD, no throttle.
- **Orders as a tagged union** (the central Zig architectural choice):

  ```zig
  const Order = union(enum) {
      move_to: MoveTo,    // { target: Vec2 }
      attack: Attack,     // { target_id: u32 }
      orbit: Orbit,       // { target_id: u32, radius: f32 }
      stop,

      fn execute(self: Order, ship: *Ship, world: *World, dt: f32) OrderResult {
          return switch (self) {
              .move_to => |o => moveTo(ship, o.target, dt),
              .attack  => |o => attackTarget(ship, world.ship(o.target_id), dt),
              // ...
          };
      }
  };
  ```

  Add a new order variant and the compiler points at every `switch` that
  needs to handle it. This replaces an OO `Order` base class + virtual
  `execute()`, and it's the single best fit for Zig's `union(enum)` in
  this design.

## Milestones

### Milestone 1 — "One ship, one order, one asteroid"

A single ship you can:
1. Select (click on it)
2. Right-click somewhere in space to issue a "move to" order
3. Watch the ship rotate toward the target and thrust toward it, arriving
   and stopping (arrival behavior, not orbit-forever)
4. One asteroid on screen that the ship avoids or collides with

Forces building: selection, orders (the `MoveTo` variant), the orders
queue (even length 1 — the data structure matters more than the length),
steering (rotate-toward + thrust + arrival), and the game loop (update
separated from draw separated from input — the three pillars).

### Milestone 2 — "Two ships and weapons"

Add:
- A second ship, enemy-faction
- An `AttackTarget` order (variant in the union)
- Weapons range, a simple "if target in range, fire" with cooldown
- Health, death

The orders union now has two variants and the `switch` in `update`
starts earning its keep. Adding `AttackTarget` is: define the variant,
handle it in `update`, handle it in the HUD. No refactoring.

### Milestone 3 — "Fleet orders"

Multiple selectable ships, shift-click to queue orders, box-select,
"move fleet here keeping formation." The world/fleet layer becomes real;
the orders queue per ship becomes a `std.ArrayList(Order)` and you
process the head each tick.

**Stop here.** That's a complete game — select ships, give orders,
watch them fight. Everything beyond (economy, map, AI) is scope creep
that's only worth it if milestones 1-3 are actually fun to play.

## Architectural rules

- **One file per concept.** `entities/ship.zig`, `entities/asteroid.zig`,
  `math/vec2.zig`, `screens/manager.zig`, etc. The file is the namespace
  and the encapsulation boundary; `pub` controls what leaks out.
- **Composition, not inheritance.** `World` *has a* `[]Ship`; ships don't
  derive from a `Drawable` base class.
- **Don't build an ECS.** Array-of-structs (`std.ArrayList(Ship)`) is
  fine for ~20 entities. ECS is an optimization for scale we don't have.
- **Fixed timestep for the simulation.** Update the world at a fixed
  rate (e.g. 60 Hz) regardless of render rate; interpolate for drawing.
  Use `SDL_GetTicks()` to accumulate dt and step the sim in fixed
  increments. Avoids ship speed becoming framerate-dependent.
- **SDL3 interop through the shared "sdl" module.** Already wired in
  `build.zig` via `addSdlModule`. Any file at any depth does
  `@import("sdl").sdl` and gets the same SDL types. No per-file
  `@cImport`.
- **Tests next to the code.** `*_test.zig` files, wired into `build.zig`
  with the `addTest` helper. Adding a test file is one line:
  ```zig
  addTest(b, test_step, target, optimize, "src/entities/ship_test.zig");
  ```
  Pure-math modules (e.g. `vec2.zig`) are testable without linking SDL.

## What we are NOT building (yet)

- Physics
- Sprites / asset pipelines
- A GUI framework (keyboard shortcuts + SDL primitives for the HUD)
- Networking
- Save systems
- Economy, star map, fleet AI

Any of these can come later if the core loop is fun. Adding them
speculatively is the scope cliff.

## Next step

Build `Vec2` and its tests first. Every other system — selection,
orders, steering, rendering — depends on 2D vector math, and it's the
cleanest place to practice the struct + tests + math pattern without SDL
in the way. Pure-math file, no `@import("sdl")`, simplest possible test
wiring. From there, Milestone 1 falls into place: ship struct with a
`Vec2` position, a `MoveTo` order, steering toward the target, drawing
as a triangle (the code already exists in `src/entities/triangle.zig`).

## Build / test commands

```bash
zig build                     # build both targets (Linux + Windows .exe)
zig build run                 # build + run the native Linux binary
zig build test                # compile + run unit tests
zig build test --summary all  # same, plus per-test pass/fail counts
```

See [README.md](README.md) for full build/run details and
[AGENTS.md](AGENTS.md) for full project context.
