defmodule Alembic.Test.Network.ConnectionTest do
  use ExUnit.Case, async: false
  require Logger
  require Alembic.Network.Protocol.Packet
  import Alembic.Network.Protocol.Packet

  alias Alembic.Network.Protocol.Encoder

  @host ~c"localhost"
  @port 7777
  @timeout 5_000
  @logout_request disconnect()
  @logout_reason <<disconnect_logout()>>

  # ============================================================
  # Helpers
  # ============================================================

  defp build_packet(packet_id, payload) do
    magic = <<0x41, 0x4C, 0x42, 0x43>>
    version = <<0x00, 0x01, 0x00>>
    <<magic::binary, version::binary, packet_id::16, byte_size(payload)::32, payload::binary>>
  end

  defp connect() do
    {:ok, socket} = :gen_tcp.connect(@host, @port, [:binary, packet: :raw, active: false])
    socket
  end

  defp send_packet(socket, packet_id, payload) do
    :ok = :gen_tcp.send(socket, build_packet(packet_id, payload))
  end

  defp recv_packet(socket) do
    {:ok, data} = :gen_tcp.recv(socket, 0, @timeout)

    <<0x41, 0x4C, 0x42, 0x43, _version::24, packet_id::16, length::32,
      payload::binary-size(length)>> = data

    {packet_id, payload}
  end

  defp do_handshake(socket) do
    client_id = "test_client"
    payload = <<byte_size(client_id)::16, client_id::binary, 0x00, 0x01>>
    send_packet(socket, 0x0001, payload)
    {0x0002, challenge} = recv_packet(socket)
    challenge
  end

  defp do_auth(socket, challenge, token \\ "test_token_123") do
    hmac = :crypto.mac(:hmac, :sha256, token, challenge)
    auth_payload = <<byte_size(token)::16, token::binary, hmac::binary>>
    send_packet(socket, 0x0010, auth_payload)
    recv_packet(socket)
  end

  defp full_connect(token \\ "test_token_123") do
    socket = connect()
    challenge = do_handshake(socket)
    {0x0011, _} = do_auth(socket, challenge, token)
    wait_until(fn -> Registry.count(Alembic.Registry.PlayerRegistry) == 1 end)
    socket
  end

  defp wait_until(fun, retries \\ 20) do
    if fun.() do
      :ok
    else
      if retries > 0 do
        Process.sleep(100)
        wait_until(fun, retries - 1)
      else
        flunk("Condition not met within timeout")
      end
    end
  end

  # ============================================================
  # Tests
  # ============================================================

  describe "handshake" do
    test "server responds to handshake request with challenge" do
      socket = connect()

      client_id = "test_client"
      payload = <<byte_size(client_id)::16, client_id::binary, 0x00, 0x01>>
      send_packet(socket, 0x0001, payload)

      {packet_id, response_payload} = recv_packet(socket)

      assert packet_id == 0x0002, "Expected HandshakeResponse (0x0002), got #{inspect(packet_id)}"
      assert byte_size(response_payload) == 32, "Expected 32 byte challenge"

      :gen_tcp.close(socket)
    end

    test "server disconnects if no auth sent within timeout" do
      socket = connect()
      assert {:error, :closed} = :gen_tcp.recv(socket, 0, 15_000)
    end
  end

  describe "authentication" do
    setup do
      socket = connect()
      challenge = do_handshake(socket)
      %{socket: socket, challenge: challenge}
    end

    test "valid token authenticates successfully", %{socket: socket, challenge: challenge} do
      {packet_id, auth_response} = do_auth(socket, challenge)

      assert packet_id == 0x0011, "Expected AuthSuccess (0x0011), got #{inspect(packet_id)}"
      <<session_id::binary-size(16), _player_id::binary>> = auth_response
      assert byte_size(session_id) == 16

      :gen_tcp.close(socket)
    end

    test "invalid hmac is rejected", %{socket: socket, challenge: _challenge} do
      token = "test_token_123"
      bad_hmac = :crypto.strong_rand_bytes(32)
      auth_payload = <<byte_size(token)::16, token::binary, bad_hmac::binary>>
      send_packet(socket, 0x0010, auth_payload)

      {packet_id, _} = recv_packet(socket)
      assert packet_id == 0x0012, "Expected AuthFailure (0x0012), got #{inspect(packet_id)}"

      :gen_tcp.close(socket)
    end

    test "sending game packet before auth is rejected", %{socket: socket} do
      move_payload = <<0::16, 0::16, 0::8>>
      send_packet(socket, 0x0100, move_payload)

      result = :gen_tcp.recv(socket, 0, @timeout)

      case result do
        {:error, :closed} ->
          assert true

        {:error, :timeout} ->
          assert true

        {:ok, data} ->
          <<_::binary-size(4), _::24, packet_id::16, _::binary>> = data
          assert packet_id in [0x0012, 0x0021]
      end

      :gen_tcp.close(socket)
    end
  end

  describe "full connection flow" do
    test "complete handshake → auth → active session" do
      socket = full_connect()

      assert Registry.count(Alembic.Registry.PlayerRegistry) == 1

      :gen_tcp.close(socket)

      # Allow cleanup
      Process.sleep(200)
    end

    test "connection drop keeps player session alive for reconnection" do
      socket = full_connect()

      assert Registry.count(Alembic.Registry.PlayerRegistry) == 1

      # Simulate connection drop
      :gen_tcp.close(socket)
      Process.sleep(200)

      # Player should still be in registry waiting for reconnection
      assert Registry.count(Alembic.Registry.PlayerRegistry) == 1

      # Cleanup - disconnect the player manually
      Alembic.Entity.Player.disconnect("test_token_123")
      wait_until(fn -> Registry.count(Alembic.Registry.PlayerRegistry) == 0 end)
    end

    test "graceful logout removes player session" do
      socket = full_connect()

      assert Registry.count(Alembic.Registry.PlayerRegistry) == 1

      # Send disconnect packet with graceful logout reason
      send_packet(socket, @logout_request, @logout_reason)

      wait_until(fn -> Registry.count(Alembic.Registry.PlayerRegistry) == 0 end)
      assert Registry.count(Alembic.Registry.PlayerRegistry) == 0
    end

    test "reconnection updates handler pid" do
      socket1 = full_connect()
      assert Registry.count(Alembic.Registry.PlayerRegistry) == 1

      :gen_tcp.close(socket1)
      Process.sleep(200)

      assert Registry.count(Alembic.Registry.PlayerRegistry) == 1

      socket2 = full_connect()
      assert Registry.count(Alembic.Registry.PlayerRegistry) == 1

      # Graceful logout to cleanup
      send_packet(socket2, @logout_request, @logout_reason)
      wait_until(fn -> Registry.count(Alembic.Registry.PlayerRegistry) == 0 end)
    end
  end
end
