defmodule Alembic.Test.Support.Fixtures do
  alias Alembic.World.{Tile, Zone}

  def test_zone do
    tiles =
      for x <- 0..19, y <- 0..19, into: %{} do
        {{x, y}, %Tile{x: x, y: y, texture_id: "grass", walkable: true}}
      end

    %Zone{id: "test", name: "Test Zone", width: 20, height: 20, tiles: tiles}
  end
end
