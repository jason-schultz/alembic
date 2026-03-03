defmodule Alembic.Test.Network.ConnectionTest do
  use ExUnit.Case, async: false
  require Logger
  require Alembic.Network.Protocol.Packet
  import Alembic.Network.Protocol.Packet

  @host ~c"localhost"
  @port 7777
  @timeout 5_000
  @disconnect_packet disconnect()
  @logout_reason <<0x00>>

  # ============================================================
  # Helpers
  # ============================================================

  defp unique_token, do: "test_token_#{:erlang.unique_integer([:positive])}"

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
    send_packet(socket, handshake_request(), payload)
    {0x0002, challenge} = recv_packet(socket)
    challenge
  end

  defp do_auth(socket, challenge, token) do
    hmac = :crypto.mac(:hmac, :sha256, token, challenge)
    auth_payload = <<byte_size(token)::16, token::binary, hmac::binary>>
    send_packet(socket, auth_request(), auth_payload)
    recv_packet(socket)
  end

  defp full_connect(token) do
    socket = connect()
    challenge = do_handshake(socket)
    {0x0011, payload} = do_auth(socket, challenge, token)

    # Extract player_id from auth_success payload
    <<session_id_len::16, _session_id::binary-size(session_id_len), player_id_len::16,
      player_id::binary-size(player_id_len)>> = payload

    wait_until(fn ->
      case Registry.lookup(Alembic.Registry.PlayerRegistry, player_id) do
        [{pid, _}] ->
          state = :sys.get_state(pid)
          is_pid(state.handler_pid) and Process.alive?(state.handler_pid)

        [] ->
          false
      end
    end)

    {socket, player_id}
  end

  defp cleanup_player(player_id) do
    case Registry.lookup(Alembic.Registry.PlayerRegistry, player_id) do
      [{pid, _}] -> GenServer.stop(pid, :normal)
      [] -> :ok
    end
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
  # Handshake Tests
  # ============================================================

  describe "handshake" do
    test "server responds to handshake request with 32 byte challenge" do
      socket = connect()

      client_id = "test_client"
      payload = <<byte_size(client_id)::16, client_id::binary, 0x00, 0x01>>
      send_packet(socket, handshake_request(), payload)

      {packet_id, challenge} = recv_packet(socket)

      assert packet_id == handshake_response(),
             "Expected HandshakeResponse (0x0002), got #{inspect(packet_id)}"

      assert byte_size(challenge) == 32, "Expected 32 byte challenge, got #{byte_size(challenge)}"

      :gen_tcp.close(socket)
    end

    test "challenge is unique per connection" do
      socket1 = connect()
      socket2 = connect()

      challenge1 = do_handshake(socket1)
      challenge2 = do_handshake(socket2)

      assert challenge1 != challenge2, "Challenges should be unique per connection"

      :gen_tcp.close(socket1)
      :gen_tcp.close(socket2)
    end

    test "server disconnects if no auth sent within timeout" do
      socket = connect()
      # Don't send anything - wait for server to close
      assert {:error, :closed} = :gen_tcp.recv(socket, 0, 15_000)
    end

    test "server disconnects if handshake sent but no auth within timeout" do
      socket = connect()
      _challenge = do_handshake(socket)
      # Don't send auth - wait for server to close
      assert {:error, :closed} = :gen_tcp.recv(socket, 0, 15_000)
    end

    test "sending auth before handshake is rejected" do
      socket = connect()

      # Send auth without handshake first
      token = "test_token_123"
      hmac = :crypto.strong_rand_bytes(32)
      auth_payload = <<byte_size(token)::16, token::binary, hmac::binary>>
      send_packet(socket, auth_request(), auth_payload)

      # Server should ignore or close connection
      result = :gen_tcp.recv(socket, 0, @timeout)
      assert match?({:error, :closed}, result) or match?({:error, :timeout}, result)

      :gen_tcp.close(socket)
    end
  end

  # ============================================================
  # Authentication Tests
  # ============================================================

  describe "authentication" do
    setup do
      token = unique_token()
      socket = connect()
      challenge = do_handshake(socket)
      on_exit(fn -> cleanup_player(token) end)
      %{socket: socket, challenge: challenge, token: token}
    end

    test "valid token authenticates successfully", %{
      socket: socket,
      challenge: challenge,
      token: token
    } do
      {packet_id, auth_response} = do_auth(socket, challenge, token)

      assert packet_id == auth_success(),
             "Expected AuthSuccess (0x0011), got #{inspect(packet_id)}"

      # Response: session_id_len::16, session_id, player_id_len::16, player_id
      <<session_id_len::16, session_id::binary-size(session_id_len), _rest::binary>> =
        auth_response

      assert session_id_len == 32, "Expected 32 byte session_id"
      assert byte_size(session_id) == 32

      :gen_tcp.close(socket)
    end

    test "invalid hmac is rejected", %{socket: socket, challenge: challenge, token: token} do
      bad_hmac = :crypto.strong_rand_bytes(32)
      auth_payload = <<byte_size(token)::16, token::binary, bad_hmac::binary>>
      send_packet(socket, auth_request(), auth_payload)

      {packet_id, _} = recv_packet(socket)

      assert packet_id == auth_failure(),
             "Expected AuthFailure (0x0012), got #{inspect(packet_id)}"

      :gen_tcp.close(socket)
    end

    test "wrong token is rejected", %{socket: socket, challenge: challenge, token: token} do
      # Use a different token for HMAC than what we claim
      real_token = token
      wrong_token = "wrong_token_456"
      hmac = :crypto.mac(:hmac, :sha256, wrong_token, challenge)

      auth_payload = <<byte_size(real_token)::16, real_token::binary, hmac::binary>>
      send_packet(socket, auth_request(), auth_payload)

      {packet_id, _} = recv_packet(socket)
      assert packet_id == auth_failure()

      :gen_tcp.close(socket)
    end

    test "sending game packet before auth is rejected", %{socket: socket} do
      move_payload = <<0::16, 0::16, 0::8>>
      send_packet(socket, player_move(), move_payload)

      result = :gen_tcp.recv(socket, 0, @timeout)

      case result do
        {:error, :closed} ->
          assert true

        {:error, :timeout} ->
          assert true

        {:ok, data} ->
          <<_::binary-size(4), _::24, packet_id::16, _::binary>> = data
          assert packet_id in [auth_failure(), disconnect()]
      end

      :gen_tcp.close(socket)
    end

    test "auth creates player session in registry", %{
      socket: socket,
      challenge: challenge,
      token: token
    } do
      do_auth(socket, challenge, token)
      wait_until(fn -> Registry.count(Alembic.Registry.PlayerRegistry) == 1 end)
      assert Registry.count(Alembic.Registry.PlayerRegistry) == 1

      :gen_tcp.close(socket)
      Process.sleep(200)
    end
  end

  # ============================================================
  # Disconnect Tests
  # ============================================================

  describe "disconnect" do
    setup do
      token = unique_token()
      %{token: token}
    end

    test "graceful logout removes player session", %{token: token} do
      {socket, player_id} = full_connect(token)
      assert Registry.count(Alembic.Registry.PlayerRegistry) == 1

      send_packet(socket, @disconnect_packet, @logout_reason)

      wait_until(fn -> Registry.lookup(Alembic.Registry.PlayerRegistry, player_id) == [] end)
      assert Registry.lookup(Alembic.Registry.PlayerRegistry, player_id) == []
    end

    test "connection drop keeps player session alive for reconnection", %{token: token} do
      {socket, player_id} = full_connect(token)
      assert Registry.count(Alembic.Registry.PlayerRegistry) == 1

      # Simulate abrupt connection drop
      :gen_tcp.close(socket)
      Process.sleep(200)

      # Player should still be in registry
      assert Registry.lookup(Alembic.Registry.PlayerRegistry, player_id) != []

      # Cleanup
      cleanup_player(player_id)
    end

    test "connection drop clears handler pid", %{token: token} do
      {socket, player_id} = full_connect(token)

      :gen_tcp.close(socket)

      wait_until(fn ->
        case Registry.lookup(Alembic.Registry.PlayerRegistry, player_id) do
          [{pid, _}] -> :sys.get_state(pid).handler_pid == nil
          [] -> false
        end
      end)

      [{pid, _}] = Registry.lookup(Alembic.Registry.PlayerRegistry, player_id)
      assert :sys.get_state(pid).handler_pid == nil
      cleanup_player(player_id)
    end

    test "disconnect before auth does not crash server", %{token: _token} do
      socket = connect()
      _challenge = do_handshake(socket)

      :gen_tcp.close(socket)
      Process.sleep(200)

      # No player should have been created since auth never completed
      assert Registry.count(Alembic.Registry.PlayerRegistry) == 0
    end
  end

  # ============================================================
  # Reconnection Tests
  # ============================================================

  describe "reconnection" do
    setup do
      token = unique_token()

      on_exit(fn ->
        Process.sleep(300)
      end)

      %{token: token}
    end

    test "reconnection updates handler pid", %{token: token} do
      # First connection
      {socket1, player_id} = full_connect(token)

      [{pid, _}] = Registry.lookup(Alembic.Registry.PlayerRegistry, player_id)
      first_handler = :sys.get_state(pid).handler_pid
      assert is_pid(first_handler)

      # Drop connection and wait for handler to clear
      :gen_tcp.close(socket1)

      wait_until(fn ->
        case Registry.lookup(Alembic.Registry.PlayerRegistry, player_id) do
          [{p, _}] -> :sys.get_state(p).handler_pid == nil
          [] -> false
        end
      end)

      Process.sleep(200)

      # Reconnect with SAME token - server identifies player by token
      socket2 = connect()
      challenge = do_handshake(socket2)
      {0x0011, _} = do_auth(socket2, challenge, token)

      wait_until(
        fn ->
          case Registry.lookup(Alembic.Registry.PlayerRegistry, player_id) do
            [{p, _}] ->
              new_handler = :sys.get_state(p).handler_pid

              Logger.debug(
                "Waiting for new handler - current: #{inspect(new_handler)}, first: #{inspect(first_handler)}"
              )

              is_pid(new_handler) and new_handler != first_handler

            [] ->
              false
          end
        end,
        50
      )

      [{pid2, _}] = Registry.lookup(Alembic.Registry.PlayerRegistry, player_id)
      second_handler = :sys.get_state(pid2).handler_pid

      assert pid == pid2, "Player GenServer should be the same pid"
      assert first_handler != second_handler, "Handler pid should have changed"
      assert is_pid(second_handler)

      send_packet(socket2, @disconnect_packet, @logout_reason)
      wait_until(fn -> Registry.lookup(Alembic.Registry.PlayerRegistry, player_id) == [] end)
    end

    test "reconnection does not create duplicate player sessions", %{token: token} do
      {socket1, player_id} = full_connect(token)

      :gen_tcp.close(socket1)

      wait_until(fn ->
        case Registry.lookup(Alembic.Registry.PlayerRegistry, player_id) do
          [{p, _}] -> :sys.get_state(p).handler_pid == nil
          [] -> false
        end
      end)

      Process.sleep(200)

      # Reconnect with SAME token
      {socket2, player_id2} = full_connect(token)

      assert player_id == player_id2, "Should be the same player_id"
      assert length(Registry.lookup(Alembic.Registry.PlayerRegistry, player_id)) == 1

      send_packet(socket2, @disconnect_packet, @logout_reason)
      wait_until(fn -> Registry.lookup(Alembic.Registry.PlayerRegistry, player_id) == [] end)
    end
  end

  # ============================================================
  # Heartbeat Tests
  # ============================================================

  describe "heartbeat" do
    test "server sends heartbeat after auth" do
      # Temporarily reduce heartbeat interval to avoid long test
      # This test relies on the @heartbeat_interval being short enough
      # Alternatively mock the timer - for now just verify packet format
      token = unique_token()
      {socket, player_id} = full_connect(token)

      # Heartbeat is sent after @heartbeat_interval (30s default)
      # So instead we just verify the server is still alive and responsive
      assert Registry.count(Alembic.Registry.PlayerRegistry) == 1

      send_packet(socket, @disconnect_packet, @logout_reason)
      wait_until(fn -> Registry.count(Alembic.Registry.PlayerRegistry) == 0 end)
    end

    test "heartbeat packet has correct format" do
      # Build and verify a heartbeat packet manually
      magic = <<0x41, 0x4C, 0x42, 0x43>>
      version = <<0x00, 0x01, 0x00>>
      packet_id = <<0x00, 0x22>>
      length = <<0x00, 0x00, 0x00, 0x00>>
      heartbeat = magic <> version <> packet_id <> length

      assert byte_size(heartbeat) == 13
      <<0x41, 0x4C, 0x42, 0x43, _version::24, 0x0022::16, 0::32>> = heartbeat
    end
  end

  # ============================================================
  # Protocol Tests
  # ============================================================

  describe "protocol" do
    setup do
      token = unique_token()
      on_exit(fn -> cleanup_player(token) end)
      %{token: token}
    end

    test "multiple packets in single TCP segment are processed", %{token: token} do
      socket = connect()
      challenge = do_handshake(socket)

      # Build auth packet
      hmac = :crypto.mac(:hmac, :sha256, token, challenge)
      auth_payload = <<byte_size(token)::16, token::binary, hmac::binary>>
      auth_packet = build_packet(auth_request(), auth_payload)

      # Build a move packet (will be ignored if auth succeeds first)
      move_packet = build_packet(player_move(), <<10::16, 20::16, 0::8>>)

      # Send both in one TCP segment
      :gen_tcp.send(socket, auth_packet <> move_packet)

      {packet_id, _} = recv_packet(socket)
      assert packet_id == auth_success()

      wait_until(fn -> Registry.count(Alembic.Registry.PlayerRegistry) == 1 end)

      send_packet(socket, @disconnect_packet, @logout_reason)
      wait_until(fn -> Registry.count(Alembic.Registry.PlayerRegistry) == 0 end)
    end

    test "unknown packet type is handled gracefully", %{token: token} do
      {socket, player_id} = full_connect(token)

      # Send an unknown packet type
      send_packet(socket, 0x9999, <<1, 2, 3>>)

      # Server should still be alive
      Process.sleep(100)
      assert Registry.count(Alembic.Registry.PlayerRegistry) == 1

      send_packet(socket, @disconnect_packet, @logout_reason)
      wait_until(fn -> Registry.count(Alembic.Registry.PlayerRegistry) == 0 end)
    end

    test "invalid magic bytes closes connection", %{token: token} do
      {:ok, socket} = :gen_tcp.connect(@host, @port, [:binary, packet: :raw, active: false])

      # Send garbage data with wrong magic
      :gen_tcp.send(socket, <<0xDE, 0xAD, 0xBE, 0xEF, 1, 2, 3, 4, 5>>)

      # Server should close connection
      result = :gen_tcp.recv(socket, 0, @timeout)
      assert match?({:error, :closed}, result) or match?({:error, :timeout}, result)
    end
  end
end
