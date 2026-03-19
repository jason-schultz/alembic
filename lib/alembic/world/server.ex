defmodule Alembic.World.Server do
  @moduledoc """
  A GenServer that manages the entire game world state.

  The World Server is responsible for:
  - Loading and managing all zones and rooms
  - Coordinating zone transitions for players
  - Managing global world state (time, weather, world events)
  - Serving as the single source of truth for world topology

  ## Responsibilities

  **Zone Management:**
  - Loads zones from campaign data on startup
  - Starts Zone GenServers under the ZoneSupervisor
  - Tracks which zones are active/loaded
  - Manages zone lifecycle (load on demand, unload when empty)

  **Transition Coordination:**
  - Handles player movement between zones
  - Validates zone entrance/exit points
  - Manages room entry/exit (e.g., entering a tavern from the overworld)

  **World State:**
  - Tracks global time (day/night cycle)
  - Weather systems (rain, snow, fog)
  - World events (boss spawns, seasonal events)

  ## Architecture

  There is one World Server per campaign. It runs alongside all the Zone/Room
  GenServers and coordinates their interactions.

  ```
  Elixir Node
  ├── World.Server (campaign: "main")
  │   ├── Zone: overworld
  │   ├── Zone: dungeon_1
  │   └── Room: tavern_1
  │
  └── World.Server (campaign: "event_pvp")
      ├── Zone: arena
      └── Zone: staging_area
  ```
  """

  use GenServer
  require Logger

  alias Alembic.World.{Zone, Room}
  alias Alembic.Supervisors.{ZoneSupervisor, RoomSupervisor}

  @type world_time :: %{
          hour: 0..23,
          day: pos_integer(),
          season: :spring | :summer | :fall | :winter
        }

  @type weather :: :clear | :rain | :snow | :fog | :storm

  @type t :: %__MODULE__{
          campaign_id: String.t(),
          name: String.t(),
          description: String.t(),
          zones: %{String.t() => :loaded | :unloaded},
          rooms: %{String.t() => :loaded | :unloaded},
          zone_definitions: %{String.t() => Zone.t()},
          room_definitions: %{String.t() => Room.t()},
          world_time: world_time(),
          weather: weather(),
          active_events: list(String.t()),
          metadata: map()
        }

  defstruct [
    :campaign_id,
    :name,
    :description,
    zones: %{},
    rooms: %{},
    zone_definitions: %{},
    room_definitions: %{},
    world_time: %{hour: 12, day: 1, season: :spring},
    weather: :clear,
    active_events: [],
    metadata: %{}
  ]

  # Client API

  @doc """
  Starts the World Server for a campaign.
  Registered in CampaignRegistry so multiple campaigns can run simultaneously.
  """
  def start_link(opts) do
    campaign_id = Keyword.fetch!(opts, :campaign_id)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(campaign_id))
  end

  @doc """
  Returns the full world state.
  """
  def get_state(campaign_id) do
    GenServer.call(via_tuple(campaign_id), :get_state)
  end

  @doc """
  Loads a zone and starts its GenServer.
  Returns {:ok, zone_id} if successful, {:error, reason} otherwise.
  """
  def load_zone(campaign_id, zone_id) do
    GenServer.call(via_tuple(campaign_id), {:load_zone, zone_id})
  end

  @doc """
  Unloads a zone and stops its GenServer.
  Only allows unloading if the zone has no players.
  """
  def unload_zone(campaign_id, zone_id) do
    GenServer.call(via_tuple(campaign_id), {:unload_zone, zone_id})
  end

  @doc """
  Loads a room and starts its GenServer.
  """
  def load_room(campaign_id, room_id) do
    GenServer.call(via_tuple(campaign_id), {:load_room, room_id})
  end

  @doc """
  Unloads a room and stops its GenServer.
  """
  def unload_room(campaign_id, room_id) do
    GenServer.call(via_tuple(campaign_id), {:unload_room, room_id})
  end

  @doc """
  Transitions a player from one zone to another.
  Handles player_leave on old zone and player_enter on new zone.
  """
  def transition_player(campaign_id, player_id, from_zone_id, to_zone_id, to_x, to_y) do
    GenServer.call(
      via_tuple(campaign_id),
      {:transition_player, player_id, from_zone_id, to_zone_id, to_x, to_y}
    )
  end

  @doc """
  Transitions a player from a zone into a room.
  """
  def enter_room(campaign_id, player_id, from_zone_id, room_id, room_x, room_y) do
    GenServer.call(
      via_tuple(campaign_id),
      {:enter_room, player_id, from_zone_id, room_id, room_x, room_y}
    )
  end

  @doc """
  Transitions a player from a room back to a zone.
  """
  def exit_room(campaign_id, player_id, room_id, to_zone_id, to_x, to_y) do
    GenServer.call(
      via_tuple(campaign_id),
      {:exit_room, player_id, room_id, to_zone_id, to_x, to_y}
    )
  end

  @doc """
  Returns the current world time.
  """
  def get_world_time(campaign_id) do
    GenServer.call(via_tuple(campaign_id), :get_world_time)
  end

  @doc """
  Returns the current weather.
  """
  def get_weather(campaign_id) do
    GenServer.call(via_tuple(campaign_id), :get_weather)
  end

  @doc """
  Sets the weather (GM command).
  """
  def set_weather(campaign_id, weather) when weather in [:clear, :rain, :snow, :fog, :storm] do
    GenServer.cast(via_tuple(campaign_id), {:set_weather, weather})
  end

  @doc """
  Advances world time by one hour.
  Typically called on a timer (e.g., every 2 real minutes = 1 game hour).
  """
  def advance_time(campaign_id) do
    GenServer.cast(via_tuple(campaign_id), :advance_time)
  end

  @doc """
  Returns a list of all loaded zones.
  """
  def list_loaded_zones(campaign_id) do
    GenServer.call(via_tuple(campaign_id), :list_loaded_zones)
  end

  @doc """
  Returns a list of all loaded rooms.
  """
  def list_loaded_rooms(campaign_id) do
    GenServer.call(via_tuple(campaign_id), :list_loaded_rooms)
  end

  def get_spawn_position(campaign_id) do
    GenServer.call(via_tuple(campaign_id), :get_spawn_position)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    campaign_id = Keyword.fetch!(opts, :campaign_id)
    zones = Keyword.get(opts, :zones, [])
    rooms = Keyword.get(opts, :rooms, [])
    zone_definitions = Map.new(zones, fn zone -> {zone.id, zone} end)
    room_definitions = Map.new(rooms, fn room -> {room.id, room} end)

    Logger.info("World Server starting for campaign #{campaign_id}...")

    # Start all zones
    zone_status =
      Map.new(zones, fn zone ->
        case ZoneSupervisor.start_zone(zone) do
          {:ok, _pid} ->
            Logger.info("Zone #{zone.id} started")
            {zone.id, :loaded}

          {:error, reason} ->
            Logger.error("Failed to start zone #{zone.id}: #{inspect(reason)}")
            {zone.id, :unloaded}
        end
      end)

    # Start all rooms
    room_status =
      Map.new(rooms, fn room ->
        case RoomSupervisor.start_room(room) do
          {:ok, _pid} ->
            Logger.info("Room #{room.id} started")
            {room.id, :loaded}

          {:error, reason} ->
            Logger.error("Failed to start room #{room.id}: #{inspect(reason)}")
            {room.id, :unloaded}
        end
      end)

    state = %__MODULE__{
      campaign_id: campaign_id,
      name: Keyword.get(opts, :name, campaign_id),
      description: Keyword.get(opts, :description, ""),
      zones: zone_status,
      rooms: room_status,
      zone_definitions: zone_definitions,
      room_definitions: room_definitions,
      world_time: %{hour: 12, day: 1, season: :spring},
      weather: :clear,
      active_events: [],
      metadata: %{
        start_zone_id: Keyword.get(opts, :start_zone_id),
        start_x: Keyword.get(opts, :start_x, 0),
        start_y: Keyword.get(opts, :start_y, 0)
      }
    }

    schedule_time_tick()
    {:ok, state}
  end

  @impl true
  def handle_call(:get_spawn_position, _from, state) do
    position = %{
      zone_id: state.metadata.start_zone_id,
      x: state.metadata.start_x,
      y: state.metadata.start_y
    }

    {:reply, {:ok, position}, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:load_zone, zone_id}, _from, state) do
    case Map.get(state.zones, zone_id) do
      :loaded ->
        {:reply, {:ok, zone_id}, state}

      _ ->
        # pass state, not campaign_id
        case do_load_zone(zone_id, state) do
          :ok ->
            new_zones = Map.put(state.zones, zone_id, :loaded)
            {:reply, {:ok, zone_id}, %{state | zones: new_zones}}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
    end
  end

  @impl true
  def handle_call({:unload_zone, zone_id}, _from, state) do
    case Map.get(state.zones, zone_id) do
      :loaded ->
        # TODO: Check if zone has players before unloading
        case do_unload_zone(zone_id) do
          :ok ->
            new_zones = Map.put(state.zones, zone_id, :unloaded)
            Logger.info("Zone #{zone_id} unloaded successfully")
            {:reply, :ok, %{state | zones: new_zones}}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end

      _ ->
        {:reply, {:error, :zone_not_loaded}, state}
    end
  end

  @impl true
  def handle_call({:load_room, room_id}, _from, state) do
    case Map.get(state.rooms, room_id) do
      :loaded ->
        {:reply, {:ok, room_id}, state}

      _ ->
        # pass state, not campaign_id
        case do_load_room(room_id, state) do
          :ok ->
            new_rooms = Map.put(state.rooms, room_id, :loaded)
            {:reply, {:ok, room_id}, %{state | rooms: new_rooms}}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
    end
  end

  @impl true
  def handle_call({:unload_room, room_id}, _from, state) do
    case Map.get(state.rooms, room_id) do
      :loaded ->
        case do_unload_room(room_id) do
          :ok ->
            new_rooms = Map.delete(state.rooms, room_id)
            Logger.info("Room #{room_id} unloaded successfully")
            {:reply, :ok, %{state | rooms: new_rooms}}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end

      _ ->
        {:reply, {:error, :room_not_loaded}, state}
    end
  end

  @impl true
  def handle_call(
        {:transition_player, player_id, from_zone_id, to_zone_id, to_x, to_y},
        _from,
        state
      ) do
    with :ok <- ensure_zone_loaded(to_zone_id, state),
         :ok <- Zone.player_leave(from_zone_id, player_id),
         :ok <- Zone.player_enter(to_zone_id, player_id, to_x, to_y) do
      Logger.info("Player #{player_id} transitioned from #{from_zone_id} to #{to_zone_id}")
      {:reply, :ok, state}
    else
      {:error, reason} ->
        Logger.error("Failed to transition player #{player_id}: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:enter_room, player_id, from_zone_id, room_id, room_x, room_y}, _from, state) do
    with :ok <- ensure_room_loaded(room_id, state),
         :ok <- Zone.player_leave(from_zone_id, player_id),
         :ok <- Room.player_enter(room_id, player_id, room_x, room_y) do
      Logger.info("Player #{player_id} entered room #{room_id} from zone #{from_zone_id}")
      {:reply, :ok, state}
    else
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:exit_room, player_id, room_id, to_zone_id, to_x, to_y}, _from, state) do
    with :ok <- ensure_zone_loaded(to_zone_id, state),
         :ok <- Room.player_leave(room_id, player_id),
         :ok <- Zone.player_enter(to_zone_id, player_id, to_x, to_y) do
      Logger.info("Player #{player_id} exited room #{room_id} to zone #{to_zone_id}")
      {:reply, :ok, state}
    else
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:get_world_time, _from, state) do
    {:reply, state.world_time, state}
  end

  @impl true
  def handle_call(:get_weather, _from, state) do
    {:reply, state.weather, state}
  end

  @impl true
  def handle_call(:list_loaded_zones, _from, state) do
    loaded =
      state.zones
      |> Enum.filter(fn {_id, status} -> status == :loaded end)
      |> Enum.map(fn {id, _status} -> id end)

    {:reply, loaded, state}
  end

  @impl true
  def handle_call(:list_loaded_rooms, _from, state) do
    loaded =
      state.rooms
      |> Enum.filter(fn {_id, status} -> status == :loaded end)
      |> Enum.map(fn {id, _status} -> id end)

    {:reply, loaded, state}
  end

  @impl true
  def handle_cast({:set_weather, weather}, state) do
    Logger.info("Weather changed to #{weather}")
    {:noreply, %{state | weather: weather}}
  end

  @impl true
  def handle_cast(:advance_time, state) do
    new_time = advance_world_time(state.world_time)

    # Log day transitions
    if new_time.hour == 0 and state.world_time.hour == 23 do
      Logger.info("New day: Day #{new_time.day}, #{new_time.season}")
    end

    {:noreply, %{state | world_time: new_time}}
  end

  @impl true
  def handle_info({:load_zone_async, zone_id}, state) do
    case do_load_zone(zone_id, state.campaign_id) do
      :ok ->
        new_zones = Map.put(state.zones, zone_id, :loaded)
        Logger.info("Zone #{zone_id} loaded asynchronously")
        {:noreply, %{state | zones: new_zones}}

      {:error, reason} ->
        Logger.error("Failed to load zone #{zone_id}: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(:time_tick, state) do
    new_time = advance_world_time(state.world_time)
    schedule_time_tick()
    {:noreply, %{state | world_time: new_time}}
  end

  # Private Helpers

  defp via_tuple(campaign_id) do
    {:via, Registry, {Alembic.Registry.CampaignRegistry, campaign_id}}
  end

  defp schedule_time_tick do
    # Advance time every 2 minutes (120,000 ms)
    Process.send_after(self(), :time_tick, 120_000)
  end

  defp do_load_zone(zone_id, state) do
    case Map.get(state.zone_definitions, zone_id) do
      nil ->
        {:error, :zone_definition_not_found}

      %Zone{} = zone_data ->
        case ZoneSupervisor.start_zone(zone_data) do
          {:ok, _pid} -> :ok
          {:error, {:already_started, _pid}} -> :ok
          {:error, reason} -> {:error, reason}
        end
    end
  end

  defp do_unload_zone(zone_id) do
    case Registry.lookup(Alembic.Registry.ZoneRegistry, zone_id) do
      [{pid, _}] ->
        DynamicSupervisor.terminate_child(Alembic.Supervisors.ZoneSupervisor, pid)

      [] ->
        {:error, :not_found}
    end
  end

  defp do_load_room(room_id, state) do
    case Map.get(state.room_definitions, room_id) do
      nil ->
        {:error, :room_definition_not_found}

      %Room{} = room_data ->
        case RoomSupervisor.start_room(room_data) do
          {:ok, _pid} -> :ok
          {:error, {:already_started, _pid}} -> :ok
          {:error, reason} -> {:error, reason}
        end
    end
  end

  defp do_unload_room(room_id) do
    case Registry.lookup(Alembic.Registry.RoomRegistry, room_id) do
      [{pid, _}] ->
        DynamicSupervisor.terminate_child(Alembic.Supervisors.RoomSupervisor, pid)

      [] ->
        {:error, :not_found}
    end
  end

  defp ensure_zone_loaded(zone_id, state) do
    case Map.get(state.zones, zone_id) do
      :loaded -> :ok
      _ -> {:error, :zone_not_loaded}
    end
  end

  defp ensure_room_loaded(room_id, state) do
    case Map.get(state.rooms, room_id) do
      :loaded -> :ok
      _ -> {:error, :room_not_loaded}
    end
  end

  defp advance_world_time(%{hour: 23, day: day, season: season}) do
    %{hour: 0, day: day + 1, season: next_season(day + 1, season)}
  end

  defp advance_world_time(%{hour: hour, day: day, season: season}) do
    %{hour: hour + 1, day: day, season: season}
  end

  defp next_season(day, _current) when rem(day, 90) == 0 do
    # Change seasons every 90 days
    case div(day, 90) |> rem(4) do
      0 -> :spring
      1 -> :summer
      2 -> :fall
      3 -> :winter
    end
  end

  defp next_season(_day, current), do: current
end
