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

  # Room-specific API

  @doc """
  Returns the entrance that the player is standing on (if any).
  Used when a player tries to exit the room.

  ## Examples

      iex> Room.get_entrance_at(room_id, 5, 2)
      {:ok, %{id: "front_door", leads_to_zone_id: "zone_town", ...}}

      iex> Room.get_entrance_at(room_id, 10, 10)
      {:error, :no_entrance}
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
  Finds the entrance by its ID.

  ## Examples

      iex> Room.get_entrance_by_id(room_id, "back_door")
      {:ok, %{id: "back_door", room_x: 15, room_y: 5, ...}}
  """
  def get_entrance_by_id(room_id, entrance_id) do
    GenServer.call(via_tuple(room_id), {:get_entrance_by_id, entrance_id})
  end

  # Room-specific callbacks

  @impl true
  def handle_call({:get_entrance_at, x, y}, _from, state) do
    entrance =
      Enum.find(state.entrances, fn e ->
        e.room_x == x and e.room_y == y
      end)

    result = if entrance, do: {:ok, entrance}, else: {:error, :no_entrance}
    {:reply, result, state}
  end

  @impl true
  def handle_call(:list_entrances, _from, state) do
    {:reply, state.entrances, state}
  end

  @impl true
  def handle_call({:get_entrance_by_id, entrance_id}, _from, state) do
    entrance = Enum.find(state.entrances, fn e -> e.id == entrance_id end)
    result = if entrance, do: {:ok, entrance}, else: {:error, :not_found}
    {:reply, result, state}
  end

  # Override base implementations

  defp world_type, do: "Room"

  defp tick_enabled? do
    # Most rooms don't need ticking
    # Puzzle rooms or trap rooms might override this
    false
  end

  @doc """
  Returns true if the room type is valid.
  """
  def valid_type?(type), do: type in @room_types

  @doc """
  Creates an entrance definition.

  ## Examples

      iex> Room.create_entrance("front_door", 5, 2, "zone_town", 128, 130)
      %{
        id: "front_door",
        room_x: 5,
        room_y: 2,
        leads_to_zone_id: "zone_town",
        leads_to_x: 128,
        leads_to_y: 130,
        requires_key: nil,
        one_way: false,
        metadata: %{}
      }
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
end
