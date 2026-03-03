defmodule Alembic.Test.Support.Fixtures do
  alias Alembic.World.{Tile, Zone, Room}
  alias Alembic.Entity.{Player, Position, Stats, Equipment, Mob}

  # --- Tiles ---

  def walkable_tile(x, y, opts \\ []) do
    %Tile{
      x: x,
      y: y,
      texture_id: Keyword.get(opts, :texture_id, "grass"),
      walkable: true
    }
  end

  def blocked_tile(x, y, opts \\ []) do
    %Tile{
      x: x,
      y: y,
      texture_id: Keyword.get(opts, :texture_id, "wall"),
      walkable: false
    }
  end

  # --- Zone ---

  def test_zone(opts \\ []) do
    id = Keyword.get(opts, :id, "test_zone")
    width = Keyword.get(opts, :width, 20)
    height = Keyword.get(opts, :height, 20)

    tiles =
      for x <- 0..(width - 1), y <- 0..(height - 1), into: %{} do
        {{x, y}, walkable_tile(x, y)}
      end

    %Zone{
      id: id,
      name: Keyword.get(opts, :name, "Test Zone"),
      width: width,
      height: height,
      tiles: tiles
    }
  end

  # Zone with a wall border and a room_enter tile in the middle
  def test_zone_with_room_entrance(opts \\ []) do
    zone = test_zone(opts)

    entrance_tile = %Tile{
      x: 10,
      y: 10,
      texture_id: "door",
      walkable: true,
      room_enter: "test_room"
    }

    %{zone | tiles: Map.put(zone.tiles, {10, 10}, entrance_tile)}
  end

  # --- Room ---

  def test_room(opts \\ []) do
    id = Keyword.get(opts, :id, "test_room")
    width = Keyword.get(opts, :width, 16)
    height = Keyword.get(opts, :height, 10)

    tiles =
      for x <- 0..(width - 1), y <- 0..(height - 1), into: %{} do
        {{x, y}, walkable_tile(x, y)}
      end

    %Room{
      id: id,
      name: Keyword.get(opts, :name, "Test Room"),
      width: width,
      height: height,
      tiles: tiles,
      entrances: Keyword.get(opts, :entrances, [test_entrance()])
    }
  end

  def test_entrance(opts \\ []) do
    %{
      id: Keyword.get(opts, :id, "front_door"),
      room_x: Keyword.get(opts, :room_x, 8),
      room_y: Keyword.get(opts, :room_y, 9),
      leads_to_zone_id: Keyword.get(opts, :leads_to_zone_id, "test_zone"),
      leads_to_x: Keyword.get(opts, :leads_to_x, 10),
      leads_to_y: Keyword.get(opts, :leads_to_y, 11),
      requires_key: nil,
      one_way: false,
      metadata: %{}
    }
  end

  # --- Player ---

  def test_player(opts \\ []) do
    %Player{
      id: Keyword.get(opts, :id, "test_player"),
      name: Keyword.get(opts, :name, "Test Hero"),
      position: Keyword.get(opts, :position, test_position()),
      stats: Keyword.get(opts, :stats, base_stats()),
      equipment: Keyword.get(opts, :equipment, %Equipment{weapon_one: nil, weapon_two: nil}),
      inventory: [],
      skills: []
    }
  end

  def test_position(opts \\ []) do
    %Position{
      zone_id: Keyword.get(opts, :zone_id, "test_zone"),
      x: Keyword.get(opts, :x, 0),
      y: Keyword.get(opts, :y, 0),
      world_x: Keyword.get(opts, :world_x, 0),
      world_y: Keyword.get(opts, :world_y, 0)
    }
  end

  def base_stats(overrides \\ %{}) do
    Map.merge(
      %Stats{
        hp: 100,
        max_hp: 100,
        mp: 50,
        max_mp: 50,
        attack: 10,
        defense: 5,
        magic_defense: 5,
        speed: 10,
        critical_chance: 0.05,
        critical_multiplier: 1.5,
        dodge_chance: 0.05,
        accuracy: 0.95,
        resistances: %{
          fire: 3,
          ice: 3,
          lightning: 3,
          poison: 2,
          bleed: 2,
          stun: 2
        }
      },
      overrides
    )
  end

  def test_mob(opts \\ []) do
    %Mob{
      id: Keyword.get(opts, :id, "test_mob"),
      name: Keyword.get(opts, :name, "Test Mob"),
      stats: Keyword.get(opts, :stats, base_stats())
    }
  end

  def room_definition_json(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "tavern_main",
        "zone_id" => "town_millhaven",
        "name" => "The Rusty Flagon",
        "width" => 20,
        "height" => 15,
        "tiles" => [
          [
            %{"asset_id" => "floor_wood_01", "walkable" => true},
            %{"asset_id" => "wall_stone_01", "walkable" => false}
          ]
        ],
        "exits" => [
          %{
            "to_room_id" => "tavern_back",
            "to_spawn_point_id" => "back_entrance",
            "condition" => nil
          }
        ],
        "spawn_points" => [
          %{"id" => "default", "x" => 5, "y" => 5}
        ],
        "npc_templates" => [],
        "objects" => []
      },
      overrides
    )
  end
end
