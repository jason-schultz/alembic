defmodule Alembic.World.RoomDefinition do
  @moduledoc """
  Static, immutable definition of a room loaded from the database or JSON.
  This never changes at runtime — it describes the layout, tiles, exits, and
  initial NPC/object configuration.
  """

  alias Alembic.World.{TileDefinition, Exit, SpawnPoint, ObjectDefinition}

  @type t :: %__MODULE__{
          id: String.t(),
          zone_id: String.t(),
          name: String.t(),
          width: non_neg_integer(),
          height: non_neg_integer(),
          tiles: [[TileDefinition.t()]],
          exits: [Exit.t()],
          spawn_points: [SpawnPoint.t()],
          npc_templates: [map()],
          objects: [ObjectDefinition.t()]
        }

  defstruct [
    :id,
    :zone_id,
    :name,
    width: 16,
    height: 10,
    tiles: [],
    exits: [],
    spawn_points: [],
    npc_templates: [],
    objects: []
  ]

  def from_json(json) when is_map(json) do
    %__MODULE__{
      id: json["id"],
      zone_id: json["zone_id"],
      name: json["name"],
      width: json["width"],
      height: json["height"],
      tiles: Enum.map(json["tiles"], fn row -> Enum.map(row, &TileDefinition.from_json/1) end),
      exits: Enum.map(json["exits"], &Exit.from_json/1),
      spawn_points: Enum.map(json["spawn_points"], &SpawnPoint.from_json/1),
      npc_templates: json["npc_templates"] || [],
      objects: Enum.map(json["objects"] || [], &ObjectDefinition.from_json/1)
    }
  end

  defp parse_tiles(nil), do: []

  defp parse_tiles(rows),
    do: Enum.map(rows, fn row -> Enum.map(row, &TileDefinition.from_json/1) end)
end
