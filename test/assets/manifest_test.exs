defmodule Alembic.Test.Assets.ManifestTest do
  use ExUnit.Case, async: false

  alias Alembic.Assets.Manifest

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp_dir} do
    # Create directory structure
    File.mkdir_p!(Path.join(tmp_dir, "tiles"))
    File.mkdir_p!(Path.join(tmp_dir, "sprites/characters"))
    File.mkdir_p!(Path.join(tmp_dir, "sprites/npcs/Enemies"))

    # Valid 32x32 PNG (2 columns, 2 rows at 16x16 cell size)
    valid_png = <<137, 80, 78, 71, 13, 10, 26, 10, 0::64, 32::32, 32::32>>

    File.write!(Path.join(tmp_dir, "tiles/Path_Tile.png"), valid_png)
    File.write!(Path.join(tmp_dir, "sprites/characters/Player.png"), valid_png)
    File.write!(Path.join(tmp_dir, "sprites/npcs/Enemies/Skeleton.png"), valid_png)

    Application.put_env(:alembic, :worlds_path, tmp_dir |> Path.dirname())
    world_id = tmp_dir |> Path.basename()

    on_exit(fn ->
      Application.delete_env(:alembic, :worlds_path)
    end)

    %{world_id: world_id, tmp_dir: tmp_dir}
  end

  def valid_meta do
    %{
      "tilesets" => [
        %{
          "id" => "Path_Tile",
          "file" => "tiles/Path_Tile.png",
          "tile_width" => 16,
          "tile_height" => 16,
          "tile_labels" => %{
            "grass" => [0, 0],
            "dirt" => [1, 0],
            "water" => [0, 1],
            "sand" => [1, 1]
          }
        }
      ],
      "sprite_sheets" => [
        %{
          "id" => "Player",
          "file" => "sprites/characters/Player.png",
          "cell_width" => 16,
          "cell_height" => 16
        }
      ],
      "npc_sheets" => [
        %{
          "id" => "Skeleton",
          "file" => "sprites/npcs/Enemies/Skeleton.png",
          "cell_width" => 16,
          "cell_height" => 16
        }
      ]
    }
  end

  describe "generate_manifest/1" do
    test "builds manifest successfully with valid meta", %{world_id: world_id, tmp_dir: tmp_dir} do
      File.write!(Path.join(tmp_dir, "asset_meta.json"), Jason.encode!(valid_meta()))

      assert {:ok, manifest_path} = Manifest.generate_manifest(world_id)
      assert File.exists?(manifest_path)

      manifest_content = File.read!(manifest_path) |> Jason.decode!()

      assert manifest_content["tilesets"] == [
               %{
                 "id" => "Path_Tile",
                 "filename" => "tiles/Path_Tile.png",
                 "url" => "/worlds/#{world_id}/assets/tiles/Path_Tile.png",
                 "image_width" => 32,
                 "image_height" => 32,
                 "columns" => 2,
                 "rows" => 2,
                 "tile_width" => 16,
                 "tile_height" => 16,
                 "tile_labels" => %{
                   "grass" => [0, 0],
                   "dirt" => [1, 0],
                   "water" => [0, 1],
                   "sand" => [1, 1]
                 }
               }
             ]

      assert manifest_content["spritesheets"] == [
               %{
                 "id" => "Player",
                 "filename" => "sprites/characters/Player.png",
                 "url" => "/worlds/#{world_id}/assets/sprites/characters/Player.png",
                 "image_width" => 32,
                 "image_height" => 32,
                 "columns" => 2,
                 "rows" => 2,
                 "cell_width" => 16,
                 "cell_height" => 16
               }
             ]

      assert manifest_content["npc_sprites"] == [
               %{
                 "id" => "Skeleton",
                 "filename" => "sprites/npcs/Enemies/Skeleton.png",
                 "url" => "/worlds/#{world_id}/assets/sprites/npcs/Enemies/Skeleton.png",
                 "image_width" => 32,
                 "image_height" => 32,
                 "columns" => 2,
                 "rows" => 2,
                 "cell_width" => 16,
                 "cell_height" => 16
               }
             ]
    end

    test "returns errors for invalid meta", %{world_id: world_id, tmp_dir: tmp_dir} do
      invalid_meta = %{
        "tilesets" => [
          %{
            "id" => "Invalid_Tile",
            "file" => "tiles/NonExistent.png",
            "tile_width" => 16,
            "tile_height" => 16
          }
        ],
        "sprite_sheets" => [],
        "npc_sheets" => []
      }

      File.write!(Path.join(tmp_dir, "asset_meta.json"), Jason.encode!(invalid_meta))

      assert {:error, errors} = Manifest.generate_manifest(world_id)
      assert :file_not_found in errors
    end

    test "returns error when asset_meta.json is missing", %{world_id: world_id} do
      assert {:error, errors} = Manifest.generate_manifest(world_id)
      assert {:file_read_error, :enoent} in errors
    end

    test "returns error when asset_meta.json is invalid JSON", %{
      world_id: world_id,
      tmp_dir: tmp_dir
    } do
      File.write!(Path.join(tmp_dir, "asset_meta.json"), "not valid json {{{")

      assert {:error, errors} = Manifest.generate_manifest(world_id)

      assert {:file_read_error,
              %Jason.DecodeError{
                position: 0,
                token: nil,
                data: "not valid json {{{"
              }} in errors

      assert length(errors) > 0
    end

    test "returns error when tileset file is missing", %{world_id: world_id, tmp_dir: tmp_dir} do
      meta = %{
        valid_meta()
        | "tilesets" => [
            %{
              "id" => "missing",
              "file" => "tiles/Missing.png",
              "tile_width" => 16,
              "tile_height" => 16
            }
          ]
      }

      File.write!(Path.join(tmp_dir, "asset_meta.json"), Jason.encode!(meta))

      assert {:error, errors} = Manifest.generate_manifest(world_id)
      assert :file_not_found in errors
    end

    test "returns error when spritesheet file is missing", %{world_id: world_id, tmp_dir: tmp_dir} do
      meta = %{
        valid_meta()
        | "sprite_sheets" => [
            %{
              "id" => "missing",
              "file" => "sprites/characters/Missing.png",
              "cell_width" => 16,
              "cell_height" => 16
            }
          ]
      }

      File.write!(Path.join(tmp_dir, "asset_meta.json"), Jason.encode!(meta))

      assert {:error, errors} = Manifest.generate_manifest(world_id)
      assert :file_not_found in errors
    end

    test "returns error when npc sheet file is missing", %{world_id: world_id, tmp_dir: tmp_dir} do
      meta = %{
        valid_meta()
        | "npc_sheets" => [
            %{
              "id" => "missing",
              "file" => "sprites/npcs/Missing.png",
              "cell_width" => 16,
              "cell_height" => 16
            }
          ]
      }

      File.write!(Path.join(tmp_dir, "asset_meta.json"), Jason.encode!(meta))

      assert {:error, errors} = Manifest.generate_manifest(world_id)
      assert :file_not_found in errors
    end

    test "returns error when tile_labels are invalid", %{world_id: world_id, tmp_dir: tmp_dir} do
      meta = %{
        valid_meta()
        | "tilesets" => [
            %{
              "id" => "Path_Tile",
              "file" => "tiles/Path_Tile.png",
              "tile_width" => 16,
              "tile_height" => 16,
              "tile_labels" => %{
                "grass" => [0, 0],
                "dirt" => [1, 0],
                "water" => [0, 1],
                "invalid_coords" => [2, 2]
              }
            }
          ]
      }

      File.write!(Path.join(tmp_dir, "asset_meta.json"), Jason.encode!(meta))

      assert {:error, errors} = Manifest.generate_manifest(world_id)

      assert {:invalid_tile_labels,
              [
                %{coords: [2, 2], file: "tiles/Path_Tile.png", label: "invalid_coords"}
              ]} in errors
    end
  end
end
