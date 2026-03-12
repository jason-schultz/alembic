defmodule Alembic.Network.ConnectionHandler do
  use GenServer
  require Logger
  require Alembic.Network.Protocol.Packet
  import Alembic.Network.Protocol.Packet

  alias Alembic.World.{Room, Server, Zone}
  alias Alembic.Entity.{Player, Position}
  alias Alembic.Supervisors.PlayerSupervisor
  alias Alembic.Network.Protocol.{Decoder, Encoder}

  # 30 seconds
  @heartbeat_interval 30_000
  # 10 seconds to auth or disconnect
  @auth_timeout 10_000

  defstruct [
    :socket,
    :player_id,
    :session_id,
    :challenge,
    buffer: <<>>,
    # :handshake | :authenticating | :active
    state: :handshake
  ]

  def start_link(socket) do
    GenServer.start_link(__MODULE__, socket)
  end

  def init(socket) do
    Process.send_after(self(), :auth_timeout, @auth_timeout)
    {:ok, %__MODULE__{socket: socket}}
  end

  def child_spec(socket) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [socket]},
      restart: :temporary,
      shutdown: 5_000,
      type: :worker
    }
  end

  def handle_info({:tcp, _socket, data}, state) do
    Logger.debug("Received data from client: #{inspect(data)} - #{Base.encode16(data)}")

    buffer = state.buffer <> data
    {packets, remaining} = extract_packets(buffer)

    Logger.debug("Extracted #{length(packets)} packets: #{inspect(packets)}")
    Logger.debug("Current connection state: #{inspect(state.state)}")

    new_state =
      Enum.reduce(packets, %{state | buffer: remaining}, fn packet, acc ->
        Logger.debug("Processing packet: #{inspect(packet)} in state: #{inspect(acc.state)}")

        try do
          result = process_packet(packet, acc)
          Logger.debug("process_packet succeeded, new state: #{inspect(result.state)}")
          result
        rescue
          e ->
            Logger.error("process_packet crashed: #{inspect(e)}")
            Logger.error(Exception.format_stacktrace(__STACKTRACE__))
            acc
        catch
          kind, reason ->
            Logger.error("process_packet threw #{inspect(kind)}: #{inspect(reason)}")
            Logger.error(Exception.format_stacktrace(__STACKTRACE__))
            acc
        end
      end)

    {:noreply, new_state}
  end

  def handle_info({:tcp_closed, _socket}, state) do
    Logger.info(
      "Client connection dropped: #{inspect(state.player_id)}, state: #{inspect(state.state)}, pid: #{inspect(self())}"
    )

    cleanup_disconnect(state)
    {:stop, :normal, state}
  end

  def handle_info(:auth_timeout, %{state: state_name} = state)
      when state_name != :active do
    Logger.warning("Client failed to authenticate in time, disconnecting")
    :gen_tcp.close(state.socket)
    {:stop, :normal, state}
  end

  def handle_info(:auth_timeout, state) do
    {:noreply, state}
  end

  def handle_info(:heartbeat, state) do
    send_packet(state.socket, Encoder.encode(heartbeat(), <<>>))
    Process.send_after(self(), :heartbeat, @heartbeat_interval)
    {:noreply, state}
  end

  def handle_info({:send_packet, payload}, state) do
    send_packet(state.socket, payload)
    {:noreply, state}
  end

  # handle handshake
  defp process_packet({:handshake_request, _data}, state)
       when state.state == :handshake do
    challenge = :crypto.strong_rand_bytes(32)
    send_packet(state.socket, Encoder.handshake_response(challenge))
    %{state | challenge: challenge, state: :authenticating}
  end

  # handle auth
  defp process_packet({:auth_request, %{token: token, hmac: hmac}}, state)
       when state.state == :authenticating do
    case verify_auth(token, hmac, state.challenge) do
      {:ok, player_id} ->
        session_id = generate_session_id()
        send_packet(state.socket, Encoder.auth_success(session_id, player_id))
        Process.send_after(self(), :heartbeat, @heartbeat_interval)
        start_player_session(player_id, self())
        # ← add this
        send_world_sync(player_id, state.socket)
        %{state | player_id: player_id, session_id: session_id, state: :active}

      {:error, reason} ->
        send_packet(state.socket, Encoder.auth_failure(reason))
        :gen_tcp.close(state.socket)
        state
    end
  end

  defp process_packet({:disconnect, %{reason: :logout}}, state)
       when state.state == :active do
    Logger.info(
      "Client requested logout: #{inspect(state.player_id)}, state: #{inspect(state.state)}, pid: #{inspect(self())}"
    )

    cleanup_logout(state)
    :gen_tcp.close(state.socket)
    state
  end

  defp process_packet({:disconnect, %{reason: :timeout}}, state) do
    Logger.warning("Client sent timeout disconnect: #{state.player_id}")
    cleanup_disconnect(state)
    :gen_tcp.close(state.socket)
    state
  end

  defp process_packet({:disconnect, %{reason: reason}}, state) do
    Logger.warning("Client disconnected with reason: #{reason}, player: #{state.player_id}")
    cleanup_disconnect(state)
    :gen_tcp.close(state.socket)
    state
  end

  # handle game packets - only when active
  defp process_packet({:player_move, %{x: _x, y: _y, facing: facing}}, state)
       when state.state == :active do
    # TODO: Player.get_state is a synchronous GenServer call inside a packet handler.
    # For now it's fine, but eventually you'll want the player's current zone/room stored directly
    # on the ConnectionHandler state so you don't need to call out to another process on every move packet.
    player = Player.get_state(state.player_id)

    case player.position do
      %Position{room_id: nil, zone_id: zone_id} ->
        handle_move_result(
          Zone.move_player_facing(zone_id, state.player_id, facing),
          state.player_id,
          state.socket
        )

      %Position{room_id: room_id, zone_id: _zone_id} ->
        handle_move_result(
          Room.move_player_facing(room_id, state.player_id, facing),
          state.player_id,
          state.socket
        )
    end

    state
  end

  defp process_packet({:heartbeat_ack, _}, state) when state.state == :active do
    # Optionally track last heartbeat ack time for more accurate timeout detection
    state
  end

  defp process_packet({:player_move, %{x: _client_x, y: _client_y, facing: facing}}, state)
       when state.state == :active do
    player_id = state.player_id

    position = Player.get_position(player_id)

    move_result =
      case position.room_id do
        nil -> Zone.move_player_facing(position.zone_id, player_id, facing)
        room_id -> Room.move_player_facing(room_id, player_id, facing)
      end

    case move_result do
      {:ok, {new_x, new_y, new_world_x, new_world_y}} ->
        updated_position = %{
          position
          | x: new_x,
            y: new_y,
            world_x: new_world_x,
            world_y: new_world_y
        }

        Player.set_position(player_id, updated_position)

        send_packet(
          state.socket,
          Encoder.position_confirm(
            updated_position.zone_id,
            new_x,
            new_y,
            new_world_x,
            new_world_y,
            facing
          )
        )

        state

      {:transition, destination} ->
        # TODO: Handle zone/room transitions
        Logger.info("Player #{player_id} triggered transition to #{destination}")

        state

      {:error, reason} ->
        # Send correction -- snap client back to authoritative position
        Logger.debug("Move rejected for player #{player_id}: #{reason}")

        send_packet(
          state.socket,
          Encoder.position_correction(
            position.x,
            position.y,
            position.world_x,
            position.world_y,
            position.facing
          )
        )

        state
    end
  end

  # reject out of order packets
  defp process_packet({packet_type, _}, state) do
    Logger.warning("Unexpected packet #{packet_type} in state #{state.state}")
    state
  end

  # Connection dropped - keep player in registry for reconnection
  defp cleanup_disconnect(state) do
    if state.player_id do
      case Player.get_handler(state.player_id) do
        {:ok, handler_pid} when handler_pid == self() ->
          Logger.debug("Connection dropped, keeping player session alive: #{state.player_id}")
          Player.set_handler(state.player_id, nil)

        {:ok, _other} ->
          Logger.debug(
            "Connection dropped, handler already replaced - not clearing: #{state.player_id}"
          )

        {:error, :not_found} ->
          Logger.debug("Connection dropped, player session already gone: #{state.player_id}")
      end
    end
  end

  @doc """
  Handle the result of a move attempt, which could be a successful move, a transition to another room/zone, or an error.
   - For successful moves, update the player's position and optionally send a confirmation to the client.
   - For transitions, log the event and trigger the necessary room/zone change logic (not implemented here).
   - For errors, log the reason and optionally send a correction packet to the client.
   This function is called after attempting to move the player in the current room or zone, and it centralizes the handling of different outcomes from a move attempt.
  """
  defp handle_move_result({:ok, {new_x, new_y, new_world_x, new_world_y}}, player_id, socket) do
    # update the player's position to reflect the confirmed move
    player = Player.get_state(player_id)

    updated_position = %Position{
      player.position
      | x: new_x,
        y: new_y,
        world_x: new_world_x,
        world_y: new_world_y
    }

    Player.set_position(player_id, updated_position)

    send_packet(
      socket,
      Encoder.position_confirm(
        updated_position.zone_id,
        new_x,
        new_y,
        new_world_x,
        new_world_y,
        updated_position.facing
      )
    )

    viewport = Zone.get_viewport(updated_position.zone_id, new_x, new_y)
    send_packet(socket, Encoder.viewport_update(viewport))

    Logger.debug("Move confirmed for player #{player_id}, new position: (#{new_x}, #{new_y})")
  end

  defp handle_move_result({:transition, destination}, player_id, _socket)
       when is_binary(destination) do
    # Zone → Room transition, destination is a room_id
    Logger.info("Player #{player_id} entering room: #{destination}")
    # TODO: World.Server.enter_room(...)
  end

  defp handle_move_result({:transition, entrance}, player_id, _socket) when is_map(entrance) do
    # Player stepped on an exit tile — orchestrate the room/zone change
    # TODO: call World.Server.enter_room or transition_player
    Logger.info("Player #{player_id} triggering transition: #{inspect(entrance)}")
  end

  defp handle_move_result({:error, reason}, player_id, socket) do
    # Move was rejected — optionally send a correction packet to snap client back
    Logger.debug("Move rejected for player #{player_id}: #{reason}")
    player = Player.get_state(player_id)
    position = player.position

    send_packet(
      socket,
      Encoder.position_correction(
        position.x,
        position.y,
        position.world_x,
        position.world_y,
        position.facing
      )
    )
  end

  # Graceful logout - stop the player session entirely
  defp cleanup_logout(state) do
    if state.player_id do
      Logger.debug("Player logged out, stopping session: #{state.player_id}")
      Alembic.Entity.Player.disconnect(state.player_id)
    end
  end

  defp start_player_session(player_id, handler_pid) do
    case PlayerSupervisor.reconnect_player(player_id, handler_pid) do
      {:ok, _pid} ->
        Logger.info("Player reconnected: #{player_id}")
        :ok

      {:error, :not_found} ->
        spawn =
          case Server.get_spawn_position("main_story") do
            {:ok, pos} -> pos
            _ -> %{zone_id: "town_millhaven", x: 0, y: 0}
          end

        case PlayerSupervisor.start_player(player_id,
               id: player_id,
               handler_pid: handler_pid,
               position: %Position{
                 zone_id: spawn.zone_id,
                 x: spawn.x,
                 y: spawn.y,
                 world_x: spawn.x,
                 world_y: spawn.y,
                 facing: :south
               }
             ) do
          {:ok, _pid} ->
            Logger.info("Player session started: #{player_id}")
            :ok

          {:error, reason} ->
            Logger.error("Failed to start player session for #{player_id}: #{inspect(reason)}")
            {:error, reason}
        end

      {:error, reason} ->
        Logger.error("Failed to reconnect player #{player_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp verify_auth(token, client_hmac, challenge) do
    expected_hmac = :crypto.mac(:hmac, :sha256, token, challenge)

    if :crypto.hash_equals(expected_hmac, client_hmac) do
      case Alembic.Accounts.get_player_by_token(token) do
        {:ok, player} -> {:ok, player.id}
        {:error, _} -> {:error, :invalid_token}
      end
    else
      {:error, :invalid_token}
    end
  end

  defp generate_session_id do
    :crypto.strong_rand_bytes(16)
    |> Base.encode16(case: :lower)
  end

  defp send_world_sync(player_id, socket) do
    player = Player.get_state(player_id)
    position = player.position

    case position do
      %Position{room_id: nil, zone_id: zone_id} ->
        case Registry.lookup(Alembic.Registry.ZoneRegistry, zone_id) do
          [{_pid, _}] ->
            zone = Zone.get_state(zone_id)
            send_packet(socket, Encoder.zone_info(zone.id, zone.name, zone.width, zone.height))

            send_packet(
              socket,
              Encoder.spawn_position(
                zone_id,
                position.x,
                position.y,
                position.world_x,
                position.world_y,
                position.facing
              )
            )

            Zone.player_enter(zone_id, player_id, position.x, position.y)
            viewport = Zone.get_viewport(zone_id, position.x, position.y)
            send_packet(socket, Encoder.viewport_update(viewport))

          [] ->
            Logger.error("World sync failed: zone #{zone_id} not found for player #{player_id}")
        end

      %Position{room_id: room_id, zone_id: _zone_id} ->
        case Registry.lookup(Alembic.Registry.RoomRegistry, room_id) do
          [{_pid, _}] ->
            room = Room.get_state(room_id)
            send_packet(socket, Encoder.room_info(room.id, room.name, room.width, room.height))

            send_packet(
              socket,
              Encoder.spawn_position(
                room_id,
                position.x,
                position.y,
                position.world_x,
                position.world_y,
                position.facing
              )
            )

            viewport = Room.get_viewport(room_id, position.x, position.y)
            send_packet(socket, Encoder.viewport_update(viewport))

          [] ->
            Logger.error("World sync failed: room #{room_id} not found for player #{player_id}")
        end
    end

    Logger.info("World sync sent to player #{player_id}")
  end

  defp extract_packets(buffer) do
    extract_packets(buffer, [])
  end

  defp extract_packets(
         <<0x41, 0x4C, 0x42, 0x43, _version::24, _packet_id::16, length::32,
           _payload::binary-size(length), _rest::binary>> = buffer,
         packets
       ) do
    header_size = 13
    packet_size = header_size + length
    <<packet::binary-size(packet_size), remaining::binary>> = buffer

    case Decoder.decode(packet) do
      {:ok, decoded, _} ->
        extract_packets(remaining, [decoded | packets])

      other ->
        Logger.error("Failed to decode packet: #{inspect(other)}, raw: #{Base.encode16(packet)}")
        {Enum.reverse(packets), remaining}
    end
  end

  defp extract_packets(remaining, packets) do
    Logger.debug("extract_packets base case hit, buffer: #{Base.encode16(remaining)}")
    {Enum.reverse(packets), remaining}
  end

  defp send_packet(socket, packet) do
    :gen_tcp.send(socket, packet)
  end
end
