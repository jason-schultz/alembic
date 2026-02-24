defmodule Alembic.Entity.Player do
  use GenServer

  alias Alembic.Entity.Position

  @moduledoc """
  A GenServer representing a player entity in the Alembic world.

  Each player runs as its own process, maintaining state and handling
  commands, movement, combat, and other interactions.
  """

  defstruct [
    :id,
    :name,
    :description,
    # Core RPG stats
    attributes: %{
      strength: 10,
      dexterity: 10,
      constitution: 10,
      intelligence: 10,
      wisdom: 10,
      charisma: 10
    },
    # Character progression
    level: 1,
    experience: 0,
    # Vitals
    health: 100,
    max_health: 100,
    mana: 100,
    max_mana: 100,
    stamina: 100,
    max_stamina: 100,
    # Skills as a flat map (skill_name => level)
    skills: %{},
    # Inventory as a list (can be enhanced later with item structs)
    inventory: [],
    # Equipment slots
    equipment: %{
      head: nil,
      chest: nil,
      left_leg: nil,
      right_leg: nil,
      left_foot: nil,
      right_foot: nil,
      left_hand: nil,
      right_hand: nil,
      weapon: nil,
      shield: nil,
      accessory1: nil,
      accessory2: nil
    },
    position: %Position{},
    sprite_url: nil,
    sprite_config: %{},
    connection_pid: nil
  ]

  # Client API

  @doc """
  Starts a player GenServer.
  """
  def start_link(attrs) do
    GenServer.start_link(__MODULE__, attrs, name: via_tuple(attrs.id))
  end

  @doc """
  Gets the current state of a player.
  """
  def get_state(player_id) do
    GenServer.call(via_tuple(player_id), :get_state)
  end

  @doc """
  Moves a player to a new room.
  """
  def move_to_room(player_id, room_id) do
    GenServer.call(via_tuple(player_id), {:move_to_room, room_id})
  end

  @doc """
  Adds an item to the player's inventory.
  """
  def add_item(player_id, item) do
    GenServer.cast(via_tuple(player_id), {:add_item, item})
  end

  @doc """
  Removes an item from the player's inventory.
  """
  def remove_item(player_id, item) do
    GenServer.call(via_tuple(player_id), {:remove_item, item})
  end

  @doc """
  Updates a skill level.
  """
  def set_skill(player_id, skill_name, level) do
    GenServer.cast(via_tuple(player_id), {:set_skill, skill_name, level})
  end

  @doc """
  Applies damage to the player.
  """
  def take_damage(player_id, amount) do
    GenServer.call(via_tuple(player_id), {:take_damage, amount})
  end

  @doc """
  Heals the player.
  """
  def heal(player_id, amount) do
    GenServer.cast(via_tuple(player_id), {:heal, amount})
  end

  @doc """
  Sends a message to the player's connection.
  """
  def send_message(player_id, message) do
    GenServer.cast(via_tuple(player_id), {:send_message, message})
  end

  # Server Callbacks

  @impl true
  def init(attrs) do
    {:ok, struct(__MODULE__, attrs)}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:move_to_room, room_id}, _from, state) do
    # Remove from old room
    if state.position.current_room_id do
      Alembic.World.Room.remove_player(state.position.current_room_id, state.id)
    end

    # Add to new room
    Alembic.World.Room.add_player(room_id, state.id)

    new_state = %{state | position: %{state.position | current_room_id: room_id}}
    {:reply, {:ok, room_id}, new_state}
  end

  @impl true
  def handle_call({:remove_item, item}, _from, state) do
    if item in state.inventory do
      new_state = %{state | inventory: List.delete(state.inventory, item)}
      {:reply, {:ok, item}, new_state}
    else
      {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:take_damage, amount}, _from, state) do
    new_health = max(0, state.health - amount)
    new_state = %{state | health: new_health}

    # Notify player they took damage
    if new_state.connection_pid do
      send(
        new_state.connection_pid,
        {:game_message, "You take #{amount} damage! (HP: #{new_health}/#{state.max_health})"}
      )
    end

    # Check if player died
    result = if new_health == 0, do: {:dead, new_state}, else: {:ok, new_state}

    {:reply, result, new_state}
  end

  @impl true
  def handle_cast({:add_item, item}, state) do
    {:noreply, %{state | inventory: [item | state.inventory]}}
  end

  @impl true
  def handle_cast({:set_skill, skill_name, level}, state) do
    new_skills = Map.put(state.skills, skill_name, level)
    {:noreply, %{state | skills: new_skills}}
  end

  @impl true
  def handle_cast({:heal, amount}, state) do
    new_health = min(state.max_health, state.health + amount)
    {:noreply, %{state | health: new_health}}
  end

  @impl true
  def handle_cast({:send_message, message}, state) do
    if state.connection_pid do
      send(state.connection_pid, {:game_message, message})
    end

    {:noreply, state}
  end

  # Private Helpers

  defp via_tuple(player_id) do
    {:via, Registry, {Alembic.Entity.PlayerRegistry, player_id}}
  end
end
