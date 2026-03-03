defmodule Alembic.World.TileDefinition do
  @moduledoc """
  Static, immutable definition of a tile loaded from the database or JSON.
  This never changes at runtime — it describes the type of tile, its properties,
  and any special interactions.
  """

  @type t :: %__MODULE__{
          asset_id: String.t(),
          walkable: boolean(),
          exit: Alembic.World.Exit.t() | nil
        }

  defstruct [:asset_id, walkable: true, exit: nil]

  def from_json(json) do
    %__MODULE__{
      asset_id: json["asset_id"],
      walkable: Map.get(json, "walkable", true),
      exit: json["exit"] && Alembic.World.Exit.from_json(json["exit"])
    }
  end
end
