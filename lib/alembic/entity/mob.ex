defmodule Alembic.Entity.Mob do
  use Alembic.Entity.Base, registry: Alembic.Registry.MobRegistry

  @moduledoc """
  A module for managing mobs (mobile entities) in the Alembic world.

  This module provides functions for creating and managing mobs,
  including their attributes, behaviors, and interactions with players
  and the environment.
  """
  alias Alembic.Entity.{Attributes, Equipment, Position, Stats}

  @type mob_type :: :aggressive | :passive | :neutral | :boss

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          type: mob_type(),
          position: Position.t(),
          stats: Stats.t(),
          attributes: Attributes.t(),
          equipment: Equipment.t() | nil,
          loot_table: list(),
          aggro_range: non_neg_integer(),
          respawn_time: non_neg_integer(),
          ai_state: atom(),
          metadata: map()
        }

  defstruct [
    :id,
    :name,
    :position,
    :stats,
    :attributes,
    type: :passive,
    equipment: nil,
    loot_table: [],
    aggro_range: 5,
    respawn_time: 30,
    ai_state: :idle,
    metadata: %{}
  ]

  @doc """
  Initializes a new mob with the given attributes.
  ## Examples

      iex> position = Position.new("zone_overworld", 10, 15, 10, 15, :south)
      iex> Mob.init(%{id: "skeleton_1", name: "Skeleton", position: position, stats: %Stats{}})
      {:ok, %Mob{id: "skeleton_1", name: "Skeleton", type: :passive, ...}}
  """
  def init(opts) do
    mob = %__MODULE__{
      id: Keyword.fetch!(opts, :id),
      name: Keyword.fetch!(opts, :name),
      position: Keyword.get(opts, :position),
      stats: Keyword.get(opts, :stats),
      attributes: Keyword.get(opts, :attributes),
      type: Keyword.get(opts, :type, :passive),
      equipment: Keyword.get(opts, :equipment),
      loot_table: Keyword.get(opts, :loot_table),
      aggro_range: Keyword.get(opts, :aggro_range),
      respawn_time: Keyword.get(opts, :respawn_time),
      ai_state: Keyword.get(opts, :ai_state, :idle),
      metadata: Keyword.get(opts, :metadata, %{})
    }

    {:ok, mob}
  end

  @doc """
  Creates a new mob with the given attributes.

  ## Examples

      iex> position = Position.new("zone_overworld", 10, 15, 10, 15, :south)
      iex> Mob.new("skeleton_1", "Skeleton", position, %Stats{})
      %Mob{id: "skeleton_1", name: "Skeleton", type: :passive, ...}
  """
  def new(id, name, %Position{} = position, %Stats{} = stats, opts \\ []) do
    %__MODULE__{
      id: id,
      name: name,
      position: position,
      stats: stats,
      attributes: Keyword.get(opts, :attributes),
      type: Keyword.get(opts, :type, :passive),
      equipment: Keyword.get(opts, :equipment),
      loot_table: Keyword.get(opts, :loot_table),
      aggro_range: Keyword.get(opts, :aggro_range),
      respawn_time: Keyword.get(opts, :respawn_time),
      ai_state: Keyword.get(opts, :ai_state),
      metadata: Keyword.get(opts, :metadata)
    }
  end

  @doc """
  Moves the mob in the given direction, updating both zone and world coordinates.
  """
  def move(%__MODULE__{} = mob, direction) when direction in [:north, :south, :east, :west] do
    new_position = Position.move(mob.position, direction)
    %{mob | position: new_position}
  end

  @doc """
  Sets the mob's position directly (for spawning, teleporting, etc.).
  """
  def set_position(%__MODULE__{} = mob, %Position{} = position) do
    %{mob | position: position}
  end

  @doc """
  Returns true if the mob is alive (hp > 0).
  """
  def alive?(%__MODULE__{stats: %Stats{hp: hp}}), do: hp > 0

  @doc """
  Returns true if the mob should aggro on a target at the given position.
  Only checks if target is within aggro range and mob is aggressive type.
  """
  def should_aggro?(
        %__MODULE__{type: :aggressive, aggro_range: range, position: mob_pos},
        target_pos
      ) do
    case Position.zone_distance(mob_pos, target_pos) do
      {:error, :different_zones} -> false
      distance -> distance <= range
    end
  end

  def should_aggro?(%__MODULE__{}, _target_pos), do: false

  def validate_move(%__MODULE__{} = _mob, %Position{} = new_position) do
    # Placeholder for actual zone validation logic
    # In a real implementation, this would check with the Zone module to see if the tile is walkable
    if new_position.x >= 0 and new_position.y >= 0 do
      :ok
    else
      {:error, "Invalid move: coordinates must be non-negative"}
    end
  end
end
