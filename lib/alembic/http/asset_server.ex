defmodule Alembic.Http.AssetServer do
  @moduledoc """
  HTTP server for world-scoped assets and manifests.

  Runs on port 8080 (configurable via :alembic, :asset_port).

  Routes:
    GET /worlds/:world_id/manifest     — unified asset manifest for a world
    GET /worlds/:world_id/assets/*path — serves asset files for a world
    GET /health                        — simple liveness check
  """

  use Plug.Router

  require Logger

  plug(Plug.Logger, log: :debug)
  plug(:match)
  plug(:dispatch)

  # ── Health check ────────────────────────────────────────────────────

  get "/health" do
    send_resp(conn, 200, "ok")
  end

  # ── World manifest ──────────────────────────────────────────────────

  get "/worlds/:world_id/manifest" do
    cond do
      not valid_world_id?(world_id) ->
        send_resp(conn, 404, "Not found")

      not Alembic.Campaign.CampaignManager.campaign_running?(world_id) ->
        send_resp(conn, 404, "Not found")

      true ->
        body =
          Jason.encode!(%{
            tiles: list_tiles(world_id),
            sprites: %{
              characters: list_character_sprites(world_id),
              npcs: list_npc_sprites(world_id)
            }
          })

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, body)
    end
  end

  # ── World asset serving ─────────────────────────────────────────────

  get "/worlds/:world_id/assets/*path" do
    cond do
      not valid_world_id?(world_id) ->
        send_resp(conn, 404, "Not found")

      not Alembic.Campaign.CampaignManager.campaign_running?(world_id) ->
        send_resp(conn, 404, "Not found")

      true ->
        base = world_manifest_path(world_id)
        file_path = Path.join([base | path])

        cond do
          not String.starts_with?(Path.expand(file_path), Path.expand(base)) ->
            send_resp(conn, 404, "Not found")

          Path.extname(file_path) not in [".png", ".jpg", ".jpeg"] ->
            send_resp(conn, 403, "Forbidden")

          not File.exists?(file_path) ->
            send_resp(conn, 404, "Not found")

          true ->
            conn
            |> put_resp_content_type(mime_type(file_path), nil)
            |> send_file(200, file_path)
        end
    end
  end

  # ── Fallback ────────────────────────────────────────────────────────

  match _ do
    send_resp(conn, 404, "Not found")
  end

  # ── Manifest helpers ─────────────────────────────────────────────────

  defp list_tiles(world_id) do
    dir = Path.join(world_manifest_path(world_id), "tiles")

    list_png_files(dir, fn filename ->
      %{id: Path.rootname(filename), file: "tiles/#{filename}"}
    end)
  end

  defp list_character_sprites(world_id) do
    dir = Path.join(world_manifest_path(world_id), "sprites/characters")

    list_png_files(dir, fn filename ->
      %{
        id: Path.rootname(filename),
        filename: filename,
        url: "/worlds/#{world_id}/assets/sprites/characters/#{filename}"
      }
    end)
  end

  defp list_npc_sprites(world_id) do
    dir = Path.join(world_manifest_path(world_id), "sprites/npcs")

    list_png_files(dir, fn filename ->
      %{id: Path.rootname(filename), file: "sprites/npcs/#{filename}"}
    end)
  end

  defp list_png_files(dir, mapper) do
    case File.ls(dir) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".png"))
        |> Enum.map(mapper)
        |> Enum.sort_by(& &1.id)

      {:error, reason} ->
        Logger.warning("Could not list files in #{dir}: #{inspect(reason)}")
        []
    end
  end

  defp worlds_base_path do
    Application.get_env(:alembic, :worlds_path, "priv/campaigns")
  end

  defp world_manifest_path(world_id) do
    Path.join([worlds_base_path(), world_id, "manifest"])
  end

  defp valid_world_id?(world_id) do
    not (String.contains?(world_id, "..") or
           String.contains?(world_id, "/") or
           String.contains?(world_id, "\\") or
           String.contains?(world_id, "\0"))
  end

  defp mime_type(path) do
    case Path.extname(path) do
      ".png" -> "image/png"
      ".jpg" -> "image/jpeg"
      ".jpeg" -> "image/jpeg"
      ".gif" -> "image/gif"
      ".webp" -> "image/webp"
      ".json" -> "application/json"
      _ -> "application/octet-stream"
    end
  end

  # ── Child spec for supervision tree ─────────────────────────────────

  def child_spec(_opts) do
    port = Application.get_env(:alembic, :asset_port, 8080)

    Logger.info("Asset HTTP server starting on port #{port}")

    %{
      id: __MODULE__,
      start: {Bandit, :start_link, [[plug: __MODULE__, port: port]]},
      type: :supervisor,
      restart: :permanent
    }
  end
end
