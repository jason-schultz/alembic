defmodule Alembic.Test.Network.DecoderTest do
  use ExUnit.Case, async: true

  alias Alembic.Network.Protocol.Decoder
  require Alembic.Network.Protocol.Packet
  import Alembic.Network.Protocol.Packet

  describe "Decoder" do
    @magic <<0x41, 0x4C, 0x42, 0x43>>
    @version <<0x00, 0x01, 0x00>>

    defp build_raw_packet(packet_id, payload) do
      <<@magic::binary, @version::binary, packet_id::16, byte_size(payload)::32, payload::binary>>
    end

    test "decodes handshake_request" do
      client_id = "test_client"
      payload = <<byte_size(client_id)::16, client_id::binary, 0x00, 0x01>>
      packet = build_raw_packet(handshake_request(), payload)

      {:ok, decoded, <<>>} = Decoder.decode(packet)
      assert decoded == {:handshake_request, %{client_id: "test_client", version: 1}}
    end

    test "decodes auth_request" do
      token = "test_token"
      hmac = :crypto.strong_rand_bytes(32)
      payload = <<byte_size(token)::16, token::binary, hmac::binary>>
      packet = build_raw_packet(auth_request(), payload)

      {:ok, decoded, <<>>} = Decoder.decode(packet)
      assert decoded == {:auth_request, %{token: token, hmac: hmac}}
    end

    test "decodes player_move with facing directions" do
      for {byte, atom} <- [{0, :north}, {1, :south}, {2, :east}, {3, :west}] do
        packet = build_raw_packet(player_move(), <<10::16, 20::16, byte::8>>)
        {:ok, decoded, <<>>} = Decoder.decode(packet)
        assert decoded == {:player_move, %{x: 10, y: 20, facing: atom}}
      end
    end

    test "decodes disconnect with logout reason" do
      packet = build_raw_packet(disconnect(), <<0x00>>)
      {:ok, decoded, <<>>} = Decoder.decode(packet)
      assert decoded == {:disconnect, %{reason: :logout}}
    end

    test "decodes disconnect with timeout reason" do
      packet = build_raw_packet(disconnect(), <<0x01>>)
      {:ok, decoded, <<>>} = Decoder.decode(packet)
      assert decoded == {:disconnect, %{reason: :timeout}}
    end

    test "decodes disconnect with unknown reason" do
      packet = build_raw_packet(disconnect(), <<0xFF>>)
      {:ok, decoded, <<>>} = Decoder.decode(packet)
      assert decoded == {:disconnect, %{reason: :unknown}}
    end

    test "returns incomplete for partial packet" do
      partial = <<@magic::binary, 0x00, 0x01, 0x00, 0x00, 0x01>>
      assert Decoder.decode(partial) == {:incomplete}
    end

    test "returns error for invalid magic" do
      bad = <<0xDE, 0xAD, 0xBE, 0xEF, 1, 2, 3, 4, 5>>
      assert Decoder.decode(bad) == {:error, :invalid_magic}
    end

    test "returns unknown for unrecognized packet id" do
      packet = build_raw_packet(0x9999, <<1, 2, 3>>)
      {:ok, decoded, <<>>} = Decoder.decode(packet)
      assert decoded == {:unknown, %{id: 0x9999, payload: <<1, 2, 3>>}}
    end

    test "returns rest of binary after decoding" do
      client_id = "test_client"
      payload = <<byte_size(client_id)::16, client_id::binary, 0x00, 0x01>>
      packet = build_raw_packet(handshake_request(), payload)
      extra = <<1, 2, 3>>

      {:ok, _decoded, rest} = Decoder.decode(packet <> extra)
      assert rest == extra
    end
  end
end
