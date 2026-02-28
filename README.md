# Alembic

A multiplayer 2D RPG game server built with Elixir, designed for Dungeon Masters and Game Masters to create interactive worlds for their players to explore. Inspired by classic top-down RPGs like The Legend of Zelda and Stardew Valley, with tabletop RPG mechanics.

## What is Alembic?

Alembic is a real-time multiplayer game server that brings tabletop RPG campaigns to life in a digital format. Players move through grid-based zones, interact with NPCs, fight mobs, and explore worlds created by GMs. The server handles all game logic, while clients (built with Bevy/Rust) render the world and handle player input.

## Current State (70% Complete)

Alembic has a **working game world** with:

✅ **Grid-based zones** - Players move on x,y coordinates through large continuous zones  
✅ **Multi-campaign support** - Run multiple independent campaigns on one server  
✅ **Dual coordinate system** - Local zone coords + global world coords for seamless transitions  
✅ **Viewport system** - Server sends 20x12 tile viewports to clients  
✅ **Movement validation** - Tile walkability, boundary checking  
✅ **Multi-player** - Multiple players visible in same zone  
✅ **Entity system** - Players, Mobs, NPCs with stats, equipment, attributes  
✅ **Combat system** - Multi-type damage (physical, fire, ice, etc.) with resistances  
✅ **Process architecture** - Fault-tolerant supervised GenServers  
✅ **Serialization** - ClientPayload protocol ready for network transmission  

### What Works Right Now

```elixir
# Start IEx and spawn a test world
iex -S mix
iex> world = Alembic.Fixtures.spawn_test_world()

# Move players around
iex> Alembic.Entity.Player.move("test1", :north)
{:ok, %Position{x: 10, y: 9, ...}}

# Get viewport (what the client would render)
iex> Alembic.World.Zone.get_viewport("test", 10, 9)
%{tiles: [...], entities: [...], center: %{x: 10, y: 9}}

# Spawn multiple players - they see each other
iex> # Player 2 joins and sees Player 1 in their viewport
```

## Architecture Overview

### Core Architecture (85% Complete)

```
Campaign
└── World.Server (coordinates zones, time, weather)
    ├── Zone: Overworld (GenServer - 256x256 grid)
    │   ├── Players (tracked positions)
    │   ├── Mobs (AI, spawns, loot)
    │   └── Tiles (walkability, textures)
    ├── Zone: Dungeon
    └── Room: Tavern (GenServer - 32x32 grid)
        └── Entrances (doors to/from zones)
```

**Process Model:**
- ✅ Each Campaign = 1 World.Server GenServer
- ✅ Each Zone = 1 Zone GenServer (tick loop for mob AI, spawns)
- ✅ Each Room = 1 Room GenServer (loaded on-demand)
- ✅ Each Player = 1 Player GenServer (connection state, inventory)
- ✅ Each Mob = 1 Mob GenServer (AI state machine)
- ✅ All supervised for fault tolerance

### Module Breakdown

#### 🟢 Entity System (90% Complete)

| Module | Status | Notes |
|--------|--------|-------|
| `Entity.Player` | ✅ | GenServer with movement, inventory, equipment |
| `Entity.Mob` | ✅ | Struct ready, GenServer pending |
| `Entity.NPC` | ✅ | Struct ready, GenServer pending |
| `Entity.Position` | ✅ | Dual coords (zone + world), facing direction |
| `Entity.Stats` | ✅ | HP, MP, attack, defense, resistances |
| `Entity.Attributes` | ✅ | Str, dex, con, int, wis, cha |
| `Entity.Equipment` | ✅ | 13 slots, dual wielding |
| `Entity.Combatant` | ✅ | Protocol for multi-type damage |
| `Entity.DamageComponent` | ✅ | Multi-damage (e.g., fire sword = physical + fire) |
| `Entity.SpriteConfig` | ✅ | Animation state, facing, frame |
| `Entity.Base` | ✅ | Shared GenServer boilerplate via `__using__` |

**Missing:**
- [ ] Mob AI state machine implementation
- [ ] NPC dialogue trees
- [ ] Status effects (buffs/debuffs)

#### 🟢 World System (80% Complete)

| Module | Status | Notes |
|--------|--------|-------|
| `World.Zone` | ✅ | GenServer with viewport, tick loop |
| `World.Room` | ✅ | GenServer with multiple entrances |
| `World.Tile` | ✅ | Texture, walkability, type, elevation |
| `World.Server` | ✅ | Campaign coordinator, zone loading |
| `World.Base` | ✅ | Shared GenServer logic for Zone/Room |
| `World.ChunkManager` | ⚠️ | Planned - viewport delta streaming |

**Missing:**
- [ ] Zone/Room loading from files (JSON/YAML)
- [ ] Procedural generation
- [ ] Tile metadata (doors, levers, chests)
- [ ] Zone transitions (seamless zone borders)

#### 🟢 Campaign System (90% Complete)

| Module | Status | Notes |
|--------|--------|-------|
| `Campaign.CampaignManager` | ✅ | Start/stop campaigns, list running |
| `Campaign.CampaignRegistry` | ✅ | Track running campaigns |

**Missing:**
- [ ] Campaign file format definition
- [ ] Campaign loader (from disk/database)
- [ ] Campaign metadata (name, description, GM)

#### 🟢 Registry System (100% Complete) ✅

| Registry | Status |
|----------|--------|
| `Registry.Base` | ✅ |
| `Registry.PlayerRegistry` | ✅ |
| `Registry.MobRegistry` | ✅ |
| `Registry.NPCRegistry` | ✅ |
| `Registry.ZoneRegistry` | ✅ |
| `Registry.RoomRegistry` | ✅ |
| `Registry.CampaignRegistry` | ✅ |

#### 🟢 Supervisor System (100% Complete) ✅

| Supervisor | Status |
|------------|--------|
| `Supervisors.PlayerSupervisor` | ✅ |
| `Supervisors.MobSupervisor` | ✅ |
| `Supervisors.NPCSupervisor` | ✅ |
| `Supervisors.ZoneSupervisor` | ✅ |
| `Supervisors.RoomSupervisor` | ✅ |
| `Supervisors.CampaignSupervisor` | ✅ |

#### 🟡 Game Systems (60% Complete)

| Module | Status | Notes |
|--------|--------|-------|
| `Game.Combat` | ⚠️ | Damage calculation stub |
| `Game.Movement` | ✅ | Position updates, validation |
| `Game.Commands` | ⚠️ | Planned - text command parser |

**Missing:**
- [ ] Combat resolution (attack rolls, crits, dodges)
- [ ] Mob AI behaviors (wander, patrol, aggro, flee)
- [ ] Quest system
- [ ] Dialogue system
- [ ] Crafting system

#### 🟡 Network Layer (0% Complete)

| Module | Status | Notes |
|--------|--------|-------|
| `Network.Endpoint` | ❌ | Phoenix endpoint |
| `Network.PlayerChannel` | ❌ | WebSocket per player |
| `Network.Message` | ❌ | Message format definitions |
| `Serialization.ClientPayload` | ✅ | Protocol ready! |

**Missing:**
- [ ] Phoenix Channels setup
- [ ] Message handlers (move, attack, interact)
- [ ] Broadcast system (player movement to nearby players)
- [ ] Authentication/authorization

## Running the Server

### Prerequisites

- Elixir 1.18+ and Erlang/OTP 27+
- Mix build tool

### Quick Start

```bash
# Install dependencies
mix deps.get

# Start interactive shell
iex -S mix

# Spawn a test world
iex> world = Alembic.Fixtures.spawn_test_world()

# Move a player
iex> Alembic.Entity.Player.move(world.player_id, :north)
{:ok, %Position{x: 10, y: 9, ...}}

# Get viewport (what client sees)
iex> Alembic.World.Zone.get_viewport(world.zone_id, 10, 9)
%{tiles: [...240 tiles...], entities: [%{type: :player, id: "test1", ...}]}

# Spawn another player
iex> position2 = %Alembic.Entity.Position{zone_id: "test", x: 12, y: 10, world_x: 12, world_y: 10, facing: :west}
iex> Alembic.Supervisors.PlayerSupervisor.start_player("test2", name: "Bob", position: position2)
iex> Alembic.World.Zone.player_enter("test", "test2", 12, 10)

# Now viewport shows BOTH players
iex> Alembic.World.Zone.get_viewport("test", 10, 10)
%{entities: [%{id: "test1", ...}, %{id: "test2", ...}]}
```

### Module Organization

```
lib/alembic/
├── campaign/
│   ├── campaign_manager.ex      # API for starting/stopping campaigns
│   └── campaign_registry.ex     # Registry (uses Base)
├── entity/
│   ├── base.ex                  # Shared GenServer logic
│   ├── player.ex                # Player GenServer
│   ├── mob.ex                   # Mob struct (GenServer TODO)
│   ├── npc.ex                   # NPC struct (GenServer TODO)
│   ├── position.ex              # Dual coordinate system
│   ├── stats.ex                 # HP, MP, resistances
│   ├── attributes.ex            # RPG stats
│   ├── equipment.ex             # 13 slots
│   ├── sprite_config.ex         # Animation state
│   ├── combatant.ex             # Protocol for combat
│   └── damage_component.ex      # Multi-type damage
├── registry/
│   ├── base.ex                  # Shared registry logic
│   ├── player_registry.ex
│   ├── mob_registry.ex
│   ├── npc_registry.ex
│   ├── zone_registry.ex
│   ├── room_registry.ex
│   └── campaign_registry.ex
├── supervisors/
│   ├── player_supervisor.ex
│   ├── mob_supervisor.ex
│   ├── npc_supervisor.ex
│   ├── zone_supervisor.ex
│   ├── room_supervisor.ex
│   └── campaign_supervisor.ex
├── world/
│   ├── base.ex                  # Shared Zone/Room logic
│   ├── zone.ex                  # Large zone GenServer
│   ├── room.ex                  # Small room GenServer
│   ├── tile.ex                  # Grid tile struct
│   └── server.ex                # World coordinator
├── game/
│   ├── combat.ex                # Combat resolution
│   ├── movement.ex              # Movement logic
│   └── commands.ex              # Command parser
├── serialization.ex             # ClientPayload protocol
├── fixtures.ex                  # Test data helpers
└── application.ex               # OTP app entry point
```

## Next Steps (Priority Order)

### Phase 1: Playable Demo (1-2 weeks)

**Goal:** Players can connect, walk around, and see each other

1. **World Data Loading** (2-3 days)
   - [ ] Define zone file format (JSON/YAML)
   - [ ] Tile loader (parse texture_id, walkability)
   - [ ] Spawn point configuration
   - [ ] Create 2-3 sample zones (town, forest, dungeon)

2. **Phoenix Channels** (2-3 days)
   - [ ] Add `phoenix` and `phoenix_pubsub` dependencies
   - [ ] Create `Network.Endpoint`
   - [ ] Create `Network.PlayerChannel`
   - [ ] Wire up `move`, `get_viewport`, `interact` handlers
   - [ ] Broadcast player movement to nearby players

3. **Collision Detection** (1 day)
   - [ ] Add varied terrain (grass, water, stone walls)
   - [ ] Test movement validation against non-walkable tiles
   - [ ] Add door tiles (transition points)

4. **Testing & Polish** (2 days)
   - [ ] Integration tests for multi-player scenarios
   - [ ] Performance testing (100+ players in one zone)
   - [ ] Fix viewport edge cases

### Phase 2: Combat & NPCs (2-3 weeks)

5. **Combat System** (1 week)
   - [ ] Implement `Game.Combat.resolve_attack/3`
   - [ ] Attack rolls, crits, dodges
   - [ ] Death handling (respawn, loot drops)
   - [ ] Experience & leveling

6. **Mob AI** (1 week)
   - [ ] Promote Mob to GenServer
   - [ ] AI state machine (idle → wander → aggro → combat → dead)
   - [ ] Aggro detection (check player distance each tick)
   - [ ] Pathfinding (A* for mob movement)
   - [ ] Respawn timers

7. **NPCs** (3-4 days)
   - [ ] Promote NPC to GenServer
   - [ ] Dialogue system (tree-based)
   - [ ] Shop system (buy/sell items)
   - [ ] Quest givers

### Phase 3: Client Integration (3-4 weeks)

8. **Bevy Client (Rust)** (2 weeks)
   - [ ] WebSocket connection to Alembic server
   - [ ] Tile rendering (2D grid)
   - [ ] Entity rendering (players, mobs, NPCs)
   - [ ] Sprite animation (walk cycles, idle)
   - [ ] Input handling (WASD movement, mouse clicks)

9. **Asset Pipeline** (1 week)
   - [ ] Texture atlas generation
   - [ ] Sprite sheet loader
   - [ ] Asset uploading (GM custom sprites)

10. **UI & Polish** (1 week)
    - [ ] Chat system
    - [ ] Inventory UI
    - [ ] Character stats panel
    - [ ] Health bars
    - [ ] Minimap

### Phase 4: GM Tools (2-3 weeks)

11. **World Builder** (2 weeks)
    - [ ] Web-based map editor
    - [ ] Drag-and-drop tile placement
    - [ ] NPC/mob spawn point editor
    - [ ] Campaign export/import

12. **GM Master View** (1 week)
    - [ ] God-mode viewport (see all zones)
    - [ ] Spawn mobs/items on-the-fly
    - [ ] Dice rolling interface
    - [ ] Player kick/ban controls

## Roadmap

### ✅ Completed (70%)

- [x] Grid-based zones with tile system
- [x] Dual coordinate system (local + world)
- [x] Viewport rendering (20x12 tiles)
- [x] Multi-player support (players see each other)
- [x] Movement validation (walkability, bounds)
- [x] Entity system (Player, Mob, NPC)
- [x] Stats, attributes, equipment
- [x] Multi-type damage system
- [x] Process architecture (supervised GenServers)
- [x] Registry system (all entities)
- [x] Serialization (ClientPayload protocol)
- [x] Campaign manager (multi-campaign support)
- [x] Test fixtures and helpers

### 🚧 In Progress (15%)

- [ ] World data loading (zone files)
- [ ] Phoenix Channels integration
- [ ] Collision detection with varied terrain

### 📋 Planned (15%)

**Networking**
- [ ] WebSocket server (Phoenix Channels)
- [ ] Authentication/authorization
- [ ] Session management
- [ ] Broadcast system (player movement)

**Combat**
- [ ] Attack resolution (rolls, crits, misses)
- [ ] Death & respawn
- [ ] Loot drops
- [ ] Experience & leveling

**AI & NPCs**
- [ ] Mob AI state machine
- [ ] NPC dialogue trees
- [ ] Shop system
- [ ] Quest system

**Persistence**
- [ ] SQLite integration (Ecto)
- [ ] Save/load campaigns
- [ ] Player character persistence
- [ ] World state snapshots

**World Building**
- [ ] Zone file format (JSON/YAML)
- [ ] Procedural generation
- [ ] Tiled Map Editor integration
- [ ] World builder UI

**Client**
- [ ] Bevy/Rust client
- [ ] Tile rendering
- [ ] Entity rendering
- [ ] Animation system
- [ ] UI (chat, inventory, stats)

## Future Vision

### Long-term Goals

**Distributed Elixir**
- [ ] Multi-node deployment (distribute zones across nodes)
- [ ] Zone migration (move zones between nodes for load balancing)
- [ ] Global player registry (cross-node lookups)

**Advanced Features**
- [ ] Weather systems (rain, snow, fog)
- [ ] Day/night cycle (already stubbed in World.Server)
- [ ] Season changes
- [ ] Dynamic events (boss spawns, world events)
- [ ] Crafting system
- [ ] Building/housing system
- [ ] PvP zones
- [ ] Guild system

**GM Features**
- [ ] Live campaign editing (change zones while players are in them)
- [ ] Dynamic difficulty scaling
- [ ] Campaign templates (pre-built adventures)
- [ ] Marketplace for community campaigns
- [ ] Sprite marketplace (community assets)

**Analytics**
- [ ] Player behavior tracking
- [ ] Zone heat maps (where players spend time)
- [ ] Combat statistics
- [ ] Economy monitoring (gold flow, item distribution)

## Development

### Running Tests

```bash
mix test
```

### Code Quality

```elixir
# Check for compile-time warnings
mix compile --warnings-as-errors

# Run Dialyzer (type checking)
mix dialyzer

# Format code
mix format
```

### Generating Documentation

```bash
mix docs
```

Documentation will be generated in the `doc/` directory.

## Technical Stack

- **Server:** Elixir 1.18+ / OTP 27+
- **Client:** Rust + Bevy (planned)
- **Network:** Phoenix Channels (WebSocket)
- **Persistence:** SQLite + Ecto (planned)
- **Deployment:** Docker + Fly.io (planned)

## Contributing

This is currently a personal project. Contributions are welcome once the initial architecture stabilizes (Phase 2 completion).

## License

This project is currently unlicensed. Please contact the maintainer for usage permissions.

---

**Current Status:** 70% complete - Core architecture done, working test world, ready for networking integration.

**Next Milestone:** Playable demo with Phoenix Channels (1-2 weeks)

