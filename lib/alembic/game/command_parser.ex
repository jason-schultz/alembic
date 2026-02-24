defmodule Alembic.Game.CommandParser do
  @moduledoc """
  Parses and executes player commands.
  """

  alias Alembic.Entity.{Player, NPC}
  alias Alembic.World.Room

  def parse_and_execute(player_id, command_string) do
    command_string
    |> String.trim()
    |> String.downcase()
    |> String.split(" ", parts: 2)
    |> execute_command(player_id)
  end

  defp execute_command(["look"], player_id) do
    player = Player.get_state(player_id)
    room = Room.look(player.position.current_room_id)
    format_room_description(room)
  end

  defp execute_command(["go", direction], player_id) do
    player = Player.get_state(player_id)
    room = Room.look(player.position.current_room_id)

    case Map.get(room.exits, direction) do
      nil ->
        {:ok, "You can't go that way."}

      destination_id ->
        Player.move_to_room(player_id, destination_id)
        new_room = Room.look(destination_id)
        format_room_description(new_room)
    end
  end

  defp execute_command(["talk", target], player_id) do
    player = Player.get_state(player_id)
    room = Room.look(player.position.current_room_id)

    npc_id =
      Enum.find(room.npcs, fn npc_id ->
        npc = NPC.get_state(npc_id)
        String.downcase(npc.name) =~ target
      end)

    case npc_id do
      nil ->
        {:ok, "You don't see '#{target}' here."}

      id ->
        npc = NPC.get_state(id)
        dialogue = NPC.speak(id)
        {:ok, "#{npc.name} says: \"#{dialogue}\""}
    end
  end

  defp execute_command(["inventory" | _], player_id) do
    player = Player.get_state(player_id)
    items = if Enum.empty?(player.inventory), do: "empty", else: Enum.join(player.inventory, ", ")
    {:ok, "Inventory: #{items}"}
  end

  defp execute_command(["stats" | _], player_id) do
    player = Player.get_state(player_id)

    {:ok,
     """
     #{player.name} - Level #{player.level}
     HP: #{player.health}/#{player.max_health}
     STR: #{player.attributes.strength} DEX: #{player.attributes.dexterity} CON: #{player.attributes.constitution}
     """}
  end

  defp execute_command(["help" | _], _) do
    {:ok, "Commands: look, go <dir>, talk <name>, inventory, stats, help, quit"}
  end

  defp execute_command(["quit" | _], _), do: {:quit, "Goodbye!"}
  defp execute_command([cmd | _], _), do: {:ok, "Unknown: '#{cmd}'. Type 'help'."}
  defp execute_command([], _), do: {:ok, ""}

  defp format_room_description(room) do
    exits = Map.keys(room.exits) |> Enum.join(", ")
    npcs = Enum.map(room.npcs, &NPC.get_state(&1).name) |> Enum.join(", ")
    npc_text = if npcs != "", do: "\nYou see: #{npcs}", else: ""

    {:ok, "=== #{room.name} ===\n#{room.description}\nExits: #{exits}#{npc_text}"}
  end
end
