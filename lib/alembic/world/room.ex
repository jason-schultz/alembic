defmodule Alembic.World.Room do
  use GenServer

  defstruct [:id, :name, :description, :exits, players: [], npcs: []]

  def start_link(attrs) do
    GenServer.start_link(__MODULE__, attrs, name: via_tuple(attrs.id))
  end

  def init(attrs) do
    {:ok, struct(__MODULE__, attrs)}
  end

  # Public API
  def look(room_id) do
    GenServer.call(via_tuple(room_id), :look)
  end

  def add_player(room_id, player_id) do
    GenServer.cast(via_tuple(room_id), {:add_player, player_id})
  end

  def remove_player(room_id, player_id) do
    GenServer.cast(via_tuple(room_id), {:remove_player, player_id})
  end

  def add_npc(room_id, npc_id) do
    GenServer.cast(via_tuple(room_id), {:add_npc, npc_id})
  end

  def remove_npc(room_id, npc_id) do
    GenServer.cast(via_tuple(room_id), {:remove_npc, npc_id})
  end

  # Callbacks
  def handle_call(:look, _from, state) do
    {:reply, state, state}
  end

  def handle_cast({:add_player, player_id}, state) do
    {:noreply, %{state | players: [player_id | state.players]}}
  end

  def handle_cast({:remove_player, player_id}, state) do
    {:noreply, %{state | players: List.delete(state.players, player_id)}}
  end

  def handle_cast({:add_npc, npc_id}, state) do
    {:noreply, %{state | npcs: [npc_id | state.npcs]}}
  end

  def handle_cast({:remove_npc, npc_id}, state) do
    {:noreply, %{state | npcs: List.delete(state.npcs, npc_id)}}
  end

  defp via_tuple(id) do
    {:via, Registry, {Alembic.World.RoomRegistry, id}}
  end
end
