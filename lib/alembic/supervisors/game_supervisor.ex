defmodule Alembic.Supervisors.GameSupervisor do
  @moduledoc """
  Supervisor for dynamic game entities (players, rooms).
  """

  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Starts a new room process.
  """
  def start_room(room_attrs) do
    spec = {Alembic.World.Room, room_attrs}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  @doc """
  Starts a new player process.
  """
  def start_player(player_attrs) do
    spec = {Alembic.Entity.Player, player_attrs}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  @doc """
  Starts a new NPC process.
  """
  def start_npc(npc_attrs) do
    spec = {Alembic.Entity.NPC, npc_attrs}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end
end
