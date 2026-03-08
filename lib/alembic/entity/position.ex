defmodule Alembic.Entity.Position do
  @moduledoc """
  Represents an entity's position in the game world.

  Position has two coordinate systems:
  - **Zone-relative** (`x`, `y`) - position within the current zone grid (0-based)
  - **World-absolute** (`world_x`, `world_y`) - absolute position in the entire game world

  World coordinates are used for:
  - Cross-zone distance calculations
  - Positioning zones relative to each other
  - Minimap rendering
  - Zone transition logic

  Zone-relative coordinates are used for:
  - Viewport rendering (what tiles to send the client)
  - Tile walkability checks
  - Local entity interactions
  """

  @type facing :: :north | :south | :east | :west

  @type t :: %__MODULE__{
          zone_id: String.t(),
          room_id: String.t(),
          x: integer(),
          y: integer(),
          world_x: integer(),
          world_y: integer(),
          facing: facing()
        }

  defstruct [
    :zone_id,
    :room_id,
    :x,
    :y,
    :world_x,
    :world_y,
    facing: :south
  ]

  @doc """
  Creates a new position with both zone-relative and world-absolute coordinates.

  ## Examples

      iex> Position.new("zone_overworld", 50, 30, 5050, 3030)
      %Position{zone_id: "zone_overworld", x: 50, y: 30, world_x: 5050, world_y: 3030}
  """
  @spec new(
          String.t(),
          String.t(),
          integer(),
          integer(),
          integer(),
          integer(),
          facing()
        ) :: t()
  def new(zone_id, room_id, x, y, world_x, world_y, facing \\ :south) do
    %__MODULE__{
      zone_id: zone_id,
      room_id: room_id,
      x: x,
      y: y,
      world_x: world_x,
      world_y: world_y,
      facing: facing
    }
  end

  @doc """
  Creates a position from zone-relative coordinates only.
  World coordinates are calculated from the zone's world offset.

  This is a convenience function — the Zone knows its world offset.
  """
  @spec from_zone_coords(
          String.t(),
          String.t(),
          non_neg_integer(),
          non_neg_integer(),
          {non_neg_integer(), non_neg_integer()},
          facing()
        ) :: t()
  def from_zone_coords(zone_id, room_id, x, y, {zone_world_x, zone_world_y}, facing \\ :south) do
    %__MODULE__{
      zone_id: zone_id,
      room_id: room_id,
      x: x,
      y: y,
      world_x: zone_world_x + x,
      world_y: zone_world_y + y,
      facing: facing
    }
  end

  @doc """
  Returns the position after moving in the given direction.
  Updates both zone-relative and world-absolute coordinates.
  Does not validate walkability or zone boundaries.
  """
  @spec move(t(), facing()) :: t()
  def move(%__MODULE__{} = pos, :north) do
    %{pos | y: pos.y - 1, world_y: pos.world_y - 1, facing: :north}
  end

  def move(%__MODULE__{} = pos, :south) do
    %{pos | y: pos.y + 1, world_y: pos.world_y + 1, facing: :south}
  end

  def move(%__MODULE__{} = pos, :east) do
    %{pos | x: pos.x + 1, world_x: pos.world_x + 1, facing: :east}
  end

  def move(%__MODULE__{} = pos, :west) do
    %{pos | x: pos.x - 1, world_x: pos.world_x - 1, facing: :west}
  end

  @doc """
  Returns the Manhattan distance between two positions using world coordinates.
  Works across zones.
  """
  @spec world_distance(t(), t()) :: non_neg_integer()
  def world_distance(%__MODULE__{world_x: x1, world_y: y1}, %__MODULE__{world_x: x2, world_y: y2}) do
    abs(x1 - x2) + abs(y1 - y2)
  end

  @doc """
  Returns the Manhattan distance between two positions using zone-relative coordinates.
  Only valid if both positions are in the same zone.
  """
  @spec zone_distance(t(), t()) :: non_neg_integer() | {:error, :different_zones}
  def zone_distance(%__MODULE__{zone_id: z1}, %__MODULE__{zone_id: z2}) when z1 != z2 do
    {:error, :different_zones}
  end

  def zone_distance(%__MODULE__{x: x1, y: y1}, %__MODULE__{x: x2, y: y2}) do
    abs(x1 - x2) + abs(y1 - y2)
  end

  @doc """
  Returns true if the two positions are in the same zone.
  """
  @spec same_zone?(t(), t()) :: boolean()
  def same_zone?(%__MODULE__{zone_id: z1}, %__MODULE__{zone_id: z2}), do: z1 == z2

  @doc """
  Returns true if the position is adjacent (within 1 tile) of the target.
  Uses zone-relative distance if same zone, world distance otherwise.
  """
  @spec adjacent?(t(), t()) :: boolean()
  def adjacent?(pos1, pos2) do
    if same_zone?(pos1, pos2) do
      case zone_distance(pos1, pos2) do
        1 -> true
        _ -> false
      end
    else
      world_distance(pos1, pos2) == 1
    end
  end

  @doc """
  Returns true if the facing direction is valid.
  """
  @spec valid_facing?(atom()) :: boolean()
  def valid_facing?(facing) when facing in [:north, :south, :east, :west], do: true
  def valid_facing?(_), do: false
end
