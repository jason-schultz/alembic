# Alembic

A tabletop RPG campaign server built with Elixir, designed to enable Dungeon Masters and Game Masters to build interactive worlds for their players to explore.

## What is Alembic?

Alembic is a multiplayer game server that brings tabletop RPG campaigns to life in a digital format. It allows DMs/GMs to create persistent worlds that players can interact with in real-time, combining the flexibility of traditional tabletop gaming with the convenience and visual richness of digital platforms.

### Current State

Alembic currently functions as a **MUD-style (Multi-User Dungeon) server** with:

- **Room-based world navigation** - Players move between connected rooms
- **Player management** - Character creation with RPG attributes (strength, dexterity, constitution, etc.)
- **Skill system** - Flexible skill progression using a map-based approach
- **Inventory & equipment** - Item management and equipment slots
- **Dynamic process supervision** - Players and rooms run as supervised GenServer processes
- **Registry-based lookups** - Fast entity lookups by ID using Elixir's Registry

### Future Goals

Alembic is evolving toward a comprehensive campaign management platform with:

#### Persistence
- **SQLite integration** - Save and restore world state between sessions
- **Campaign continuity** - Return to your campaign exactly where you left off

#### World Building
- **Declarative world definition** - Define worlds using JSON, YAML, or Cargo configuration files
- **World builder UI** - Visual interface for DMs/GMs to design maps, place NPCs, and configure encounters
- **Custom sprite support** - DMs can upload sprites for monsters, buildings, NPCs, and environmental objects
- **Player customization** - Players can upload custom character sprites

#### Client Architecture
- **WebAssembly-based client** - Browser-based game client built with Bevy
- **Real-time rendering** - 2D top-down view (Legend of Zelda-style movement and perspective)
- **Server-authoritative** - Game logic remains on the server to prevent cheating
- **Coordinate-based movement** - Smooth character movement with fine-grained positioning
- **DM/GM master view** - Dedicated interface for campaign oversight and world management

## Running the Server

### Prerequisites

- Elixir 1.18+ and Erlang/OTP 27+
- Mix build tool

### Starting the Server

```bash
# Clone the repository
git clone <repository-url>
cd alembic

# Install dependencies
mix deps.get

# Compile the project
mix compile

# Start an interactive Elixir shell with the application running
iex -S mix
```

### Testing the Server

Once in the IEx shell, you can interact with the world:

```elixir
# List all available rooms
Alembic.World.RoomRegistry.list_room_ids()

# Create a new player
{:ok, _pid} = Alembic.Supervisors.GameSupervisor.start_player(%{
  id: "player1",
  name: "Adventurer",
  description: "A brave soul seeking fortune"
})

# Get player state
Alembic.Entity.Player.get_state("player1")

# Move player to a room
Alembic.Entity.Player.move_to_room("player1", "tavern")

# Look at the current room
Alembic.World.Room.look("tavern")

# Move through the world
Alembic.Entity.Player.move_to_room("player1", "town_square")
Alembic.Entity.Player.move_to_room("player1", "dark_forest")
```

## Architecture

Alembic uses Elixir's OTP principles for robustness and concurrency:

- **GenServer processes** - Each player and room runs as an independent process
- **Dynamic supervision** - Entities are supervised for fault tolerance
- **Registry pattern** - Fast lookups using Elixir's built-in Registry
- **Process isolation** - Failures in one entity don't affect others

### Module Organization

```
lib/alembic/
├── entity/              # Game entities (players, NPCs, items)
│   ├── player.ex
│   ├── player_registry.ex
│   └── position.ex
├── world/               # World infrastructure
│   ├── room.ex
│   ├── room_registry.ex
│   └── world_builder.ex
├── supervisors/         # OTP supervisors
│   └── game_supervisor.ex
└── application.ex       # Application entry point
```

## Development

### Running Tests

```bash
mix test
```

### Generating Documentation

```bash
mix docs
```

Documentation will be generated in the `doc/` directory and can be viewed by opening `doc/index.html` in your browser.

## Roadmap

- [ ] WebSocket server for real-time client connections
- [ ] SQLite persistence layer
- [ ] World definition file parser (JSON/YAML)
- [ ] Combat system
- [ ] NPC AI and dialogue system
- [ ] Item system with effects
- [ ] World builder web UI
- [ ] Bevy-based WebAssembly client
- [ ] DM/GM master view interface
- [ ] Sprite upload and management
- [ ] Fine-grained coordinate positioning

## License

This project is currently unlicensed. Please contact the maintainer for usage permissions.

