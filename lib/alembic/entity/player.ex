defmodule Alembic.Entity.Player do
  use Alembic.Entity.Base, registry: Alembic.Registry.PlayerRegistry

  alias Alembic.Entity.{Attributes, Equipment, Position, Stats}

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          position: Position.t(),
          stats: Stats.t(),
          attributes: Attributes.t(),
          equipment: Equipment.t() | nil,
          inventory: list(),
          skills: list(),
          sprite_config: map(),
          session_id: String.t() | nil,
          handler_pid: pid() | nil
        }

  defstruct [
    :id,
    :name,
    :position,
    :stats,
    :attributes,
    :equipment,
    :inventory,
    :skills,
    :sprite_config,
    :session_id,
    :handler_pid
  ]

  # Player-specific init
  @impl true
  def init(opts) do
    player = %__MODULE__{
      id: Keyword.fetch!(opts, :id),
      name: Keyword.get(opts, :name, "Unnamed Hero"),
      position: Keyword.get(opts, :position),
      stats: Keyword.get(opts, :stats),
      attributes: Keyword.get(opts, :attributes),
      equipment: Keyword.get(opts, :equipment),
      inventory: Keyword.get(opts, :inventory),
      skills: Keyword.get(opts, :skills),
      sprite_config: Keyword.get(opts, :sprite_config),
      session_id: Keyword.get(opts, :session_id),
      handler_pid: Keyword.get(opts, :handler_pid)
    }

    Logger.info(
      "Player #{player.name} (#{player.id}) initialized, handler: #{inspect(player.handler_pid)}"
    )

    {:ok, player}
  end

  # Player-specific validation (overrides base)
  defp validate_move(_state, %Position{} = position) do
    # TODO: Check with Zone
    if position.x >= 0 and position.y >= 0 do
      :ok
    else
      {:error, "Invalid coordinates"}
    end
  end

  # Player-specific functions
  def equip_item(player_id, slot, item) do
    GenServer.call(via_tuple(player_id), {:equip_item, slot, item})
  end

  def add_to_inventory(player_id, item) do
    GenServer.call(via_tuple(player_id), {:add_to_inventory, item})
  end

  def get_handler(player_id) do
    case Registry.lookup(Alembic.Registry.PlayerRegistry, player_id) do
      [{pid, _}] ->
        GenServer.call(pid, :get_handler)

      [] ->
        {:error, :not_found}
    end
  end

  def set_handler(player_id, nil) do
    Logger.debug("set_handler called - player_id: #{player_id}, handler_pid: nil")

    case Registry.lookup(Alembic.Registry.PlayerRegistry, player_id) do
      [{pid, _}] -> GenServer.call(pid, {:set_handler, nil})
      [] -> {:error, :not_found}
    end
  end

  def set_handler(player_id, handler_pid) when is_pid(handler_pid) do
    Logger.debug(
      "set_handler called - player_id: #{player_id}, handler_pid: #{inspect(handler_pid)}"
    )

    case Registry.lookup(Alembic.Registry.PlayerRegistry, player_id) do
      [{pid, _}] ->
        Logger.debug("set_handler found player pid: #{inspect(pid)}, calling GenServer")
        GenServer.call(pid, {:set_handler, handler_pid})

      [] ->
        Logger.error("set_handler - player not found: #{player_id}")
        {:error, :not_found}
    end
  end

  def disconnect(player_id) do
    case Registry.lookup(Alembic.Registry.PlayerRegistry, player_id) do
      [{pid, _}] ->
        GenServer.stop(pid, :normal)

      [] ->
        Logger.warning("Attempted to disconnect non-existent player #{player_id}")
        :ok
    end
  end

  @impl true
  def handle_call(:get_handler, _from, state) do
    {:reply, {:ok, state.handler_pid}, state}
  end

  @impl true
  def handle_call({:set_handler, new_handler_pid}, _from, state) do
    Logger.info(
      "Player #{state.id} handler updated: #{inspect(state.handler_pid)} -> #{inspect(new_handler_pid)}"
    )

    {:reply, :ok, %{state | handler_pid: new_handler_pid}}
  end

  @impl true
  def handle_call({:equip_item, slot, item}, _from, state) do
    new_equipment = Equipment.equip(state.equipment, slot, item)
    new_state = %{state | equipment: new_equipment}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:add_to_inventory, item}, _from, state) do
    new_inventory = [item | state.inventory]
    new_state = %{state | inventory: new_inventory}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:move, _facing}, _from, state) do
    Logger.warning("Player #{state.id} attempted to move, but has no current position")
    {:reply, {:error, :no_position}, state}
  end

  @impl true
  def handle_call({:move, facing}, _from, state) do
    new_position = Position.move(state.position, facing)
    {:reply, :ok, %{state | position: new_position}}
  end

  @impl true
  def handle_info({:send_to_client, payload}, state) do
    send(state.handler_pid, {:send_packet, payload})
    {:noreply, state}
  end
end
