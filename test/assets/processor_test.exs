defmodule Alembic.Test.Assets.ProcessorTest do
  use ExUnit.Case, async: true

  alias Alembic.Assets.Processor

  @moduletag :tmp_dir

  describe "image_dimensions/1" do
    test "processes PNG file correctly", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "test.png")
      File.write!(path, <<137, 80, 78, 71, 13, 10, 26, 10, 0::64, 16::32, 32::32>>)

      assert {:ok, %{width: 16, height: 32}} = Processor.image_dimensions(path)
    end

    test "returns error for invalid PNG file", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "invalid.png")
      File.write!(path, "not a png")

      assert {:error, {:invalid_png, ^path}} = Processor.image_dimensions(path)
    end

    test "returns error for non-existent file" do
      assert {:error, {:file_read_error, :enoent, _}} =
               Processor.image_dimensions("non_existent_file.png")
    end

    test "returns error for PNG with insufficient header data", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "short.png")
      File.write!(path, <<137, 80, 78>>)

      assert {:error, {:invalid_png, ^path}} = Processor.image_dimensions(path)
    end
  end

  describe "compute_grid/4" do
    test "computes grid correctly for valid dimensions" do
      assert {:ok, %{columns: 4, rows: 2}} = Processor.compute_grid(64, 32, 16, 16)
    end

    test "returns error for invalid dimensions" do
      assert {:error, :invalid_dimensions} = Processor.compute_grid(65, 32, 16, 16)
      assert {:error, :invalid_dimensions} = Processor.compute_grid(64, 33, 16, 16)
    end
  end
end
