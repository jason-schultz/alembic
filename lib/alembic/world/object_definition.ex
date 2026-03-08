defmodule Alembic.World.ObjectDefinition do
  @moduledoc """
  Static, immutable definition of an object loaded from the database or JSON.
  This never changes at runtime — it describes the type of object, its properties,
  and any special interactions.
  """

  @type t :: %__MODULE__{
          id: String.t(),
          asset_id: String.t(),
          x: integer(),
          y: integer(),

          # :chest, :door, :lever, :decoration
          type: atom(),
          state: map()
        }

  defstruct [:id, :asset_id, :x, :y, type: :decoration, state: %{}]

  def from_json(json) do
    %__MODULE__{
      id: json["id"],
      asset_id: json["asset_id"],
      x: json["x"],
      y: json["y"],
      type: String.to_atom(json["type"] || "decoration"),
      state: json["state"] || %{}
    }
  end
end
