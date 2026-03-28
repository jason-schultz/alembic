defmodule Alembic.Test.Assets.ValidatorTest do
  use ExUnit.Case, async: true

  alias Alembic.Assets.Validator

  @moduletag :tmp_dir

  describe "validate/1" do
    test "validates a correct PNG file", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "valid.png")
      File.write!(path, <<137, 80, 78, 71, 13, 10, 26, 10, 0::64, 16::32, 32::32>>)

      assert {:ok, ^path} = Validator.validate(path)
    end

    test "returns error for non-existent file", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "non_existent.png")
      assert {:error, :file_not_found} = Validator.validate(path)
    end

    test "returns error for invalid extension", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "invalid.txt")
      File.write!(path, "not a png")

      assert {:error, :invalid_extension} = Validator.validate(path)
    end

    test "returns error for invalid magic bytes", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "invalid_magic.png")
      File.write!(path, "not a png")

      assert {:error, :invalid_magic_bytes} = Validator.validate(path)
    end

    test "returns error for file too large", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "too_large.png")
      png_header = <<137, 80, 78, 71, 13, 10, 26, 10, 0::64, 16::32, 16::32>>
      padding = :binary.copy(<<0>>, 10_000_001 - byte_size(png_header))
      File.write!(path, png_header <> padding)

      #
      # File.write!(path, <<0::8>> |> :binary.copy(10_000_001))

      assert {:error, :file_too_large} = Validator.validate(path)
    end

    test "returns error for path traversal characters", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "../secret.png")
      assert {:error, :path_traversal_detected} = Validator.validate(path)
    end

    test "returns error for invalid dimensions", %{tmp_dir: tmp_dir} do
      # Create a valid PNG header but with invalid dimensions (e.g. width=0)
      path = Path.join(tmp_dir, "invalid_dimensions.png")
      png_header = <<137, 80, 78, 71, 13, 10, 26, 10>> <> <<0::64>>
      File.write!(path, png_header <> <<0::32>> <> <<0::32>>)

      assert {:error, :invalid_dimensions} = Validator.validate(path)
    end

    test "returns error for invalid dimensons (too large)", %{tmp_dir: tmp_dir} do
      # Create a valid PNG header but with dimensions that are too large (e.g. width=5000)
      path = Path.join(tmp_dir, "too_large_dimensions.png")
      png_header = <<137, 80, 78, 71, 13, 10, 26, 10>> <> <<0::64>>
      File.write!(path, png_header <> <<5000::32>> <> <<5000::32>>)

      assert {:error, :invalid_dimensions} = Validator.validate(path)
    end
  end

  describe "validate_tile_labels/3" do
    test "validates correct tile labels" do
      tileset_meta = %{
        "file" => "tileset.png",
        "tile_labels" => %{
          "grass" => [0, 0],
          "water" => [1, 0]
        }
      }

      assert {:ok, %{"grass" => [0, 0], "water" => [1, 0]}} =
               Validator.validate_tile_labels(2, 2, tileset_meta)
    end

    test "returns error for invalid tile label format" do
      tileset_meta = %{
        "file" => "tileset.png",
        "tile_labels" => %{
          # Invalid coords
          "grass" => [0],
          # Invalid label
          "123" => [1, 0]
        }
      }

      assert {:error,
              {:invalid_tile_labels, [%{label: "grass", file: "tileset.png", coords: [0]}]}} =
               Validator.validate_tile_labels(2, 2, tileset_meta)
    end

    test "returns error for out-of-bounds coordinates" do
      tileset_meta = %{
        "file" => "tileset.png",
        "tile_labels" => %{
          # Out of bounds
          "grass" => [2, 0],
          "water" => [1, 0]
        }
      }

      assert {:error,
              {:invalid_tile_labels, [%{label: "grass", file: "tileset.png", coords: [2, 0]}]}} =
               Validator.validate_tile_labels(2, 2, tileset_meta)
    end

    test "returns multiple errors for multiple invalid labels" do
      tileset_meta = %{
        "file" => "tileset.png",
        "tile_labels" => %{
          # Invalid coords
          "grass" => [0],
          # Out of bounds
          "water" => [2, 0]
        }
      }

      assert {:error,
              {:invalid_tile_labels,
               [
                 %{label: "water", file: "tileset.png", coords: [2, 0]},
                 %{label: "grass", file: "tileset.png", coords: [0]}
               ]}} = Validator.validate_tile_labels(2, 2, tileset_meta)
    end
  end
end
