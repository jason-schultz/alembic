defmodule Alembic.Supervisors.ConnectionSupervisor do
  @moduledoc """
  A DynamicSupervisor for managing ConnectionHandler processes.

  Each TCP connection gets its own ConnectionHandler GenServer.
  If a handler crashes, it's cleaned up without affecting other connections.
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
  Returns count of active connections.
  """
  def connection_count do
    case DynamicSupervisor.count_children(__MODULE__) do
      %{active: count} -> count
      _ -> 0
    end
  end
end
