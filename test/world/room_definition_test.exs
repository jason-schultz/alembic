defmodule Alembic.Test.World.RoomDefinitionTest do
  use ExUnit.Case, async: true
  import Alembic.Test.Support.Fixtures

  alias Alembic.World.RoomDefinition

  @valid_json room_definition_json()

  describe "from_json/1" do
    test "parses all top level fields" do
      room = RoomDefinition.from_json(@valid_json)

      assert room.id == "tavern_main"
      assert room.zone_id == "town_millhaven"
      assert room.name == "The Rusty Flagon"
      assert room.width == 20
      assert room.height == 15
    end

    test "parses tiles as nested list" do
      room = RoomDefinition.from_json(@valid_json)

      assert length(room.tiles) == 1
      assert length(hd(room.tiles)) == 2
    end

    test "parses exits" do
      room = RoomDefinition.from_json(@valid_json)

      assert length(room.exits) == 1
      exit = hd(room.exits)
      assert exit.to_spawn_point_id != nil
      assert exit.to_room_id == "tavern_back"
    end

    test "parses spawn points" do
      room = RoomDefinition.from_json(@valid_json)

      assert length(room.spawn_points) == 1
      spawn = hd(room.spawn_points)
      assert spawn.x == 5
      assert spawn.y == 5
    end

    test "parses npc_templates as raw maps" do
      json =
        Map.put(@valid_json, "npc_templates", [
          %{"template_id" => "goblin", "spawn_point_id" => "default"}
        ])

      room = RoomDefinition.from_json(json)

      assert length(room.npc_templates) == 1
      assert hd(room.npc_templates)["template_id"] == "goblin"
    end

    test "handles missing objects field" do
      json = Map.delete(@valid_json, "objects")
      room = RoomDefinition.from_json(json)

      assert room.objects == []
    end

    test "handles missing npc_templates field" do
      json = Map.delete(@valid_json, "npc_templates")
      room = RoomDefinition.from_json(json)

      assert room.npc_templates == []
    end

    test "handles empty tiles" do
      json = Map.put(@valid_json, "tiles", [])
      room = RoomDefinition.from_json(json)

      assert room.tiles == []
    end

    test "handles empty exits" do
      json = Map.put(@valid_json, "exits", [])
      room = RoomDefinition.from_json(json)

      assert room.exits == []
    end
  end

  describe "struct defaults" do
    test "width defaults to 16" do
      assert %RoomDefinition{}.width == 16
    end

    test "height defaults to 10" do
      assert %RoomDefinition{}.height == 10
    end

    test "collections default to empty lists" do
      room = %RoomDefinition{}
      assert room.tiles == []
      assert room.exits == []
      assert room.spawn_points == []
      assert room.npc_templates == []
      assert room.objects == []
    end
  end
end
