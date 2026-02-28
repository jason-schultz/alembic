defmodule Alembic.World.WorldBuilder do
  @moduledoc """
  Sets up the initial world with rooms.
  """

  alias Alembic.World.{Room, Zone}
  alias Alembic.Entity.NPC
  alias Alembic.Supervisors.GameSupervisor

  @doc """
  Initializes the starting rooms for the game world.
  """
  def setup_world do
    # Define initial rooms
    rooms = []

    # Start each room as a GenServer process
    Enum.each(rooms, fn room_attrs ->
      {:ok, _pid} = Room.start_link(room_attrs)
    end)

    # Define NPCs
    npcs = []

    # Start each NPC as a GenServer process
    Enum.each(npcs, fn npc_attrs ->
      {:ok, _pid} = GameSupervisor.start_npc(npc_attrs)
    end)

    :ok
  end
end
