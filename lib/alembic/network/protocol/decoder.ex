defmodule Alembic.Network.Protocol.Decoder do
  @moduledoc """
  Decodes incoming binary data into game data structures.
  """

  require Alembic.Network.Protocol.Packet
  import Alembic.Network.Protocol.Packet

  @magic <<0x41, 0x4C, 0x42, 0x43>>

  def decode(
        <<@magic::binary, _version::24, packet_id::16, length::32, payload::binary-size(length),
          rest::binary>>
      ) do
    {:ok, decode_packet(packet_id, payload), rest}
  end

  def decode(<<@magic, _rest::binary>>) do
    # valid magic but incomplete packet
    {:incomplete}
  end

  def decode(<<_non_magic::binary-size(4), _rest::binary>>) do
    # invalid magic, reject connection
    {:error, :invalid_magic}
  end

  def decode(_), do: {:incomplete}

  defp decode_packet(
         handshake_request(),
         <<client_id_len::16, client_id::binary-size(client_id_len), version::16>>
       ) do
    {:handshake_request, %{client_id: client_id, version: version}}
  end

  defp decode_packet(handshake_response(), <<challenge::binary-size(32)>>) do
    {:handshake_response, %{challenge: challenge}}
  end

  defp decode_packet(
         auth_request(),
         <<token_len::16, token::binary-size(token_len), hmac::binary-size(32)>>
       ) do
    {:auth_request, %{token: token, hmac: hmac}}
  end

  defp decode_packet(player_move(), <<x::16, y::16, facing::8>>) do
    facing_atom =
      case facing do
        0 -> :north
        1 -> :south
        2 -> :east
        3 -> :west
        _ -> :south
      end

    {:player_move, %{x: x, y: y, facing: facing_atom}}
  end

  defp decode_packet(disconnect(), <<reason::8>>) do
    reason_atom =
      case reason do
        disconnect_logout() -> :logout
        disconnect_timeout() -> :timeout
        disconnect_invalid_packet() -> :invalid_packet
        disconnect_server_error() -> :server_error
        _ -> :unknown
      end

    {:disconnect, %{reason: reason_atom}}
  end

  defp decode_packet(id, payload) do
    {:unknown, %{id: id, payload: payload}}
  end
end
