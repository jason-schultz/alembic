defmodule Alembic.World.Exit do
  @moduledoc """
  Static, immutable definition of an exit loaded from the database or JSON.
  This never changes at runtime — it describes the destination room and any
  conditions for using the exit.
  """

  @type t :: %__MODULE__{
          to_room_id: String.t(),
          to_spawn_point_id: String.t(),
          # nil = always open, or a condition tag like "requires_key_dungeon_1"
          condition: String.t() | nil
        }

  defstruct [:to_room_id, :to_spawn_point_id, condition: nil]

  def from_json(json) do
    %__MODULE__{
      to_room_id: json["to_room_id"],
      to_spawn_point_id: json["to_spawn_point_id"],
      condition: json["condition"]
    }
  end
end
