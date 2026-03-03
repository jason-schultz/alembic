defmodule Alembic.Test.Network.EncoderTest do
  use ExUnit.Case, async: true

  alias Alembic.Network.Protocol.Encoder
  alias Alembic.Network.Protocol.Decoder

  describe "Encoder" do
    @magic <<0x41, 0x4C, 0x42, 0x43>>

    test "encode produces valid packet structure" do
      packet = Encoder.encode(0x0001, <<1, 2, 3>>)
      <<magic::binary-size(4), _version::24, packet_id::16, length::32, payload::binary>> = packet

      assert magic == @magic
      assert packet_id == 0x0001
      assert length == 3
      assert payload == <<1, 2, 3>>
    end

    test "handshake_response encodes 32 byte challenge" do
      challenge = :crypto.strong_rand_bytes(32)
      packet = Encoder.handshake_response(challenge)

      <<@magic::binary, _version::24, packet_id::16, length::32, payload::binary>> = packet
      assert packet_id == 0x0002
      assert length == 32
      assert payload == challenge
    end

    test "auth_success encodes session_id and player_id" do
      packet = Encoder.auth_success("my_session_id_here", "player_123")

      <<@magic::binary, _version::24, 0x0011::16, _length::32, session_len::16,
        session_id::binary-size(session_len), player_len::16,
        player_id::binary-size(player_len)>> = packet

      assert session_id == "my_session_id_here"
      assert player_id == "player_123"
    end

    test "auth_failure encodes reason code" do
      packet = Encoder.auth_failure(:invalid_token)
      <<@magic::binary, _version::24, 0x0012::16, _length::32, reason_code::8>> = packet
      assert reason_code == 0x01
    end

    test "disconnect encodes logout reason" do
      packet = Encoder.disconnect(:logout)
      <<@magic::binary, _version::24, 0x0021::16, _length::32, reason::8>> = packet
      assert reason == 0x00
    end

    test "disconnect encodes timeout reason" do
      packet = Encoder.disconnect(:timeout)
      <<@magic::binary, _version::24, 0x0021::16, _length::32, reason::8>> = packet
      assert reason == 0x01
    end

    test "encoded packet can be decoded back" do
      challenge = :crypto.strong_rand_bytes(32)
      packet = Encoder.handshake_response(challenge)

      {:ok, decoded, <<>>} = Decoder.decode(packet)
      assert decoded == {:handshake_response, %{challenge: challenge}}
    end
  end
end
