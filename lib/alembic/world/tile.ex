defmodule Alembic.World.Tile do
  @moduledoc """
  Represents a single tile on a zone grid.

  Each tile has a position, texture information for the client to render,
  and server-side metadata like walkability and type.

  Tile size (32x32 or 64x64) is a client concern — the server only
  tracks logical grid coordinates.
  """

  @tile_types [
    :ground,
    :wall,
    :water,
    :door,
    :staircase,
    :void,
    :trap,
    :teleporter,
    :decorative,
    :hazard,
    :cover,
    :spawn_point,
    :interactive,
    :resource_node,
    :obstacle,
    :ladder,
    :bridge,
    :furniture,
    :container,
    :sign,
    :portal,
    :secret,
    :hidden,
    :breakable,
    :climbable,
    :slippery,
    :sticky,
    :flammable,
    :electrified,
    :poisonous,
    :magical,
    :corrupted
  ]

  @type tile_type ::
          :ground
          | :wall
          | :water
          | :door
          | :staircase
          | :void
          | :trap
          | :teleporter
          | :decorative
          | :hazard
          | :cover
          | :spawn_point
          | :interactive
          | :resource_node
          | :obstacle
          | :ladder
          | :bridge
          | :furniture
          | :container
          | :sign
          | :portal
          | :secret
          | :hidden
          | :breakable
          | :climbable
          | :slippery
          | :sticky
          | :flammable
          | :electrified
          | :poisonous
          | :magical
          | :corrupted

  @type t :: %__MODULE__{
          x: non_neg_integer(),
          y: non_neg_integer(),
          texture_id: String.t(),
          walkable: boolean(),
          type: tile_type(),
          interior: boolean(),
          elevation: non_neg_integer(),
          entity_id: String.t() | nil,
          metadata: map()
        }
  defstruct [
    :x,
    :y,
    :texture_id,
    walkable: true,
    type: :ground,
    interior: false,
    elevation: 0,
    entity_id: nil,
    metadata: %{}
  ]

  @doc """
  Creates a new tile with the given attributes.
  ## Examples

      iex> Tile.new(%{x: 0, y: 0, texture_id: "grass"})
      %Tile{x: 0, y: 0, texture_id: "grass", walkable: true, type: :ground}

      iex> Tile.new(%{x: 1, y: 1, texture_id: "water", walkable: false, type: :water})
      %Tile{x: 1, y: 1, texture_id: "water", walkable: false, type: :water}
  """
  @spec new(non_neg_integer(), non_neg_integer(), String.t(), keyword()) :: t()
  def new(x, y, texture_id, opts \\ []) do
    %__MODULE__{
      x: x,
      y: y,
      texture_id: texture_id,
      walkable: Keyword.get(opts, :walkable, true),
      type: Keyword.get(opts, :tile_type, :ground),
      interior: Keyword.get(opts, :interior, false),
      elevation: Keyword.get(opts, :elevation, 0),
      entity_id: Keyword.get(opts, :entity_id, nil),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  @doc """
  Returns true if the tile can be walked on by an entity.
  A tile is not walkable if it is a wall, water, lava, obstacle, or is occupied by an entity.
  """
  @spec walkable?(t()) :: boolean()
  def walkable?(%__MODULE__{walkable: false}), do: false
  def walkable?(%__MODULE__{entity_id: id}) when not is_nil(id), do: false

  def walkable?(%__MODULE__{type: type}) when type in [:wall, :water, :lava, :obstacle],
    do: false

  def walkable?(_), do: true

  @doc """
  Returns true if the tile is a transition point (door staircase, portal, ladder, etc).
  The client uses this to trigger a zone/room transition
  """
  @spec transition?(t()) :: boolean()
  def transition?(%__MODULE__{type: type})
      when type in [:door, :staircase, :portal, :ladder],
      do: true

  def transition?(_), do: false

  @doc """
  Places an entity on the tile, Returns an error if the tile is occupied.
  """
  @spec place_entity(t(), String.t()) :: {:ok, t()} | {:error, String.t()}
  def place_entity(%__MODULE__{entity_id: nil} = tile, entity_id) do
    {:ok, %{tile | entity_id: entity_id}}
  end

  def place_entity(%__MODULE__{entity_id: existing}, _entity_id) do
    {:error, "Tile is already occupied by entity #{existing}"}
  end

  @doc """
  Removes any entity from the tile.
  """
  @spec remove_entity(t()) :: t()
  def remove_entity(%__MODULE__{} = tile), do: %{tile | entity_id: nil}

  @doc """
  Returns true if the tile type is valid.
  """
  @spec valid_type?(atom()) :: boolean()
  def valid_type?(type), do: type in @tile_types
end
