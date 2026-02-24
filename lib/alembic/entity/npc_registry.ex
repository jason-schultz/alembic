defmodule Alembic.Entity.NPCRegistry do
  @moduledoc """
  A registry for managing NPC processes.
  """

  @registry_name Alembic.Entity.NPCRegistry

  def registry_name, do: @registry_name

  def lookup(npc_id) do
    case Registry.lookup(@registry_name, npc_id) do
      [{pid, _}] -> {:ok, pid}
      [] -> {:error, :not_found}
    end
  end

  def whereis(npc_id) do
    case lookup(npc_id) do
      {:ok, pid} -> pid
      {:error, :not_found} -> nil
    end
  end

  def exists?(npc_id) do
    case lookup(npc_id) do
      {:ok, _pid} -> true
      {:error, :not_found} -> false
    end
  end

  def list_npc_ids do
    Registry.select(@registry_name, [{{:"$1", :_, :_}, [], [:"$1"]}])
  end

  def list_npc_pids do
    Registry.select(@registry_name, [{{:_, :"$1", :_}, [], [:"$1"]}])
  end

  def count do
    Registry.count(@registry_name)
  end

  def via_tuple(npc_id) do
    {:via, Registry, {@registry_name, npc_id}}
  end
end
