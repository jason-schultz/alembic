defmodule Alembic.Entity.Player do
  use Alembic.Entity.Base, registry: Alembic.Registry.PlayerRegistry

  alias Alembic.Entity.{Equipment, Position}

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
    :session_id
  ]

  # Player-specific init
  @impl true
  def init(opts) do
    player = %__MODULE__{
      id: Keyword.fetch!(opts, :id),
      name: Keyword.fetch!(opts, :name),
      position: Keyword.get(opts, :position),
      stats: Keyword.get(opts, :stats),
      attributes: Keyword.get(opts, :attributes),
      equipment: Keyword.get(opts, :equipment),
      inventory: Keyword.get(opts, :inventory),
      skills: Keyword.get(opts, :skills),
      sprite_config: Keyword.get(opts, :sprite_config),
      session_id: Keyword.get(opts, :session_id)
    }

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
end
