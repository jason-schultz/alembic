defmodule Alembic.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Starts a worker by calling: Alembic.Worker.start_link(arg)
      # {Alembic.Worker, arg}
      {Registry, keys: :unique, name: Alembic.Entity.PlayerRegistry},
      {Registry, keys: :unique, name: Alembic.Entity.NPCRegistry},
      {Registry, keys: :unique, name: Alembic.World.RoomRegistry},
      Alembic.Supervisors.GameSupervisor
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Alembic.Supervisor]

    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        # Initialize the world afeter supervisor starts
        Alembic.World.WorldBuilder.setup_world()
        {:ok, pid}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
