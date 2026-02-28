defmodule Alembic.Supervisors.CampaignSupervisor do
  @moduledoc """
  A DynamicSupervisor for managing World.Server processes (campaigns).

  Each campaign runs as a separate World.Server GenServer under this supervisor.
  This provides fault tolerance - if a campaign crashes, it can be restarted
  without affecting other campaigns.
  """

  use DynamicSupervisor

  alias Alembic.World.Server, as: WorldServer

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Starts a new campaign under this supervisor.

  ## Examples

      iex> CampaignSupervisor.start_campaign("main_story", zones: ["overworld"])
      {:ok, #PID<0.123.0>}
  """
  def start_campaign(campaign_id, opts \\ []) do
    world_opts = Keyword.put(opts, :campaign_id, campaign_id)

    child_spec = {WorldServer, world_opts}
    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end

  @doc """
  Stops a running campaign.
  """
  def stop_campaign(pid) when is_pid(pid) do
    DynamicSupervisor.terminate_child(__MODULE__, pid)
  end

  @doc """
  Returns a list of all campaign PIDs currently running under this supervisor.
  """
  def list_campaigns do
    DynamicSupervisor.which_children(__MODULE__)
    |> Enum.map(fn {_id, pid, _type, _modules} -> pid end)
    |> Enum.filter(&is_pid/1)
  end

  @doc """
  Returns the count of running campaigns.
  """
  def count_campaigns do
    DynamicSupervisor.count_children(__MODULE__).active
  end
end
