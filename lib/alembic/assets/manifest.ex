defmodule Alembic.Assets.Manifest do
  @moduledoc """
  Generates a manifest for a world/campaign that describes the structure of the assets (tilesets, spritesheets) and provides the files for the client to load them.
  """

  @doc """
  Generates a manifest for the given world ID.
  Reads the asset_meta.json file which lists the tilesets and spritesheets, validates the files, and writes the manifest.json file for the client to read.
  The manifest.json file will look similar to the asset_meta.json file, but it will include some extra fields:
  - image_width
  - image_height
  - columns
  - rows
  """

  @spec generate_manifest(String.t()) :: {:ok, String.t()} | {:error, term}
  def generate_manifest(world_id) do
    with {:ok, meta} <- read_asset_meta(world_id),
         {:ok, manifest} <- build_manifest(world_id, meta),
         {:ok, manifest_path} <- write_manifest(world_id, manifest) do
      {:ok, manifest_path}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_manifest(world_id, meta) do
    {tilesets, tileset_errors} = build_tilesets(world_id, meta["tilesets"] || [])

    {spritesheets, spritesheet_errors} =
      build_sheets(
        world_id,
        meta["sprite_sheets"] || []
      )

    {npc_sheets, npc_sheet_errors} =
      build_sheets(world_id, meta["npc_sheets"] || [])

    if tileset_errors == [] and spritesheet_errors == [] and npc_sheet_errors == [] do
      manifest = %{
        tilesets: tilesets,
        spritesheets: spritesheets,
        npc_sprites: npc_sheets
      }

      {:ok, manifest}
    else
      {:error, tileset_errors ++ spritesheet_errors ++ npc_sheet_errors}
    end
  end

  defp build_sheets(world_id, sheets) do
    Enum.reduce(sheets, {[], []}, fn sheet_meta, {results, errors} ->
      case build_sheet_entry(world_id, sheet_meta) do
        {:ok, entry} -> {results ++ [entry], errors}
        {:error, reason} -> {results, errors ++ [reason]}
      end
    end)
  end

  defp build_sheet_entry(world_id, sheet_meta) do
    path = Path.join(world_manifest_path(world_id), sheet_meta["file"])

    with {:ok, path} <- Alembic.Assets.Validator.validate(path),
         {:ok, %{width: width, height: height}} <-
           Alembic.Assets.Processor.image_dimensions(path),
         {:ok, %{columns: columns, rows: rows}} <-
           Alembic.Assets.Processor.compute_grid(
             width,
             height,
             sheet_meta["cell_width"],
             sheet_meta["cell_height"]
           ) do
      entry = %{
        id: sheet_meta["id"],
        filename: sheet_meta["file"],
        url: "/worlds/#{world_id}/assets/#{sheet_meta["file"]}",
        image_width: width,
        image_height: height,
        columns: columns,
        rows: rows,
        cell_width: sheet_meta["cell_width"],
        cell_height: sheet_meta["cell_height"]
      }

      {:ok, entry}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_tilesets(world_id, tilesets) do
    Enum.reduce(tilesets, {[], []}, fn tileset_meta, {results, errors} ->
      case build_tileset_entry(world_id, tileset_meta) do
        {:ok, entry} -> {results ++ [entry], errors}
        {:error, reason} -> {results, errors ++ [reason]}
      end
    end)
  end

  defp build_tileset_entry(world_id, tileset_meta) do
    path = Path.join(world_manifest_path(world_id), tileset_meta["file"])

    with {:ok, path} <- Alembic.Assets.Validator.validate(path),
         {:ok, %{width: width, height: height}} <-
           Alembic.Assets.Processor.image_dimensions(path),
         {:ok, %{columns: columns, rows: rows}} <-
           Alembic.Assets.Processor.compute_grid(
             width,
             height,
             tileset_meta["tile_width"],
             tileset_meta["tile_height"]
           ),
         {:ok, labels} <-
           Alembic.Assets.Validator.validate_tile_labels(
             columns,
             rows,
             tileset_meta
           ) do
      entry = %{
        id: tileset_meta["id"],
        filename: tileset_meta["file"],
        url: "/worlds/#{world_id}/assets/#{tileset_meta["file"]}",
        image_width: width,
        image_height: height,
        columns: columns,
        rows: rows,
        tile_width: tileset_meta["tile_width"],
        tile_height: tileset_meta["tile_height"],
        tile_labels: labels
      }

      {:ok, entry}
    end
  end

  defp read_asset_meta(world_id) do
    path = Path.join(world_manifest_path(world_id), "asset_meta.json")

    with {:ok, content} <- File.read(path),
         {:ok, meta} <- Jason.decode(content) do
      {:ok, meta}
    else
      {:error, reason} -> {:error, [{:file_read_error, reason}]}
    end
  end

  defp world_manifest_path(world_id) do
    Application.get_env(:alembic, :worlds_path)
    |> Path.join(world_id)
  end

  defp write_manifest(world_id, manifest) do
    path = Path.join(world_manifest_path(world_id), "manifest.json")
    content = Jason.encode_to_iodata!(manifest)

    case File.write(path, content) do
      :ok -> {:ok, path}
      {:error, reason} -> {:error, {:file_write_error, reason}}
    end
  end
end
