defmodule Alembic.Http.AssetServerTest do
  use ExUnit.Case, async: false
  import Plug.Test
  import Plug.Conn

  alias Alembic.Http.AssetServer

  @world_id "test_world"
  @opts AssetServer.init([])

  setup_all do
    unless Process.whereis(Alembic.Registry.CampaignRegistry) do
      start_supervised!({Registry, keys: :unique, name: Alembic.Registry.CampaignRegistry})
    end

    :ok
  end

  setup do
    tmp_dir = Path.join(System.tmp_dir!(), "alembic_test_#{System.unique_integer([:positive])}")

    for dir <- [
          Path.join([tmp_dir, @world_id, "manifest", "tiles"]),
          Path.join([tmp_dir, @world_id, "manifest", "sprites", "characters"]),
          Path.join([tmp_dir, @world_id, "manifest", "sprites", "npcs"])
        ] do
      File.mkdir_p!(dir)
    end

    # PNG signature bytes — content doesn't matter for these tests, but recognisable
    png_header = <<137, 80, 78, 71, 13, 10, 26, 10>>

    for file <- [
          Path.join([tmp_dir, @world_id, "manifest", "tiles", "grass_01.png"]),
          Path.join([tmp_dir, @world_id, "manifest", "tiles", "water_01.png"]),
          Path.join([tmp_dir, @world_id, "manifest", "sprites", "characters", "Male_White.png"]),
          Path.join([tmp_dir, @world_id, "manifest", "sprites", "characters", "Female_Dark.png"]),
          Path.join([tmp_dir, @world_id, "manifest", "sprites", "npcs", "merchant_01.png"])
        ] do
      File.write!(file, png_header)
    end

    original_path = Application.get_env(:alembic, :worlds_path)
    Application.put_env(:alembic, :worlds_path, tmp_dir)

    {:ok, _} = Registry.register(Alembic.Registry.CampaignRegistry, @world_id, %{})

    on_exit(fn ->
      File.rm_rf!(tmp_dir)

      case original_path do
        nil -> Application.delete_env(:alembic, :worlds_path)
        val -> Application.put_env(:alembic, :worlds_path, val)
      end
    end)

    :ok
  end

  # ── Helpers ──────────────────────────────────────────────────────────

  defp call(method, path), do: conn(method, path) |> AssetServer.call(@opts)

  defp manifest_body do
    call(:get, "/worlds/#{@world_id}/manifest").resp_body |> Jason.decode!()
  end

  # ── Health ────────────────────────────────────────────────────────────

  describe "GET /health" do
    test "returns 200 ok" do
      conn = call(:get, "/health")
      assert conn.status == 200
      assert conn.resp_body == "ok"
    end
  end

  # ── Manifest ─────────────────────────────────────────────────────────

  describe "GET /worlds/:world_id/manifest" do
    test "returns 200 with JSON content type for a known world" do
      conn = call(:get, "/worlds/#{@world_id}/manifest")
      assert conn.status == 200
      [content_type | _] = get_resp_header(conn, "content-type")
      assert String.starts_with?(content_type, "application/json")
    end

    test "tiles have correct id and file path" do
      body = manifest_body()
      assert %{"id" => "grass_01", "file" => "tiles/grass_01.png"} in body["tiles"]
      assert %{"id" => "water_01", "file" => "tiles/water_01.png"} in body["tiles"]
    end

    test "characters have correct id, filename, and url" do
      body = manifest_body()

      assert %{
               "id" => "Male_White",
               "filename" => "Male_White.png",
               "url" => "/worlds/#{@world_id}/assets/sprites/characters/Male_White.png"
             } in body["sprites"]["characters"]
    end

    test "npcs have correct id and file path" do
      body = manifest_body()

      assert %{"id" => "merchant_01", "file" => "sprites/npcs/merchant_01.png"} in body["sprites"][
               "npcs"
             ]
    end

    test "returns 404 for an unknown world" do
      conn = call(:get, "/worlds/unknown_world/manifest")
      assert conn.status == 404
    end

    test "returns 404 for world_id containing path traversal (..) " do
      conn = call(:get, "/worlds/bad..world/manifest")
      assert conn.status == 404
    end
  end

  # ── Asset serving ─────────────────────────────────────────────────────

  describe "GET /worlds/:world_id/assets/*path" do
    test "serves a tile PNG with image/png content type" do
      conn = call(:get, "/worlds/#{@world_id}/assets/tiles/grass_01.png")
      assert conn.status == 200
      assert get_resp_header(conn, "content-type") == ["image/png"]
    end

    test "serves a character sprite" do
      conn = call(:get, "/worlds/#{@world_id}/assets/sprites/characters/Male_White.png")
      assert conn.status == 200
    end

    test "serves an NPC sprite" do
      conn = call(:get, "/worlds/#{@world_id}/assets/sprites/npcs/merchant_01.png")
      assert conn.status == 200
    end

    test "returns 404 for a missing file" do
      conn = call(:get, "/worlds/#{@world_id}/assets/tiles/nonexistent.png")
      assert conn.status == 404
    end

    test "returns 403 for a disallowed file extension" do
      conn = call(:get, "/worlds/#{@world_id}/assets/tiles/config.json")
      assert conn.status == 403
    end

    test "returns 404 for an unknown world" do
      conn = call(:get, "/worlds/unknown_world/assets/tiles/grass_01.png")
      assert conn.status == 404
    end

    test "returns 404 when asset path traversal escapes the manifest directory" do
      conn = call(:get, "/worlds/#{@world_id}/assets/../../../etc/passwd.png")
      assert conn.status == 404
    end
  end

  # ── Fallback ─────────────────────────────────────────────────────────

  describe "fallback" do
    test "returns 404 for unmatched routes" do
      conn = call(:get, "/not/a/real/route")
      assert conn.status == 404
    end
  end
end
