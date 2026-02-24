defmodule Alembic.Entity.NPC do
  use GenServer

  @moduledoc """
  A GenServer representing a non-player character (NPC) in the Alembic world.

  NPCs can be merchants, quest givers, enemies, or ambient characters that
  bring the world to life.
  """

  alias Alembic.Entity.Position

  defstruct [
    :id,
    :name,
    :description,
    # NPC type: :merchant, :quest_giver, :enemy, :ambient, :boss
    type: :ambient,
    # Position in the world
    position: %Position{},
    # Dialogue lines the NPC can say
    dialogue: [],
    # Items the NPC has (for merchants or loot)
    inventory: [],
    # Is the NPC hostile?
    hostile: false,
    # Combat stats (if hostile)
    attributes: %{
      strength: 5,
      dexterity: 5,
      constitution: 5
    },
    health: 50,
    max_health: 50,
    # Behavior flags
    behavior: %{
      wanders: false,
      respawns: false,
      aggro_range: 0
    }
  ]

  # Client API

  @doc """
  Starts an NPC GenServer.
  """
  def start_link(attrs) when is_map(attrs) do
    id = attrs[:id] || attrs.id
    GenServer.start_link(__MODULE__, attrs, name: via_tuple(id))
  end

  def start_link(attrs) when is_list(attrs) do
    start_link(Map.new(attrs))
  end

  @doc """
  Gets the current state of an NPC.
  """
  def get_state(npc_id) do
    GenServer.call(via_tuple(npc_id), :get_state)
  end

  @doc """
  Gets a random dialogue line from the NPC.
  """
  def speak(npc_id) do
    GenServer.call(via_tuple(npc_id), :speak)
  end

  @doc """
  Moves an NPC to a new room.
  """
  def move_to_room(npc_id, room_id) do
    GenServer.call(via_tuple(npc_id), {:move_to_room, room_id})
  end

  @doc """
  Applies damage to the NPC.
  """
  def take_damage(npc_id, amount) do
    GenServer.call(via_tuple(npc_id), {:take_damage, amount})
  end

  # Server Callbacks

  @impl true
  def init(attrs) do
    state = struct(__MODULE__, attrs)
    # If the NPC has a starting room, add itself to that room
    if state.position.current_room_id do
      Alembic.World.Room.add_npc(state.position.current_room_id, state.id)
    end

    {:ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call(:speak, _from, state) do
    dialogue =
      if Enum.empty?(state.dialogue) do
        "..."
      else
        Enum.random(state.dialogue)
      end

    {:reply, dialogue, state}
  end

  @impl true
  def handle_call({:move_to_room, room_id}, _from, state) do
    # Remove from old room
    if state.position.current_room_id do
      Alembic.World.Room.remove_npc(state.position.current_room_id, state.id)
    end

    # Add to new room
    Alembic.World.Room.add_npc(room_id, state.id)

    # Update position
    new_position = %{state.position | current_room_id: room_id}
    new_state = %{state | position: new_position}

    {:reply, {:ok, room_id}, new_state}
  end

  @impl true
  def handle_call({:take_damage, amount}, _from, state) do
    new_health = max(0, state.health - amount)
    new_state = %{state | health: new_health}

    result = if new_health == 0, do: {:dead, new_state}, else: {:ok, new_state}

    {:reply, result, new_state}
  end

  # Private Helpers

  defp via_tuple(npc_id) do
    {:via, Registry, {Alembic.Entity.NPCRegistry, npc_id}}
  end
end
