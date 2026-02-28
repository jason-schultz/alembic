defmodule Alembic.World.Zone do
  @moduledoc """
  A GenServer representing a single zone in the game world.

  A zone is a large continuous grid of tiles (e.g. overworld, dungeon, town).
  It owns its tile grid, manages entity positions within it, runs the mob
  spawn/tick loop, and broadcasts state changes to all players in the zone.

  ## Zone Types
  - `:overworld`  - Large open world grid, weather, day/night cycle
  - `:dungeon`    - Shared instanced area, mob respawns, boss rooms
  - `:town`       - Safe zone, NPC schedules, merchants
  - `:wilderness` - Open PvE, random encounters
  - `:interior`   - Building interiors loaded as part of the parent zone grid
  """

  use Alembic.World.Base,
    registry: Alembic.Registry.ZoneRegistry,
    viewport_width: 20,
    viewport_height: 12,
    tick_interval: 100

  @zone_types [:overworld, :dungeon, :town, :wilderness, :interior]

  @type zone_type :: :overworld | :dungeon | :town | :wilderness | :interior

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          type: zone_type(),
          width: non_neg_integer(),
          height: non_neg_integer(),
          world_offset_x: non_neg_integer(),
          world_offset_y: non_neg_integer(),
          tiles: %{{non_neg_integer(), non_neg_integer()} => Alembic.World.Tile.t()},
          players: %{String.t() => {non_neg_integer(), non_neg_integer()}},
          mobs: %{String.t() => {non_neg_integer(), non_neg_integer()}},
          spawn_points: list(map()),
          safe_zone: boolean(),
          metadata: map()
        }

  defstruct [
    :id,
    :name,
    :width,
    :height,
    world_offset_x: 0,
    world_offset_y: 0,
    type: :overworld,
    tiles: %{},
    players: %{},
    mobs: %{},
    spawn_points: [],
    safe_zone: false,
    metadata: %{}
  ]

  # Zone-specific API (not in base)

  @doc """
  GM only - spawns a mob at the given position.
  """
  def gm_spawn_mob(zone_id, mob_type, x, y) do
    GenServer.cast(via_tuple(zone_id), {:gm_spawn_mob, mob_type, x, y})
  end

  # Zone-specific callbacks

  @impl true
  def handle_cast({:gm_spawn_mob, mob_type, x, y}, state) do
    Logger.info("GM spawning mob #{mob_type} at (#{x}, #{y}) in zone #{state.id}")
    # TODO: wire up to MobSupervisor when implemented
    {:noreply, state}
  end

  # Override base implementations

  defp process_tick(state) do
    state
    |> tick_mobs()
    |> tick_spawns()
  end

  defp world_type, do: "Zone"

  # Zone-specific private functions

  defp tick_mobs(state) do
    # TODO: iterate mobs, send AI tick messages to each Mob GenServer
    state
  end

  defp tick_spawns(state) do
    # TODO: check spawn points, respawn mobs if needed
    state
  end

  @doc """
  Returns true if the zone type is valid.
  """
  def valid_type?(type), do: type in @zone_types
end
