defmodule Alembic.Application do
  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    children = [
      # Registries - must start first
      {Registry, keys: :unique, name: Alembic.Registry.PlayerRegistry},
      {Registry, keys: :unique, name: Alembic.Registry.MobRegistry},
      {Registry, keys: :unique, name: Alembic.Registry.NPCRegistry},
      {Registry, keys: :unique, name: Alembic.Registry.ZoneRegistry},
      {Registry, keys: :unique, name: Alembic.Registry.RoomRegistry},
      {Registry, keys: :unique, name: Alembic.Registry.CampaignRegistry},

      # Dynamic supervisors for entities
      Alembic.Supervisors.PlayerSupervisor,
      Alembic.Supervisors.MobSupervisor,
      Alembic.Supervisors.NPCSupervisor,
      Alembic.Supervisors.ZoneSupervisor,
      Alembic.Supervisors.RoomSupervisor,

      # Campaign supervisor with custom module
      Alembic.Supervisors.CampaignSupervisor,

      # HTTP Asset Server -- serves sprites/tilesets to clients
      Alembic.Http.AssetServer,

      # Network layer - Order matters!!!
      # ConnectionSupervisor must start BEFORE acceptor
      Alembic.Supervisors.ConnectionSupervisor,
      Alembic.Network.Acceptor
    ]

    opts = [strategy: :one_for_one, name: Alembic.Supervisor]
    {:ok, sup} = Supervisor.start_link(children, opts)

    # Load the default campaign after supervision tree is up
    case Alembic.Campaign.CampaignLoader.load("main_story") do
      {:ok, _} -> Logger.info("Main campaign loaded")
      {:error, reason} -> Logger.error("Failed to load campaign: #{inspect(reason)}")
    end

    {:ok, sup}
  end
end
