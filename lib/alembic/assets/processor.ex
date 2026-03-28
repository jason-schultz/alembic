defmodule Alembic.Assets.Processor do
  @moduledoc """
  Processes sprite and tile assets for a world/campaign that will extract raw technical data from the source files,
  such as file width/height and then compute the columns and rows based off of the tile/cell size.
  """

  @doc """
  Given a file path to a PNG image, returns the width and height in pixels.
  Extracts this information from the PNG header without fully decoding the image.

  Returns {:ok, %{width: width, height: height}} on success or {:error, reason} on failure.
  """
  @spec image_dimensions(String.t()) ::
          {:ok, %{width: non_neg_integer, height: non_neg_integer}} | {:error, term}
  def image_dimensions(file_path) do
    with {:ok, data} <-
           File.open(file_path, [:binary, :read], fn file -> IO.binread(file, 24) end),
         <<137, 80, 78, 71, 13, 10, 26, 10, _::64, width::32, height::32>> <- data do
      {:ok, %{width: width, height: height}}
    else
      :eof ->
        {:error, {:invalid_png, "end of file reached prematurely", file_path}}

      {:error, reason} ->
        {:error, {:file_read_error, reason, file_path}}

      _ ->
        {:error, {:invalid_png, file_path}}
    end
  end

  @doc """
  Given the width and height of an image and the size of each cell, computes the number of columns and rows.
  """
  @spec compute_grid(non_neg_integer, non_neg_integer, non_neg_integer, non_neg_integer) ::
          {:ok, %{columns: non_neg_integer, rows: non_neg_integer}}
          | {:error, :invalid_dimensions}
  def compute_grid(width, height, cell_width, cell_height) do
    if rem(width, cell_width) == 0 and rem(height, cell_height) == 0 do
      {:ok, %{columns: div(width, cell_width), rows: div(height, cell_height)}}
    else
      {:error, :invalid_dimensions}
    end
  end
end
