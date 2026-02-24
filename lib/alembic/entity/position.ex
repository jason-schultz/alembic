defmodule Alembic.Entity.Position do
  @moduledoc """
  A struct to represent an entity's position in the world.
  """

  @direction [:north, :northeast, :east, :southeast, :south, :southwest, :west, :northwest]
  defstruct [
    # The ID of the current room the entity is in
    current_room_id: nil,
    # Additional position-related data can be added here
    # For example, coordinates within a room, if we want to support that later
    # x: 0,
    # y: 0,
    facing: @direction |> Enum.random()
  ]
end
