defmodule Alembic.Supervisors.RoomSupervisor do
  @moduledoc """
  A DynamicSupervisor for managing Room GenServer processes.

  Rooms (taverns, shops, houses) are loaded on-demand when players enter
  and can be unloaded when empty to save memory.
  """

  use DynamicSupervisor

  alias Alembic.World.Room

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_room(%Room{} = room_data) do
    child_spec = {Room, room_data}

    case DynamicSupervisor.start_child(__MODULE__, child_spec) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      {:error, reason} -> {:error, reason}
    end
  end

  def stop_room(room_id) do
    case Registry.lookup(Alembic.Registry.RoomRegistry, room_id) do
      [{pid, _}] ->
        DynamicSupervisor.terminate_child(__MODULE__, pid)

      [] ->
        {:error, :not_found}
    end
  end

  def list_rooms do
    DynamicSupervisor.which_children(__MODULE__)
    |> Enum.map(fn {_id, pid, _type, _modules} -> pid end)
    |> Enum.filter(&is_pid/1)
  end

  def count_rooms do
    case DynamicSupervisor.count_children(__MODULE__) do
      %{active: count} -> count
      _ -> 0
    end
  end
end
