defmodule Alembic.Network.Protocol.Packet do
  # Handshake
  defmacro handshake_request, do: 0x0001
  defmacro handshake_response, do: 0x0002

  # Auth
  defmacro auth_request, do: 0x0010
  defmacro auth_success, do: 0x0011
  defmacro auth_failure, do: 0x0012

  # Session
  defmacro session_ready, do: 0x0020
  defmacro disconnect, do: 0x0021
  defmacro heartbeat, do: 0x0022
  defmacro heartbeat_ack, do: 0x0023

  # Disconnect reason codes
  # Client requested graceful logout
  defmacro disconnect_logout, do: 0x00
  # Auth or heartbeat timeout
  defmacro disconnect_timeout, do: 0x01
  # Protocol violation
  defmacro disconnect_invalid_packet, do: 0x02
  # Internal server error
  defmacro disconnect_server_error, do: 0x03

  # Game
  defmacro player_move, do: 0x0100
  defmacro viewport_update, do: 0x0101
  defmacro entity_spawn, do: 0x0102
  defmacro entity_despawn, do: 0x0103
  defmacro entity_move, do: 0x0104
  defmacro status_effect, do: 0x0105
  defmacro combat_event, do: 0x0106
  defmacro chat_message, do: 0x0107

  defmacro zone_info, do: 0x0200
  defmacro room_info, do: 0x0201
  defmacro spawn_position, do: 0x0202

  def name(handshake_request()), do: :handshake_request
  def name(handshake_response()), do: :handshake_response
  def name(auth_request()), do: :auth_request
  def name(auth_success()), do: :auth_success
  def name(auth_failure()), do: :auth_failure
  def name(session_ready()), do: :session_ready
  def name(disconnect()), do: :disconnect
  def name(heartbeat()), do: :heartbeat
  def name(heartbeat_ack()), do: :heartbeat_ack
  def name(player_move()), do: :player_move
  def name(viewport_update()), do: :viewport_update
  def name(entity_spawn()), do: :entity_spawn
  def name(entity_despawn()), do: :entity_despawn
  def name(entity_move()), do: :entity_move
  def name(status_effect()), do: :status_effect
  def name(combat_event()), do: :combat_event
  def name(chat_message()), do: :chat_message
  def name(zone_info()), do: :zone_info
  def name(room_info()), do: :room_info
  def name(spawn_position()), do: :spawn_position
  def name(id), do: {:unknown, id}
end
