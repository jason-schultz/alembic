# Alembic

A multiplayer 2D RPG game server built with Elixir, designed for Dungeon Masters and Game Masters to create interactive worlds for their players to explore. Inspired by classic top-down RPGs like The Legend of Zelda and Stardew Valley, with tabletop RPG mechanics.

## What is Alembic?

Alembic is a real-time multiplayer game server that brings tabletop RPG campaigns to life in a digital format. Players move through grid-based zones, interact with NPCs, fight mobs, and explore worlds created by GMs. The server handles all game logic, while clients (built with Bevy/Rust) render the world and handle player input.

## Current State (~80% Complete)

Alembic has a **working game server** with:

✅ **Grid-based zones** - Players move on x,y coordinates through large continuous zones
✅ **Multi-campaign support** - Run multiple independent campaigns on one server
✅ **Dual coordinate system** - Local zone coords + global world coords for seamless transitions
✅ **Viewport system** - Server sends 20x12 tile viewports to clients
✅ **Movement validation** - Tile walkability, boundary checking, room transitions
✅ **Multi-player** - Multiple players visible in same zone
✅ **Entity system** - Players, Mobs, NPCs with stats, equipment, attributes
✅ **Combat system** - Multi-type damage (physical, fire, ice, etc.) with resistances
✅ **Process architecture** - Fault-tolerant supervised GenServers
✅ **TCP network layer** - Binary protocol, challenge/response auth, heartbeats
✅ **Asset pipeline** - PNG validation, grid metadata, manifest generation with tile labels
✅ **HTTP asset server** - Serves manifests and images to clients
✅ **Campaign loader** - Loads zones, rooms, and tiles from campaign.json

### What Works Right Now

```bash
# Start the server (TCP on :7777, HTTP assets on :8080)
iex -S mix

# Process assets for a campaign
mix alembic.assets.process main_story
```

```elixir
# Load a campaign from priv/campaigns/<id>/campaign.json
Alembic.Campaign.CampaignLoader.load("main_story")

# Move a player (direction: :north | :south | :east | :west)
Alembic.World.Zone.move_player_facing("town_millhaven", "player_id", :north)

# Get viewport (what the client renders)
Alembic.World.Zone.get_viewport("town_millhaven", 10, 9)
# => %{tiles: [...240 tiles...], entities: [...]}
```

## Architecture Overview

### Server Architecture

```
                          ┌─────────────────────┐
Rust/Bevy client ──TCP──► │ Network.Acceptor     │ :7777
                          │ Network.ConnectionHandler (per client)
                          └──────────┬──────────┘
                                     │
                          ┌──────────▼──────────┐
Rust/Bevy client ──HTTP──►│ Http.AssetServer     │ :8080
                          │ /worlds/:id/manifest  │
                          │ /worlds/:id/assets/*  │
                          └──────────┬──────────┘
                                     │
                          ┌──────────▼──────────┐
                          │ Campaign.CampaignLoader
                          │ World.Server          │
                          │ ├── Zone (GenServer)  │
                          │ │   ├── Players       │
                          │ │   ├── Mobs          │
                          │ │   └── Tiles         │
                          │ └── Room (GenServer)  │
                          └─────────────────────┘
```

### Process Model

- Each Campaign = 1 `World.Server` GenServer
- Each Zone = 1 `Zone` GenServer (tick loop for mob AI, spawns)
- Each Room = 1 `Room` GenServer (loaded on-demand)
- Each Player = 1 `Player` GenServer (connection state, inventory)
- Each Connection = 1 `ConnectionHandler` GenServer (temporary, supervised)
- All supervised for fault tolerance

---

## Module Breakdown

### 🟢 Network Layer (70% Complete)

| Module | Status | Notes |
|--------|--------|-------|
| `Network.Acceptor` | ✅ | TCP listener on port 7777 |
| `Network.ConnectionHandler` | ✅ | Per-client GenServer, full state machine |
| `Network.Protocol.Packet` | ✅ | Packet type constants (macros) |
| `Network.Protocol.Encoder` | ✅ | Binary packet encoding |
| `Network.Protocol.Decoder` | ✅ | Binary packet decoding |
| `Supervisors.ConnectionSupervisor` | ✅ | DynamicSupervisor for connections |
| `Http.AssetServer` | ✅ | Bandit/Plug HTTP server on port 8080 |

**Connection state machine:** `:handshake` → `:authenticating` → `:authenticated` → `:active`

**Protocol:** Custom binary protocol with 13-byte header (`ALBC` magic + version + packet ID + length). Auth uses HMAC-SHA256 challenge/response with a 10-second auth timeout and 30-second heartbeats.

**Packet types defined:**

| Range | Category | Packets |
|-------|----------|---------|
| `0x0001–0x0002` | Handshake | `handshake_request`, `handshake_response` |
| `0x0010–0x0012` | Auth | `auth_request`, `auth_success`, `auth_failure` |
| `0x0020–0x0023` | Session | `session_ready`, `disconnect`, `heartbeat`, `heartbeat_ack` |
| `0x0100–0x0107` | Game | `player_move`, `viewport_update`, `entity_spawn/despawn/move`, `combat_event`, `chat_message` |
| `0x0200–0x0204` | World sync | `zone_info`, `room_info`, `spawn_position`, `position_confirm/correction` |
| `0x0300–0x0302` | World selection | `join_world`, `leave_world`, `world_list` |

**Missing:**
- [ ] Room transition packets (enter/exit room)
- [ ] Entity broadcast to nearby players (currently only sender gets updates)
- [ ] Reconnect session handoff (handler PID transfer)

---

### 🟢 Asset Pipeline (100% Complete) ✅

| Module | Status | Notes |
|--------|--------|-------|
| `Assets.Processor` | ✅ | Reads PNG dimensions from header, computes grid columns/rows |
| `Assets.Validator` | ✅ | Validates PNG files (existence, magic bytes, size, dimensions, tile label bounds) |
| `Assets.Manifest` | ✅ | Reads asset_meta.json, validates assets, writes manifest.json |

**Mix task:** `mix alembic.assets.process <world_id>`

**asset_meta.json format:**
```json
{
  "tilesets": [
    {
      "id": "Water_Tile",
      "file": "manifest/tiles/Water_Tile.png",
      "tile_width": 16,
      "tile_height": 16,
      "tile_labels": {
        "water_fill": [1, 1],
        "water_edge_top": [1, 0]
      }
    }
  ],
  "sprite_sheets": [...],
  "npc_sheets": [...]
}
```

`tile_labels` are optional. Each label maps a friendly name to a `[column, row]` atlas coordinate. Invalid coordinates (out of grid bounds) are caught at build time.

---

### 🟢 HTTP Asset Server (100% Complete) ✅

Runs on port 8080 (configurable via `:alembic, :asset_port`).

| Route | Description |
|-------|-------------|
| `GET /health` | Liveness check |
| `GET /worlds/:world_id/manifest` | Unified asset manifest (JSON) |
| `GET /worlds/:world_id/assets/*path` | Serves PNG/JPG asset files |

Only serves assets for running campaigns. Validates `world_id` against path traversal. Restricted to image file extensions.

---

### 🟢 Campaign Loader (100% Complete) ✅

| Module | Status | Notes |
|--------|--------|-------|
| `Campaign.CampaignLoader` | ✅ | Reads campaign.json, builds Zone/Room structs, starts the world |
| `Campaign.CampaignManager` | ✅ | Start/stop campaigns, list running worlds |

**campaign.json structure:** defines `id`, `name`, `start_zone_id`, `start_x/y`, a `zones` array (each with a 2D tile grid), and a `rooms` array (each with entrances that link back to zones).

Tiles reference tilesets by `asset_id` (matching `tile_labels` in `asset_meta.json`).

---

### 🟢 Entity System (90% Complete)

| Module | Status | Notes |
|--------|--------|-------|
| `Entity.Player` | ✅ | GenServer with movement, inventory, equipment, handler PID |
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

---

### 🟢 World System (85% Complete)

| Module | Status | Notes |
|--------|--------|-------|
| `World.Zone` | ✅ | GenServer with viewport, movement, tick loop |
| `World.Room` | ✅ | GenServer with multiple entrances |
| `World.Tile` | ✅ | Texture, walkability, type, elevation |
| `World.Server` | ✅ | Campaign coordinator, spawn positions |
| `World.Base` | ✅ | Shared GenServer logic for Zone/Room |
| `World.TileDefinition` | ✅ | Tile type definitions |
| `World.SpawnPoint` | ✅ | Spawn point struct |
| `World.Exit` | ✅ | Zone exit definitions |
| `World.RoomDefinition` | ✅ | Room definition struct |
| `World.ChunkManager` | ⚠️ | Planned — viewport delta streaming |

**Missing:**
- [ ] Zone transitions (seamless zone borders)
- [ ] Procedural generation
- [ ] Tile interaction metadata (doors, levers, chests)

---

### 🟢 Registry System (100% Complete) ✅

| Registry | Status |
|----------|--------|
| `Registry.Base` | ✅ |
| `Registry.PlayerRegistry` | ✅ |
| `Registry.MobRegistry` | ✅ |
| `Registry.NPCRegistry` | ✅ |
| `Registry.ZoneRegistry` | ✅ |
| `Registry.RoomRegistry` | ✅ |
| `Registry.CampaignRegistry` | ✅ |

---

### 🟢 Supervisor System (100% Complete) ✅

| Supervisor | Status |
|------------|--------|
| `Supervisors.PlayerSupervisor` | ✅ |
| `Supervisors.MobSupervisor` | ✅ |
| `Supervisors.NPCSupervisor` | ✅ |
| `Supervisors.ZoneSupervisor` | ✅ |
| `Supervisors.RoomSupervisor` | ✅ |
| `Supervisors.CampaignSupervisor` | ✅ |
| `Supervisors.ConnectionSupervisor` | ✅ |

---

### 🟡 Game Systems (60% Complete)

| Module | Status | Notes |
|--------|--------|-------|
| `Game.Combat` | ⚠️ | Damage calculation stub |
| `Game.Movement` | ✅ | Position updates, validation |
| `Game.Commands` | ⚠️ | Planned — text command parser |

**Missing:**
- [ ] Combat resolution (attack rolls, crits, dodges)
- [ ] Mob AI behaviors (wander, patrol, aggro, flee)
- [ ] Quest system
- [ ] Dialogue system
- [ ] Crafting system

---

### 🟡 Accounts / Auth (50% Complete)

| Module | Status | Notes |
|--------|--------|-------|
| `Accounts` | ⚠️ | `get_player_by_token/1` stub — no persistence yet |

**Missing:**
- [ ] Player account storage (Ecto + SQLite)
- [ ] Token issuance / revocation
- [ ] Session persistence across restarts

---

## Running the Server

### Prerequisites

- Elixir 1.18+ and Erlang/OTP 27+
- Mix build tool

### Dependencies

| Dep | Purpose |
|-----|---------|
| `ecto_sql ~> 3.13` | Database (persistence, planned) |
| `jason ~> 1.4` | JSON encoding/decoding |
| `plug ~> 1.14` | HTTP routing for asset server |
| `bandit ~> 1.0` | HTTP server (asset serving on port 8080) |

### Quick Start

```bash
# Install dependencies
mix deps.get

# Process assets for a campaign (generates manifest.json)
mix alembic.assets.process main_story

# Start interactive shell (TCP :7777, HTTP :8080)
iex -S mix
```

```elixir
# Load a campaign
Alembic.Campaign.CampaignLoader.load("main_story")

# Move a player
Alembic.World.Zone.move_player_facing("town_millhaven", player_id, :north)

# Get viewport
Alembic.World.Zone.get_viewport("town_millhaven", 10, 9)
```

### Module Organization

```
lib/alembic/
├── application.ex
├── accounts.ex                  # Token-based auth (stub)
├── assets/
│   ├── manifest.ex              # Reads asset_meta.json, writes manifest.json
│   ├── processor.ex             # PNG dimension extraction, grid computation
│   └── validator.ex             # PNG + tile label validation
├── campaign/
│   ├── campaign_loader.ex       # Loads campaign.json, starts zones/rooms
│   └── campaign_manager.ex      # Start/stop campaigns, list running worlds
├── entity/
│   ├── base.ex                  # Shared GenServer logic
│   ├── player.ex                # Player GenServer
│   ├── mob.ex                   # Mob struct (GenServer TODO)
│   ├── npc.ex                   # NPC struct (GenServer TODO)
│   ├── position.ex              # Dual coordinate system
│   ├── stats.ex                 # HP, MP, resistances
│   ├── attributes.ex            # RPG attributes
│   ├── equipment.ex             # 13 equipment slots
│   ├── sprite_config.ex         # Animation state
│   ├── combatant.ex             # Protocol for combat
│   └── damage_component.ex      # Multi-type damage
├── http/
│   └── asset_server.ex          # Bandit/Plug HTTP server (port 8080)
├── network/
│   ├── acceptor.ex              # TCP listener (port 7777)
│   ├── connection_handler.ex    # Per-client state machine GenServer
│   └── protocol/
│       ├── packet.ex            # Packet type constants
│       ├── encoder.ex           # Binary packet encoding
│       └── decoder.ex           # Binary packet decoding
├── registry/
│   ├── base.ex
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
│   ├── campaign_supervisor.ex
│   └── connection_supervisor.ex
└── world/
    ├── base.ex                  # Shared Zone/Room logic
    ├── zone.ex                  # Large zone GenServer
    ├── room.ex                  # Small room GenServer
    ├── tile.ex                  # Grid tile struct
    ├── tile_definition.ex       # Tile type definitions
    ├── spawn_point.ex           # Spawn point struct
    ├── exit.ex                  # Zone exit definitions
    ├── room_definition.ex       # Room definition struct
    ├── object_definition.ex     # World object definitions
    ├── server.ex                # World coordinator
    └── campaign_loader.ex       # Campaign deserialization

lib/mix/tasks/
└── alembic.assets.process.ex   # mix alembic.assets.process <world_id>

priv/campaigns/<world_id>/
├── campaign.json                # Zone layout, tile grid, room entrances
├── asset_meta.json              # Tileset + spritesheet definitions with tile_labels
└── manifest/
    ├── tiles/                   # Tileset PNGs
    └── sprites/                 # Character + NPC spritesheet PNGs
```

---

## Next Steps (Priority Order)

### Phase 1: Playable Client Connection

1. **Entity broadcast** — When a player moves, nearby players should receive `entity_move` packets. Currently only the moving player gets a viewport update.

2. **Room transitions** — The connection handler has TODOs for `enter_room` / `leave_room`. Wire up `World.Server.enter_room` and send `room_info` + `spawn_position` to the client.

3. **Account persistence** — `Accounts.get_player_by_token/1` is a stub. Needs Ecto + SQLite to store player accounts and issue tokens.

4. **Rust/Bevy client** — Connect to the TCP server, read the binary protocol, render the viewport.

### Phase 2: Combat & NPCs

5. **Combat resolution** — Implement `Game.Combat.resolve_attack/3` with attack rolls, crits, dodges, death.

6. **Mob AI** — Promote Mob to GenServer with an AI state machine (idle → wander → aggro → combat → dead), pathfinding (A*), respawn timers.

7. **NPCs** — Promote NPC to GenServer with dialogue trees, shop system, quest givers.

### Phase 3: GM Tools

8. **Campaign builder** — Web-based map editor, drag-and-drop tile placement, NPC/mob spawn editors.

9. **Campaign tile validation** — Validate that every `asset_id` in campaign.json's tile grid matches a `tile_label` in asset_meta.json (currently a backlog item).

---

## Roadmap

### ✅ Completed (~80%)

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
- [x] Campaign manager (multi-campaign support)
- [x] TCP network layer (binary protocol, auth, heartbeats)
- [x] Asset pipeline (PNG validation, grid metadata, tile labels, manifest.json)
- [x] HTTP asset server (manifest + file serving)
- [x] Campaign loader (campaign.json → Zone/Room structs)

### 🚧 In Progress

- [ ] Entity broadcast (movement visible to nearby players)
- [ ] Room transitions (enter/exit room packets)
- [ ] Account persistence (Ecto + SQLite)

### 📋 Planned

**Client**
- [ ] Rust + Bevy client
- [ ] Tile rendering (2D grid from manifest)
- [ ] Entity rendering (players, mobs, NPCs)
- [ ] Sprite animation (walk cycles, idle)
- [ ] UI (chat, inventory, stats, health bars, minimap)

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
- [ ] Player character persistence
- [ ] World state snapshots

**World Building**
- [ ] Campaign tile validation (asset_id ↔ tile_label cross-check)
- [ ] Campaign builder UI (web-based map editor)
- [ ] Procedural generation

---

## Future Vision

**Distributed Elixir**
- [ ] Multi-node deployment (distribute zones across nodes)
- [ ] Zone migration (move zones between nodes for load balancing)
- [ ] Global player registry (cross-node lookups)

**Advanced Features**
- [ ] Weather systems (rain, snow, fog)
- [ ] Day/night cycle (already stubbed in World.Server)
- [ ] Dynamic events (boss spawns, world events)
- [ ] Crafting and building/housing systems
- [ ] PvP zones, guild system

**GM Features**
- [ ] Live campaign editing (change zones while players are in them)
- [ ] Dynamic difficulty scaling
- [ ] Campaign templates (pre-built adventures)
- [ ] Community asset marketplace

---

## Development

### Running Tests

```bash
mix test
```

### Code Quality

```bash
# Check for compile-time warnings
mix compile --warnings-as-errors

# Format code
mix format
```

### Generating Documentation

```bash
mix docs
```

---

## Technical Stack

| Layer | Technology |
|-------|-----------|
| Server | Elixir 1.18+ / OTP 27+ |
| Game protocol | Raw TCP, custom binary protocol (port 7777) |
| Asset serving | HTTP via Bandit + Plug (port 8080) |
| JSON | Jason |
| Persistence | Ecto + SQLite (planned) |
| Client | Rust + Bevy (planned) |
| Deployment | Docker + Fly.io (planned) |

## Contributing

This is currently a personal project. Contributions are welcome once the initial architecture stabilizes.

## License

This project is currently unlicensed. Please contact the maintainer for usage permissions.

---

**Current Status:** ~80% complete — core architecture, networking, asset pipeline, and campaign loading done. Next milestone: entity broadcast + room transitions + Rust client.
