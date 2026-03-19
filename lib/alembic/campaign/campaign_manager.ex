defmodule Alembic.Campaign.CampaignManager do
  @moduledoc """
  Manages the lifecycle of campaigns on the server.

  Provides a high-level API for starting, stopping, and querying campaigns.
  Uses CampaignRegistry internally to track running World.Server instances.
  """

  alias Alembic.Supervisors.CampaignSupervisor
  alias Alembic.World.Server, as: WorldServer

  def start_campaign(campaign_id, opts \\ []) do
    case CampaignSupervisor.start_campaign(campaign_id, opts) do
      {:ok, _pid} -> {:ok, campaign_id}
      {:error, {:already_started, _pid}} -> {:error, :already_running}
      {:error, reason} -> {:error, reason}
    end
  end

  def stop_campaign(campaign_id) do
    case Registry.lookup(Alembic.Registry.CampaignRegistry, campaign_id) do
      [{pid, _}] ->
        CampaignSupervisor.stop_campaign(pid)

      [] ->
        {:error, :not_found}
    end
  end

  def list_campaigns do
    Registry.select(Alembic.Registry.CampaignRegistry, [{{:"$1", :_, :_}, [], [:"$1"]}])
  end

  def campaign_running?(campaign_id) do
    case Registry.lookup(Alembic.Registry.CampaignRegistry, campaign_id) do
      [{_pid, _}] -> true
      [] -> false
    end
  end

  def get_campaign_state(campaign_id) do
    if campaign_running?(campaign_id) do
      {:ok, WorldServer.get_state(campaign_id)}
    else
      {:error, :not_running}
    end
  end

  @doc """
  Returns world metadata for each running campaign, used to build the WORLD_LIST packet.
  Player count is not yet tracked per-world and is always 0.
  """
  def list_world_infos do
    list_campaigns()
    |> Enum.map(fn campaign_id ->
      state = WorldServer.get_state(campaign_id)

      %{
        world_id: campaign_id,
        world_name: state.name,
        description: state.description,
        player_count: 0
      }
    end)
  end

  @doc """
  Returns statistics about running campaigns.
  """
  def stats do
    %{
      total_campaigns: length(list_campaigns()),
      supervisor_counts: CampaignSupervisor.count_campaigns()
    }
  end
end
