defmodule Alembic.World.RoomRegistry do
  @moduledoc """
  A registry for managing room processes in the Alembic world.

  Provides convenience functions for looking up, listing, and managing
  room processes by their unique IDs.
  """

  @registry_name Alembic.World.RoomRegistry

  @doc """
  Returns the name of the registry.
  """
  def registry_name, do: @registry_name

  @doc """
  Looks up a room by its ID.

  Returns `{:ok, pid}` if the room exists, `{:error, :not_found}` otherwise.

  ## Examples

      iex> RoomRegistry.lookup("tavern")
      {:ok, #PID<0.123.0>}

      iex> RoomRegistry.lookup("nonexistent")
      {:error, :not_found}
  """
  def lookup(room_id) do
    case Registry.lookup(@registry_name, room_id) do
      [{pid, _}] -> {:ok, pid}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Looks up a room by its ID and returns the PID directly.

  Returns the PID if found, `nil` otherwise.

  ## Examples

      iex> RoomRegistry.whereis("tavern")
      #PID<0.123.0>

      iex> RoomRegistry.whereis("nonexistent")
      nil
  """
  def whereis(room_id) do
    case lookup(room_id) do
      {:ok, pid} -> pid
      {:error, :not_found} -> nil
    end
  end

  @doc """
  Checks if a room with the given ID exists.

  ## Examples

      iex> RoomRegistry.exists?("tavern")
      true

      iex> RoomRegistry.exists?("nonexistent")
      false
  """
  def exists?(room_id) do
    case lookup(room_id) do
      {:ok, _pid} -> true
      {:error, :not_found} -> false
    end
  end

  @doc """
  Lists all registered room IDs.

  ## Examples

      iex> RoomRegistry.list_room_ids()
      ["tavern", "forest", "dungeon"]
  """
  def list_room_ids do
    Registry.select(@registry_name, [{{:"$1", :_, :_}, [], [:"$1"]}])
  end

  @doc """
  Lists all room PIDs.

  ## Examples

      iex> RoomRegistry.list_room_pids()
      [#PID<0.123.0>, #PID<0.124.0>, #PID<0.125.0>]
  """
  def list_room_pids do
    Registry.select(@registry_name, [{{:_, :"$1", :_}, [], [:"$1"]}])
  end

  @doc """
  Returns the count of registered rooms.

  ## Examples

      iex> RoomRegistry.count()
      3
  """
  def count do
    Registry.count(@registry_name)
  end

  @doc """
  Returns a via tuple for the given room ID.

  This is useful for GenServer calls when you need to reference a room.

  ## Examples

      iex> RoomRegistry.via_tuple("tavern")
      {:via, Registry, {Alembic.World.RoomRegistry, "tavern"}}
  """
  def via_tuple(room_id) do
    {:via, Registry, {@registry_name, room_id}}
  end
end
