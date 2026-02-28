defmodule Alembic.Entity.NPC do
  use Alembic.Entity.Base, registry: Alembic.Registry.NPCRegistry

  @moduledoc """
  A module for managing NPCs (non-player characters) in the Alembic world.

  This module provides functions for creating and managing NPCs,
  including their attributes, behaviors, dialogue, and interactions
  with players.
  """
  alias Alembic.Entity.{Attributes, Equipment, Position, Stats}

  @type npc_type :: :merchant | :quest_giver | :guard | :ambient | :trainer

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          type: npc_type(),
          position: Position.t(),
          stats: Stats.t(),
          attributes: Attributes.t(),
          equipment: Equipment.t() | nil,
          dialogue: list(String.t()),
          shop_inventory: list() | nil,
          schedule: map(),
          metadata: map()
        }

  defstruct [
    :id,
    :name,
    :position,
    :stats,
    :attributes,
    type: :ambient,
    equipment: nil,
    dialogue: [],
    shop_inventory: nil,
    schedule: %{},
    metadata: %{}
  ]

  @doc """
  Initializes a new NPC with the given attributes.
  ## Examples

      iex> position = Position.new("zone_town", 50, 30, 550, 530, :south)
      iex> NPC.init(%{id: "blacksmith_1", name: "Griswold", position: position, stats: %Stats{}})
      {:ok, %NPC{id: "blacksmith_1", name: "Griswold", type: :ambient, ...}}
  """
  def init(opts) do
    npc = %__MODULE__{
      id: Keyword.fetch!(opts, :id),
      name: Keyword.fetch!(opts, :name),
      position: Keyword.get(opts, :position),
      stats: Keyword.get(opts, :stats),
      attributes: Keyword.get(opts, :attributes),
      type: Keyword.get(opts, :type, :ambient),
      equipment: Keyword.get(opts, :equipment),
      dialogue: Keyword.get(opts, :dialogue),
      shop_inventory: Keyword.get(opts, :shop_inventory),
      schedule: Keyword.get(opts, :schedule),
      metadata: Keyword.get(opts, :metadata)
    }

    {:ok, npc}
  end

  @doc """
  Creates a new NPC with the given attributes.

  ## Examples

      iex> position = Position.new("zone_town", 50, 30, 550, 530, :south)
      iex> NPC.new("blacksmith_1", "Griswold", position, %Stats{})
      %NPC{id: "blacksmith_1", name: "Griswold", type: :ambient, ...}
  """
  def new(id, name, %Position{} = position, %Stats{} = stats, opts \\ []) do
    %__MODULE__{
      id: id,
      name: name,
      position: position,
      stats: stats,
      attributes: Keyword.get(opts, :attributes),
      type: Keyword.get(opts, :type, :ambient),
      equipment: Keyword.get(opts, :equipment),
      dialogue: Keyword.get(opts, :dialogue),
      shop_inventory: Keyword.get(opts, :shop_inventory),
      schedule: Keyword.get(opts, :schedule),
      metadata: Keyword.get(opts, :metadata)
    }
  end

  @doc """
  Moves the NPC in the given direction, updating both zone and world coordinates.
  Typically used for scheduled NPC movement (guard patrols, etc.).
  """
  def move(%__MODULE__{} = npc, direction) when direction in [:north, :south, :east, :west] do
    new_position = Position.move(npc.position, direction)
    %{npc | position: new_position}
  end

  @doc """
  Sets the NPC's position directly (for spawning, teleporting, schedule changes, etc.).
  """
  def set_position(%__MODULE__{} = npc, %Position{} = position) do
    %{npc | position: position}
  end

  @doc """
  Returns true if the NPC is a merchant with a shop inventory.
  """
  def merchant?(%__MODULE__{type: :merchant, shop_inventory: inventory}) when is_list(inventory),
    do: true

  def merchant?(%__MODULE__{}), do: false

  @doc """
  Returns true if the NPC can give quests.
  """
  def quest_giver?(%__MODULE__{type: :quest_giver}), do: true
  def quest_giver?(%__MODULE__{}), do: false

  @doc """
  Returns the NPC's current dialogue response.
  For now just returns the first dialogue line, but could be enhanced
  with dialogue trees, quest state checks, etc.
  """
  def get_dialogue(%__MODULE__{dialogue: [first | _rest]}), do: first
  def get_dialogue(%__MODULE__{}), do: "..."

  def validate_move(%__MODULE__{} = _npc, %Position{} = new_position) do
    # Placeholder for actual zone validation logic
    # In a real implementation, this would check with the Zone module to see if the tile is walkable
    if new_position.x >= 0 and new_position.y >= 0 do
      :ok
    else
      {:error, "Invalid move: coordinates must be non-negative"}
    end
  end
end
