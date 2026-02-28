defmodule Alembic.Supervisors.ZoneSupervisor do
  @moduledoc """
  A DynamicSupervisor for managing Zone GenServer processes.

  Each zone (overworld, dungeon, town, etc.) runs as a separate Zone GenServer
  under this supervisor. Zones are loaded/unloaded dynamically based on player
  activity and world server commands.

  ## Lifecycle
  - World.Server decides to load zone → `start_zone/1` spawns a Zone GenServer
  - Zone becomes empty → World.Server can `stop_zone/1` to free memory
  - Zone crashes → Supervisor restarts it (players may need to reconnect)

  ## Zone Loading Strategy
  Common patterns:
  - **Always loaded**: Spawn zones, main towns (loaded at campaign start)
  - **On-demand**: Dungeons, remote areas (loaded when first player enters)
  - **Timed unload**: Empty zones unload after 5 minutes of inactivity
  """

  use DynamicSupervisor

  alias Alembic.World.Zone

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Starts a new zone under this supervisor.

  The zone_data should be a fully constructed %Zone{} struct with:
  - `:id` - Unique zone identifier
  - `:name` - Human-readable zone name
  - `:width`, `:height` - Zone dimensions
  - `:tiles` - Map of {x, y} => Tile structs
  - `:type` - Zone type (:overworld, :dungeon, etc.)

  ## Examples

      iex> zone = %Zone{id: "zone_overworld", name: "The Overworld", ...}
      iex> ZoneSupervisor.start_zone(zone)
      {:ok, #PID<0.789.0>}
  """
  def start_zone(%Zone{} = zone_data) do
    child_spec = {Zone, zone_data}

    case DynamicSupervisor.start_child(__MODULE__, child_spec) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Stops a zone process.
  Should only be called when the zone is empty (no players).

  ## Examples

      iex> ZoneSupervisor.stop_zone("zone_dungeon_1")
      :ok
  """
  def stop_zone(zone_id) do
    case Registry.lookup(Alembic.Registry.ZoneRegistry, zone_id) do
      [{pid, _}] ->
        DynamicSupervisor.terminate_child(__MODULE__, pid)

      [] ->
        {:error, :not_found}
    end
  end

  @doc """
  Returns a list of all zone PIDs currently running.
  """
  def list_zones do
    DynamicSupervisor.which_children(__MODULE__)
    |> Enum.map(fn {_id, pid, _type, _modules} -> pid end)
    |> Enum.filter(&is_pid/1)
  end

  @doc """
  Returns the count of active zones.
  """
  def count_zones do
    case DynamicSupervisor.count_children(__MODULE__) do
      %{active: count} -> count
      _ -> 0
    end
  end

  @doc """
  Returns true if a zone is currently loaded.
  """
  def zone_loaded?(zone_id) do
    case Registry.lookup(Alembic.Registry.ZoneRegistry, zone_id) do
      [{_pid, _}] -> true
      [] -> false
    end
  end

  @doc """
  Returns statistics about the zone supervisor.
  """
  def stats do
    children = DynamicSupervisor.count_children(__MODULE__)

    %{
      active: children.active,
      supervisors: children.supervisors,
      workers: children.workers
    }
  end

  @doc """
  Reloads a zone (stops and restarts it).
  Useful for applying zone updates or fixing corrupted state.
  Players will be disconnected from the zone.

  ## Examples

      iex> ZoneSupervisor.reload_zone("zone_dungeon_1", new_zone_data)
      {:ok, #PID<0.999.0>}
  """
  def reload_zone(zone_id, new_zone_data) do
    with :ok <- stop_zone(zone_id),
         {:ok, pid} <- start_zone(new_zone_data) do
      {:ok, pid}
    else
      {:error, :not_found} ->
        # Zone wasn't loaded, just start it
        start_zone(new_zone_data)

      {:error, reason} ->
        {:error, reason}
    end
  end
end
