defmodule Alembic.Campaign.CampaignLoader do
  @moduledoc """
  Loads campaign data from JSON files and starts the world.

  Reads from priv/campaigns/<campaign_id>/campaign.json,
  deserializes into Zone and Room structs with real tile data,
  and hands them off to World.Server to start the game world.
  """

  require Logger

  alias Alembic.World.{Zone, Room, Tile}
  alias Alembic.Supervisors.{CampaignSupervisor, ZoneSupervisor, RoomSupervisor}

  @campaigns_dir "campaigns"

  @doc """
  Loads a campaign from priv/campaigns/<campaign_id>/campaign.json
  and starts all its zones and rooms.
  """
  def load(campaign_id) do
    Logger.info("Loading campaign: #{campaign_id}")

    with {:ok, json} <- read_campaign_file(campaign_id),
         {:ok, data} <- parse_json(json),
         {:ok, campaign} <- validate_campaign(data),
         {:ok, _pid} <- start_campaign(campaign) do
      Logger.info("Campaign #{campaign_id} loaded successfully")
      {:ok, campaign_id}
    else
      {:error, reason} ->
        Logger.error("Failed to load campaign #{campaign_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # --- Private ---

  defp read_campaign_file(campaign_id) do
    path =
      :code.priv_dir(:alembic)
      |> Path.join(@campaigns_dir)
      |> Path.join(campaign_id)
      |> Path.join("campaign.json")

    case File.read(path) do
      {:ok, contents} -> {:ok, contents}
      {:error, reason} -> {:error, {:file_read_error, reason, path}}
    end
  end

  defp parse_json(json) do
    case Jason.decode(json) do
      {:ok, data} -> {:ok, data}
      {:error, reason} -> {:error, {:json_parse_error, reason}}
    end
  end

  defp validate_campaign(%{"campaign" => campaign}) do
    required = ["id", "name", "start_zone_id", "zones", "rooms"]

    missing = Enum.filter(required, &(not Map.has_key?(campaign, &1)))

    if Enum.empty?(missing) do
      {:ok, campaign}
    else
      {:error, {:missing_fields, missing}}
    end
  end

  defp validate_campaign(_), do: {:error, :invalid_campaign_structure}

  defp start_campaign(campaign) do
    campaign_id = campaign["id"]
    zones = Enum.map(campaign["zones"], &build_zone/1)
    rooms = Enum.map(campaign["rooms"], &build_room/1)

    case CampaignSupervisor.start_campaign(campaign_id,
           zones: zones,
           rooms: rooms,
           start_zone_id: campaign["start_zone_id"],
           start_x: campaign["start_x"] || 0,
           start_y: campaign["start_y"] || 0
         ) do
      {:ok, pid} -> {:ok, pid}
      {:error, reason} -> {:error, {:campaign_start_failed, reason}}
    end
  end

  defp build_zone(zone_json) do
    tiles = build_zone_tiles(zone_json["tiles"] || [], zone_json["width"])

    Logger.info(
      "Building zone #{zone_json["id"]}: #{zone_json["width"]}x#{zone_json["height"]}, #{map_size(tiles)} tile rows"
    )

    %Zone{
      id: zone_json["id"],
      name: zone_json["name"],
      type: String.to_atom(zone_json["type"] || "overworld"),
      width: zone_json["width"],
      height: zone_json["height"],
      world_offset_x: zone_json["world_offset_x"] || 0,
      world_offset_y: zone_json["world_offset_y"] || 0,
      tiles: tiles
    }
  end

  defp build_zone_tiles(rows, width) do
    rows
    |> Enum.with_index()
    |> Enum.flat_map(fn {row, y} ->
      row
      |> Enum.with_index()
      |> Enum.map(fn {tile_json, x} ->
        {{x, y}, build_tile(tile_json, x, y)}
      end)
    end)
    |> Map.new()
  end

  defp build_room(room_json) do
    tiles = build_zone_tiles(room_json["tiles"] || [], room_json["width"])
    entrances = Enum.map(room_json["entrances"] || [], &build_entrance/1)

    %Room{
      id: room_json["id"],
      name: room_json["name"],
      type: String.to_atom(room_json["type"] || "house"),
      width: room_json["width"],
      height: room_json["height"],
      tiles: tiles,
      entrances: entrances
    }
  end

  defp build_entrance(entrance_json) do
    %{
      id: entrance_json["id"],
      room_x: entrance_json["room_x"],
      room_y: entrance_json["room_y"],
      leads_to_zone_id: entrance_json["leads_to_zone_id"],
      leads_to_x: entrance_json["leads_to_x"],
      leads_to_y: entrance_json["leads_to_y"],
      requires_key: entrance_json["requires_key"],
      one_way: entrance_json["one_way"] || false,
      metadata: %{}
    }
  end

  defp build_tile(tile_json, x, y) do
    %Tile{
      x: x,
      y: y,
      texture_id: tile_json["asset_id"],
      walkable: Map.get(tile_json, "walkable", true),
      type: tile_type(tile_json),
      room_enter: tile_json["room_enter"]
    }
  end

  defp tile_type(%{"walkable" => false}), do: :wall
  defp tile_type(%{"room_enter" => id}) when not is_nil(id), do: :door
  defp tile_type(_), do: :ground
end
