defmodule Alembic.Network.Protocol.Encoder do
  @moduledoc """
  Encodes game data into binary format for network transmission.
  """

  require Alembic.Network.Protocol.Packet
  import Alembic.Network.Protocol.Packet

  @magic <<0x41, 0x4C, 0x42, 0x43>>
  @version (fn ->
              [major, minor, patch] =
                Mix.Project.config()[:version]
                |> String.trim_leading("v")
                |> String.split(".", parts: 3)
                |> Enum.map(&String.to_integer/1)

              <<major::8, minor::8, patch::8>>
            end).()

  @doc """
  Encodes an authentication success packet.
  ## Examples

      iex> Encoder.auth_success("session123", "player456")
      <<0x41, 0x4C, 0x42, 0x43, 0x01, 0x00, 0x11, 0x00, 0x00, 0x00, 0x0A, "session123", 0x00, 0x00, 0x00, 0x0A, "player456">>
  """
  @spec auth_success(String.t(), String.t()) :: binary()
  def auth_success(session_id, player_id) do
    session_bytes = byte_size(session_id)
    player_bytes = byte_size(player_id)

    payload =
      <<
        session_bytes::16,
        session_id::binary,
        player_bytes::16,
        player_id::binary
      >>

    encode(auth_success(), payload)
  end

  @doc """
  Encodes an authentication failure packet with a reason code.
  ## Examples

      iex> Encoder.auth_failure(:invalid_token)
      <<0x41, 0x4C, 0x42, 0x43, 0x01, 0x00, 0x12, 0x00, 0x00, 0x00, 0x01, 0x01>>
  """
  @spec auth_failure(atom()) :: binary()
  def auth_failure(reason) do
    reason_code =
      case reason do
        :invalid_token -> 0x01
        :expired_token -> 0x02
        :banned -> 0x03
        :server_full -> 0x04
        _ -> 0xFF
      end

    encode(auth_failure(), <<reason_code::8>>)
  end

  @doc """
  Encodes an entity movement packet with the given parameters.
  ## Examples

      iex> Encoder.entity_move("entity123", 10, 20, :north)
      <<0x41, 0x4C, 0x42, 0x43, 0x01, 0x01, 0x04, 0x00, 0x00, 0x00, 0x0A, "entity123", 0x00, 0x0A, 0x00, 0x14, 0x00>>
  """
  @spec entity_move(String.t(), integer(), integer(), atom()) :: binary()
  def entity_move(entity_id, x, y, facing) do
    facing_byte =
      case facing do
        :north -> 0
        :east -> 1
        :south -> 2
        :west -> 3
      end

    payload = <<entity_id::binary-size(16), x::16, y::16, facing_byte::8>>
    encode(0x0104, payload)
  end

  @doc """
  Encodes a generic packet with the given ID and binary payload.
  ## Examples

      iex> Encoder.encode(0x0001, <<1, 2, 3>>)
      <<0x41, 0x4C, 0x42, 0x43, 0x01, 0x00, 0x01, 0x00, 0x00, 0x00, 0x03, 0x01, 0x02, 0x03>>
  """
  @spec encode(integer(), binary()) :: binary()
  def encode(packet_id, payload) when is_binary(payload) do
    length = byte_size(payload)

    <<
      @magic::binary,
      @version::binary,
      packet_id::16,
      length::32,
      payload::binary
    >>
  end

  @doc """
  Encodes a handshake response packet with the given challenge string.
  ## Examples
      iex> Encoder.handshake_response("challenge123")
      <<0x41, 0x4C, 0x42, 0x43, 0x01, 0x00, 0x02, 0x00, 0x00, 0x00, 0x20, "challenge123">>
  """
  @spec handshake_response(String.t()) :: binary()
  def handshake_response(challenge) do
    payload = <<challenge::binary-size(32)>>
    encode(handshake_response(), payload)
  end

  @doc """
  Encodes a disconnect packet with the given reason.
  ## Examples
      iex> Encoder.disconnect(:logout)
      <<0x41, 0x4C, 0x42, 0x43, 0x01, 0x00, 0x21, 0x00, 0x00, 0x00, 0x01, 0x00>>
  """
  @spec disconnect(atom()) :: binary()
  def disconnect(reason) do
    reason_code =
      case reason do
        :logout -> disconnect_logout()
        :timeout -> disconnect_timeout()
        :invalid_packet -> disconnect_invalid_packet()
        :server_error -> disconnect_server_error()
        _ -> 0xFF
      end

    encode(0x0021, <<reason_code::8>>)
  end

  @doc """
  Encodes a zone info packet sent to the client after auth.
  Tells the client which zone they are in and its dimensions.
  """
  @spec zone_info(String.t(), String.t(), non_neg_integer(), non_neg_integer()) :: binary()
  def zone_info(zone_id, zone_name, width, height) do
    zone_id_bytes = byte_size(zone_id)
    zone_name_bytes = byte_size(zone_name)

    payload = <<
      zone_id_bytes::16,
      zone_id::binary,
      zone_name_bytes::16,
      zone_name::binary,
      width::16,
      height::16
    >>

    encode(zone_info(), payload)
  end

  @doc """
  Encodes a room info packet sent to the client after auth.
  Tells the client which room they are in and its dimensions.
  """
  @spec room_info(String.t(), String.t(), non_neg_integer(), non_neg_integer()) :: binary()
  def room_info(room_id, room_name, width, height) do
    room_id_bytes = byte_size(room_id)
    room_name_bytes = byte_size(room_name)

    payload = <<
      room_id_bytes::16,
      room_id::binary,
      room_name_bytes::16,
      room_name::binary,
      width::16,
      height::16
    >>

    encode(room_info(), payload)
  end

  @doc """
  Encodes a spawn position packet sent to the client after auth.
  Tells the client where to place the player in the world.
  """
  @spec spawn_position(String.t(), integer(), integer(), integer(), integer(), atom()) :: binary()
  def spawn_position(zone_id, x, y, world_x, world_y, facing) do
    zone_id_bytes = byte_size(zone_id)

    facing_byte =
      case facing do
        :north -> 0
        :south -> 1
        :east -> 2
        :west -> 3
      end

    payload = <<
      zone_id_bytes::16,
      zone_id::binary,
      x::16,
      y::16,
      world_x::32,
      world_y::32,
      facing_byte::8
    >>

    encode(spawn_position(), payload)
  end

  @doc """
  Encodes a viewport update packet.
  Sends a flat list of tiles around the player's position.

  Each tile is encoded as:
    x::16, y::16, asset_id_len::16, asset_id::binary, walkable::8
  """
  @spec viewport_update(map()) :: binary()
  def viewport_update(%{tiles: tiles, center: %{x: cx, y: cy}}) do
    tile_count = length(tiles)

    tiles_binary =
      Enum.reduce(tiles, <<>>, fn tile, acc ->
        asset_id = Map.get(tile, :texture_id) || Map.get(tile, :asset_id) || "void"
        asset_id_bytes = byte_size(asset_id)
        walkable_byte = if tile.walkable, do: 1, else: 0

        acc <>
          <<
            tile.x::16,
            tile.y::16,
            asset_id_bytes::16,
            asset_id::binary,
            walkable_byte::8
          >>
      end)

    payload = <<
      cx::16,
      cy::16,
      tile_count::32,
      tiles_binary::binary
    >>

    encode(viewport_update(), payload)
  end

  @doc """
  Encodes an entity spawn packet.
  Sent when a player, NPC, or mob enters the client's viewport.
  """
  @spec entity_spawn(String.t(), atom(), integer(), integer(), String.t()) :: binary()
  def entity_spawn(entity_id, entity_type, x, y, sprite_id) do
    entity_id_bytes = byte_size(entity_id)
    sprite_id_bytes = byte_size(sprite_id)

    type_byte =
      case entity_type do
        :player -> 0
        :npc -> 1
        :mob -> 2
        _ -> 0xFF
      end

    payload = <<
      entity_id_bytes::16,
      entity_id::binary,
      type_byte::8,
      x::16,
      y::16,
      sprite_id_bytes::16,
      sprite_id::binary
    >>

    encode(entity_spawn(), payload)
  end
end
