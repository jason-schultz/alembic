defmodule Mix.Tasks.Alembic.Assets.Process do
  use Mix.Task

  @shortdoc "Processes assets for a world and generates the manifest"

  @moduledoc """
  Processes all assets for a given world and generates the manifest.json file.

  Usage:
      mix alembic.assets.process <world_id>
  """

  @impl Mix.Task
  def run(args) do
    Application.ensure_all_started(:alembic)

    case args do
      [world_id] ->
        case Alembic.Assets.Manifest.generate_manifest(world_id) do
          {:ok, manifest_path} ->
            IO.puts("Manifest generated successfully: #{manifest_path}")

          {:error, errors} ->
            IO.puts("Failed to generate manifest:")
            Enum.each(errors, &IO.puts("  - #{inspect(&1)}"))
            Mix.raise("Asset processing failed")
        end

      _ ->
        IO.puts("Usage: mix alembic.assets.process <world_id>")
        Mix.raise("Asset processing failed")
    end
  end
end
