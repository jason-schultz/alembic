# lib/alembic/entity/player_registry.ex
defmodule Alembic.Entity.PlayerRegistry do
  @moduledoc """
  A registry for managing player processes.
  """

  @registry_name Alembic.Entity.PlayerRegistry

  def lookup(player_id) do
    case Registry.lookup(@registry_name, player_id) do
      [{pid, _}] -> {:ok, pid}
      [] -> {:error, :not_found}
    end
  end

  def whereis(player_id) do
    case lookup(player_id) do
      {:ok, pid} -> pid
      {:error, :not_found} -> nil
    end
  end

  def exists?(player_id) do
    case lookup(player_id) do
      {:ok, _pid} -> true
      {:error, :not_found} -> false
    end
  end

  def list_player_ids do
    Registry.select(@registry_name, [{{:"$1", :_, :_}, [], [:"$1"]}])
  end

  def count do
    Registry.count(@registry_name)
  end

  def via_tuple(player_id) do
    {:via, Registry, {@registry_name, player_id}}
  end
end
