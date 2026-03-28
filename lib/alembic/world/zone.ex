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
    viewport_width: 32,
    viewport_height: 24,
    tick_interval: 100,
    hibernate_after: 30_000

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
  Moves a player one step in the given facing direction.

  Returns:
  - `{:ok, {new_x, new_y}}` — moved successfully, broadcast to others handled internally
  - `{:transition, entrance}` — stepped on an entrance tile, caller must handle room change
  - `{:error, reason}` — move blocked (out of bounds, unwalkable tile)
  """
  def move_player_facing(zone_id, player_id, facing) do
    GenServer.call(via_tuple(zone_id), {:move_player_facing, player_id, facing})
  end

  @doc """
  GM only - spawns a mob at the given position.
  """
  def gm_spawn_mob(zone_id, mob_type, x, y) do
    GenServer.cast(via_tuple(zone_id), {:gm_spawn_mob, mob_type, x, y})
  end

  # Zone-specific callbacks

  @impl true
  def handle_call({:move_player_facing, player_id, facing}, _from, state) do
    case Map.fetch(state.players, player_id) do
      {:ok, {x, y}} ->
        {new_x, new_y} = apply_facing({x, y}, facing)

        cond do
          not in_bounds?(state, new_x, new_y) ->
            {:reply, {:error, :out_of_bounds}, state}

          not walkable?(state, new_x, new_y) ->
            {:reply, {:error, :blocked}, state}

          entrance = entrance_at(state, new_x, new_y) ->
            # Don't update position — caller handles the transition
            {:reply, {:transition, entrance}, state}

          true ->
            new_state = %{state | players: Map.put(state.players, player_id, {new_x, new_y})}

            broadcast_to_others(
              new_state.players,
              player_id,
              {:player_moved, player_id, new_x, new_y, state.world_offset_x + new_x,
               state.world_offset_y + new_y}
            )

            {:reply,
             {:ok, {new_x, new_y, state.world_offset_x + new_x, state.world_offset_y + new_y}},
             new_state}
        end

      :error ->
        {:reply, {:error, :player_not_in_room}, state}
    end
  end

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

  defp apply_facing({x, y}, :north), do: {x, y - 1}
  defp apply_facing({x, y}, :south), do: {x, y + 1}
  defp apply_facing({x, y}, :east), do: {x + 1, y}
  defp apply_facing({x, y}, :west), do: {x - 1, y}

  defp in_bounds?(state, x, y) do
    x >= 0 and y >= 0 and x < state.width and y < state.height
  end

  defp walkable?(state, x, y) do
    state.tiles |> Map.get({x, y}, %{walkable: false}) |> Map.get(:walkable, false)
  end

  defp entrance_at(state, x, y) do
    case Map.get(state.tiles, {x, y}) do
      %{room_enter: room_id} when not is_nil(room_id) -> room_id
      _ -> nil
    end
  end

  defp broadcast_to_others(players, exclude_id, message) do
    players
    |> Map.delete(exclude_id)
    |> Enum.each(fn {player_id, _pos} ->
      case Registry.lookup(Alembic.Registry.PlayerRegistry, player_id) do
        [{pid, _}] ->
          send(pid, {:zone_event, message})

        [] ->
          Logger.warning(
            "broadcast_to_others: player #{player_id} not found in registry, skipping"
          )
      end
    end)
  end
end
