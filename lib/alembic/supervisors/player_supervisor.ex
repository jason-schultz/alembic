defmodule Alembic.Supervisors.PlayerSupervisor do
  @moduledoc """
  A DynamicSupervisor for managing Player GenServer processes.

  Each connected player runs as a separate Player GenServer under this supervisor.
  This provides fault tolerance - if a player process crashes, it can be restarted
  without affecting other players.

  ## Lifecycle
  - Player connects → `start_player/2` spawns a Player GenServer
  - Player disconnects → `stop_player/1` terminates the process
  - Player crashes → Supervisor can optionally restart (configure strategy)
  """

  use DynamicSupervisor
  require Logger

  alias Alembic.Entity.Player

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Starts a new player process under this supervisor.

  ## Options
  - `:id` - Unique player ID (required)
  - `:name` - Player character name (required)
  - `:session_id` - WebSocket session ID for linking
  - `:position` - Starting position (defaults to spawn point)
  - `:stats`, `:attributes`, `:equipment` - Character data

  ## Examples

      iex> PlayerSupervisor.start_player("player_123", name: "Aragorn")
      {:ok, #PID<0.123.0>}
  """
  def start_player(player_id, opts \\ []) do
    spec = %{
      id: player_id,
      start: {Player, :start_link, [opts]},
      restart: :temporary
    }

    case DynamicSupervisor.start_child(__MODULE__, spec) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      {:error, reason} -> {:error, reason}
    end
  end

  def reconnect_player(player_id, handler_pid) do
    case Registry.lookup(Alembic.Registry.PlayerRegistry, player_id) do
      [{pid, _}] ->
        Logger.debug(
          "PlayerSupervisor: reconnecting player #{player_id} with handler #{inspect(handler_pid)}"
        )

        case Alembic.Entity.Player.set_handler(player_id, handler_pid) do
          :ok -> {:ok, pid}
          {:error, reason} -> {:error, reason}
        end

      [] ->
        {:error, :not_found}
    end
  end

  @doc """
  Stops a player process.
  Typically called when a player disconnects or logs out.

  ## Examples

      iex> PlayerSupervisor.stop_player("player_123")
      :ok
  """
  def stop_player(player_id) do
    case Registry.lookup(Alembic.Registry.PlayerRegistry, player_id) do
      [{pid, _}] ->
        DynamicSupervisor.terminate_child(__MODULE__, pid)

      [] ->
        {:error, :not_found}
    end
  end

  @doc """
  Returns a list of all player PIDs currently running under this supervisor.
  """
  def list_players do
    DynamicSupervisor.which_children(__MODULE__)
    |> Enum.map(fn {_id, pid, _type, _modules} -> pid end)
    |> Enum.filter(&is_pid/1)
  end

  @doc """
  Returns the count of active players.
  """
  def count_players do
    case DynamicSupervisor.count_children(__MODULE__) do
      %{active: count} -> count
      _ -> 0
    end
  end

  @doc """
  Returns true if a player is currently running.
  """
  def player_running?(player_id) do
    case Registry.lookup(Alembic.Registry.PlayerRegistry, player_id) do
      [{_pid, _}] -> true
      [] -> false
    end
  end

  @doc """
  Returns statistics about the player supervisor.
  """
  def stats do
    children = DynamicSupervisor.count_children(__MODULE__)

    %{
      active: children.active,
      supervisors: children.supervisors,
      workers: children.workers
    }
  end
end
