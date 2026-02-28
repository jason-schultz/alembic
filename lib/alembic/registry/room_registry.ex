defmodule Alembic.World.RoomRegistry do
  @moduledoc """
  A registry for managing room processes in the Alembic world.

  Provides convenience functions for looking up, listing, and managing
  room processes by their unique IDs.
  """
  use Alembic.Registry.Base, entity_name: :room
end
