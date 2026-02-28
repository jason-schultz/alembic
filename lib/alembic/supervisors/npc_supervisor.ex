defmodule Alembic.Supervisors.NPCSupervisor do
  @moduledoc """
  A DynamicSupervisor for managing NPC GenServer processes.

  NPCs (merchants, quest givers, trainers) run as separate GenServers.
  Unlike mobs, NPCs typically don't move or have complex AI, but they
  do need to track interaction state (dialogue progress, shop inventory, etc.).
  """

  use DynamicSupervisor

  alias Alembic.Entity.NPC

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def spawn_npc(npc_id, opts \\ []) do
    npc_opts = Keyword.put(opts, :id, npc_id)
    child_spec = {NPC, npc_opts}

    case DynamicSupervisor.start_child(__MODULE__, child_spec) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      {:error, reason} -> {:error, reason}
    end
  end

  def despawn_npc(npc_id) do
    case Registry.lookup(Alembic.Registry.NPCRegistry, npc_id) do
      [{pid, _}] ->
        DynamicSupervisor.terminate_child(__MODULE__, pid)
      [] ->
        {:error, :not_found}
    end
  end

  def list_npcs do
    DynamicSupervisor.which_children(__MODULE__)
    |> Enum.map(fn {_id, pid, _type, _modules} -> pid end)
    |> Enum.filter(&is_pid/1)
  end

  def count_npcs do
    case DynamicSupervisor.count_children(__MODULE__) do
      %{active: count} -> count
      _ -> 0
    end
  end
end
