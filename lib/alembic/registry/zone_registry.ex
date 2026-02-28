defmodule Alembic.Registry.ZoneRegistry do
  @moduledoc """
  A registry for managing zone processes in the Alembic world.

  Provides convenience functions for looking up, listing, and managing
  zone processes by their unique IDs.
  """
  use Alembic.Registry.Base, entity_name: :zone
end
