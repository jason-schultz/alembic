defmodule Alembic.World.SpawnPoint do
  @moduledoc """
  Static, immutable definition of a spawn point loaded from the database or JSON.
  This never changes at runtime — it describes the location and any conditions
  for spawning.
  """

  @type t :: %__MODULE__{
          id: String.t(),
          room_id: String.t(),
          x: integer(),
          y: integer(),
          world_x: integer(),
          world_y: integer(),
          facing: :north | :south | :east | :west,
          # nil = always available, or a condition tag like "requires_quest_1"
          condition: String.t() | nil
        }

  defstruct [:id, :room_id, :x, :y, :world_x, :world_y, :facing, condition: nil]

  def from_json(json) do
    %__MODULE__{
      id: json["id"],
      room_id: json["room_id"],
      x: json["x"],
      y: json["y"],
      world_x: json["world_x"],
      world_y: json["world_y"],
      facing: parse_facing(json["facing"]),
      condition: json["condition"]
    }
  end

  defp parse_facing(nil), do: :south
  defp parse_facing(facing) when is_binary(facing), do: String.to_atom(facing)
end
