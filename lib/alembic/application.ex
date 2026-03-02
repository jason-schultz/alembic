defmodule Alembic.Application do
  use Application

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

      # Campaign supervisor with custome module
      Alembic.Supervisors.CampaignSupervisor,

      # Network layer - Order matters!!!
      # ConnectionSupervisor must start BEFORE acceptor
      Alembic.Supervisors.ConnectionSupervisor,
      Alembic.Network.Acceptor
    ]

    opts = [strategy: :one_for_one, name: Alembic.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
