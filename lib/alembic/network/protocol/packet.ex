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

  def name(0x0001), do: :handshake_request
  def name(0x0002), do: :handshake_response
  def name(0x0010), do: :auth_request
  def name(0x0011), do: :auth_success
  def name(0x0012), do: :auth_failure
  def name(0x0020), do: :session_ready
  def name(0x0021), do: :disconnect
  def name(0x0022), do: :heartbeat
  def name(0x0023), do: :heartbeat_ack
  def name(0x0100), do: :player_move
  def name(0x0101), do: :viewport_update
  def name(0x0102), do: :entity_spawn
  def name(0x0103), do: :entity_despawn
  def name(0x0104), do: :entity_move
  def name(0x0105), do: :status_effect
  def name(0x0106), do: :combat_event
  def name(0x0107), do: :chat_message
  def name(id), do: {:unknown, id}
end
