defmodule Alembic.World.Room do
  @moduledoc """
  A GenServer representing a room (interior building space).

  Rooms are smaller, instanced areas like taverns, shops, houses, etc.
  They have their own tile grid but are typically entered from a zone.

  ## Entrances
  Rooms can have multiple entrances/exits. Each entrance defines:
  - Where in the room the player spawns (room_x, room_y)
  - What zone it connects to (zone_id)
  - Where in that zone it leads (zone_x, zone_y)
  - Optional: a door key requirement, one-way exit flag, etc.

  ## Movement
  The Room is the authority on movement validation. When a player moves,
  the Room checks walkability and whether the destination tile is an entrance
  (exit trigger). Transitions are returned to the caller (ConnectionHandler)
  as {:transition, entrance} so it can orchestrate the room/zone change.
  """

  use Alembic.World.Base,
    registry: Alembic.Registry.RoomRegistry,
    viewport_width: 16,
    viewport_height: 10,
    tick_interval: 100

  @room_types [:tavern, :shop, :house, :dungeon_room, :puzzle_room]

  @type room_type :: :tavern | :shop | :house | :dungeon_room | :puzzle_room

  @type entrance :: %{
          id: String.t(),
          room_x: non_neg_integer(),
          room_y: non_neg_integer(),
          leads_to_zone_id: String.t(),
          leads_to_x: non_neg_integer(),
          leads_to_y: non_neg_integer(),
          requires_key: String.t() | nil,
          one_way: boolean(),
          metadata: map()
        }

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          type: room_type(),
          width: non_neg_integer(),
          height: non_neg_integer(),
          tiles: %{{non_neg_integer(), non_neg_integer()} => Alembic.World.Tile.t()},
          players: %{String.t() => {non_neg_integer(), non_neg_integer()}},
          npcs: list(String.t()),
          entrances: list(entrance()),
          metadata: map()
        }

  defstruct [
    :id,
    :name,
    type: :house,
    width: 16,
    height: 10,
    tiles: %{},
    players: %{},
    npcs: [],
    entrances: [],
    metadata: %{}
  ]

  # Client API

  @doc """
  Moves a player one step in the given facing direction.

  Returns:
  - `{:ok, {new_x, new_y}}` — moved successfully, broadcast to others handled internally
  - `{:transition, entrance}` — stepped on an entrance tile, caller must handle room change
  - `{:error, reason}` — move blocked (out of bounds, unwalkable tile)
  """
  def move_player_facing(room_id, player_id, facing) do
    GenServer.call(via_tuple(room_id), {:move_player_facing, player_id, facing})
  end

  @doc """
  Adds a player to the room at a named entrance, or at coordinates if entrance_id is nil.
  Returns `{:ok, {x, y}}` with the resolved spawn position.
  """
  def player_enter_at(room_id, player_id, entrance_id) do
    GenServer.call(via_tuple(room_id), {:player_enter_at, player_id, entrance_id})
  end

  @doc """
  Returns the entrance that the player is standing on (if any).
  Used when a player tries to exit the room.
  """
  def get_entrance_at(room_id, x, y) do
    GenServer.call(via_tuple(room_id), {:get_entrance_at, x, y})
  end

  @doc """
  Returns all entrances for the room.
  """
  def list_entrances(room_id) do
    GenServer.call(via_tuple(room_id), :list_entrances)
  end

  @doc """
  Finds an entrance by its ID.
  """
  def get_entrance_by_id(room_id, entrance_id) do
    GenServer.call(via_tuple(room_id), {:get_entrance_by_id, entrance_id})
  end

  @doc """
  Creates an entrance definition map.
  """
  def create_entrance(id, room_x, room_y, zone_id, zone_x, zone_y, opts \\ []) do
    %{
      id: id,
      room_x: room_x,
      room_y: room_y,
      leads_to_zone_id: zone_id,
      leads_to_x: zone_x,
      leads_to_y: zone_y,
      requires_key: Keyword.get(opts, :requires_key),
      one_way: Keyword.get(opts, :one_way, false),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  @doc """
  Returns true if the room type is valid.
  """
  def valid_type?(type), do: type in @room_types

  # Server callbacks

  @impl true
  def handle_call({:player_enter_at, player_id, entrance_id}, _from, state) do
    {x, y} = resolve_spawn(state, entrance_id)
    new_players = Map.put(state.players, player_id, {x, y})
    new_state = %{state | players: new_players}

    broadcast_to_others(new_state.players, player_id, {:player_entered_room, player_id, x, y})

    Logger.info("Player #{player_id} entered room #{state.id} at (#{x}, #{y})")
    {:reply, {:ok, {x, y}}, new_state}
  end

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
              {:player_moved, player_id, new_x, new_y}
            )

            {:reply, {:ok, {new_x, new_y}}, new_state}
        end

      :error ->
        {:reply, {:error, :player_not_in_room}, state}
    end
  end

  @impl true
  def handle_call({:get_entrance_at, x, y}, _from, state) do
    result =
      case entrance_at(state, x, y) do
        nil -> {:error, :no_entrance}
        entrance -> {:ok, entrance}
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call(:list_entrances, _from, state) do
    {:reply, state.entrances, state}
  end

  @impl true
  def handle_call({:get_entrance_by_id, entrance_id}, _from, state) do
    result =
      case Enum.find(state.entrances, &(&1.id == entrance_id)) do
        nil -> {:error, :not_found}
        entrance -> {:ok, entrance}
      end

    {:reply, result, state}
  end

  # Override base defaults

  defp world_type, do: "Room"

  defp tick_enabled?, do: false

  # Private helpers

  defp resolve_spawn(state, nil) do
    # No entrance specified — use first entrance or origin
    case List.first(state.entrances) do
      %{room_x: x, room_y: y} -> {x, y}
      nil -> {0, 0}
    end
  end

  defp resolve_spawn(state, entrance_id) do
    case Enum.find(state.entrances, &(&1.id == entrance_id)) do
      %{room_x: x, room_y: y} -> {x, y}
      nil -> resolve_spawn(state, nil)
    end
  end

  defp in_bounds?(state, x, y) do
    x >= 0 and y >= 0 and x < state.width and y < state.height
  end

  defp walkable?(state, x, y) do
    state
    |> Map.get(:tiles, %{})
    |> Map.get({x, y}, %{walkable: false})
    |> Map.get(:walkable, false)
  end

  defp entrance_at(state, x, y) do
    Enum.find(state.entrances, fn e -> e.room_x == x and e.room_y == y end)
  end

  defp apply_facing({x, y}, :north), do: {x, y - 1}
  defp apply_facing({x, y}, :south), do: {x, y + 1}
  defp apply_facing({x, y}, :east), do: {x + 1, y}
  defp apply_facing({x, y}, :west), do: {x - 1, y}

  defp broadcast_to_others(players, exclude_id, message) do
    players
    |> Map.delete(exclude_id)
    |> Enum.each(fn {player_id, _pos} ->
      case Registry.lookup(Alembic.Registry.PlayerRegistry, player_id) do
        [{pid, _}] ->
          send(pid, {:room_event, message})

        [] ->
          Logger.warning(
            "broadcast_to_others: player #{player_id} not found in registry, skipping"
          )
      end
    end)
  end
end
