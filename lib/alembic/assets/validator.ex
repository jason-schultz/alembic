defmodule Alembic.Assets.Validator do
  @moduledoc """
  Validates asset files (e.g. PNG images) for use in campaigns. Checks file extension, magic bytes, size, path safety, and dimensions.
  """

  @valid_extensions [".png"]

  @doc """
  Validates a file at the given path against multiple criteria:
  - Must exist
  - Must have a .png extension
  - Must have valid PNG magic bytes
  - Must be between 1 byte and 10 MB in size
  - Must not contain path traversal characters
  - Must have valid dimensions (width and height > 0 and <= 4096) as determined by reading the PNG header
  """
  @spec validate(String.t()) :: {:ok, String.t()} | {:error, atom}
  def validate(file_path) do
    with {:ok, file_path} <- check_path_traversal(file_path),
         {:ok, file_path} <- check_file_exists(file_path),
         {:ok, file_path} <- check_extension(file_path),
         {:ok, file_path} <- check_magic_bytes(file_path),
         {:ok, file_path} <- check_file_size(file_path),
         {:ok, file_path} <- check_dimensions(file_path) do
      {:ok, file_path}
    else
      {:error, error} -> {:error, error}
    end
  end

  defp check_file_exists(file_path) do
    case File.exists?(file_path) do
      true -> {:ok, file_path}
      false -> {:error, :file_not_found}
    end
  end

  @doc """
  Validates that animation labels are in the correct format and within bounds of the spritesheet dimensions.
  Expects labels to be a map where keys are label names and values are maps with keys :row, :frames, and optional :flip_x.
   - row must be an integer between 0 and rows-1
   - frames must be an integer between 1 and columns
    - flip_x must be a boolean if present
  """
  @spec validate_animation_labels(non_neg_integer(), non_neg_integer(), map) ::
          {:ok, map}
          | {:error, {:invalid_animation_labels, [%{label: String.t(), file: String.t()}]}}
  def validate_animation_labels(columns, rows, sheet_meta) when is_map(sheet_meta) do
    Map.get(sheet_meta, "animation_labels", %{})
    |> Enum.reduce({%{}, []}, fn {label, info}, {valid, errors} ->
      case validate_animation_label(label, info, columns, rows, sheet_meta) do
        {:ok, _} -> {Map.put(valid, label, info), errors}
        {:error, info} -> {valid, [info | errors]}
      end
    end)
    |> then(fn
      {valid, []} ->
        {:ok, valid}

      {_, bad} ->
        {:error, {:invalid_animation_labels, bad}}
    end)
  end

  def validate_animation_labels(_, _, _), do: {:ok, %{}}

  defp validate_animation_label(label, info, columns, rows, sheet_meta) do
    cond do
      not is_binary(label) ->
        {:error, %{label: label, file: sheet_meta["file"]}}

      not is_map(info) ->
        {:error, %{label: label, file: sheet_meta["file"]}}

      true ->
        row = Map.get(info, "row")
        frames = Map.get(info, "frames")
        flip_x = Map.get(info, "flip_x", false)

        cond do
          not is_integer(row) or row < 0 or row >= rows ->
            {:error, %{label: label, file: sheet_meta["file"]}}

          not is_integer(frames) or frames < 1 or frames > columns ->
            {:error, %{label: label, file: sheet_meta["file"]}}

          not is_boolean(flip_x) ->
            {:error, %{label: label, file: sheet_meta["file"]}}

          true ->
            {:ok, %{label => info}}
        end
    end
  end

  @doc """
  Validates that tile labels are in the correct format and within bounds of the tileset dimensions.
  Expects labels to be a map where keys are label names and values are [column, row] coordinates.
  """
  @spec validate_tile_labels(non_neg_integer, non_neg_integer, map) ::
          {:ok, map}
          | {:error,
             {:invalid_tile_labels, [%{label: String.t(), coords: [integer], file: String.t()}]}}
  def validate_tile_labels(columns, rows, tileset_meta) when is_map(tileset_meta) do
    Map.get(tileset_meta, "tile_labels", %{})
    |> Enum.reduce({%{}, []}, fn {label, coords}, {valid, errors} ->
      case validate_tile_label(label, coords, columns, rows, tileset_meta) do
        {:ok, _} -> {Map.put(valid, label, coords), errors}
        {:error, info} -> {valid, [info | errors]}
      end
    end)
    |> then(fn
      {valid, []} ->
        {:ok, valid}

      {_, bad} ->
        {:error, {:invalid_tile_labels, bad}}
    end)
  end

  def validate_tile_labels(_, _, _), do: {:ok, %{}}

  defp validate_tile_label(label, coords, columns, rows, tileset_meta) do
    cond do
      not is_binary(label) ->
        {:error, %{label: label, coords: coords, file: tileset_meta["file"]}}

      not is_list(coords) or length(coords) != 2 ->
        {:error, %{label: label, coords: coords, file: tileset_meta["file"]}}

      true ->
        case coords do
          [col, row] when is_integer(col) and is_integer(row) ->
            if col >= 0 and col < columns and row >= 0 and row < rows do
              {:ok, %{label => coords}}
            else
              {:error, %{label: label, coords: coords, file: tileset_meta["file"]}}
            end

          _ ->
            {:error, %{label: label, coords: coords, file: tileset_meta["file"]}}
        end
    end
  end

  defp check_extension(file_path) do
    if Path.extname(file_path) in @valid_extensions do
      {:ok, file_path}
    else
      {:error, :invalid_extension}
    end
  end

  defp check_magic_bytes(file_path) do
    case File.open(file_path, [:read, :binary], fn file -> IO.binread(file, 8) end) do
      {:ok, magic_bytes} ->
        if magic_bytes == <<137, 80, 78, 71, 13, 10, 26, 10>> do
          {:ok, file_path}
        else
          {:error, :invalid_magic_bytes}
        end

      {:error, _reason} ->
        {:error, :file_read_error}
    end
  end

  defp check_file_size(file_path) do
    case File.stat(file_path) do
      {:ok, %File.Stat{size: size}} when size > 0 and size <= 10_000_000 ->
        {:ok, file_path}

      {:ok, %File.Stat{size: size}} when size > 10_000_000 ->
        {:error, :file_too_large}

      {:ok, %File.Stat{size: 0}} ->
        {:error, :empty_file}

      {:error, _reason} ->
        {:error, :file_stat_error}
    end
  end

  defp check_path_traversal(file_path) do
    if String.contains?(file_path, "..") or
         String.contains?(file_path, "\\") or
         String.contains?(file_path, "\0") do
      {:error, :path_traversal_detected}
    else
      {:ok, file_path}
    end
  end

  defp check_dimensions(file_path) do
    case Alembic.Assets.Processor.image_dimensions(file_path) do
      {:ok, %{width: width, height: height}} ->
        if width > 0 and height > 0 and width <= 4096 and height <= 4096 do
          {:ok, file_path}
        else
          {:error, :invalid_dimensions}
        end

      {:error, _reason} ->
        {:error, :dimension_check_failed}
    end
  end
end
