defmodule Alembic.Game.GameLoop do
  alias Alembic.Game.CommandParser
  alias Alembic.Supervisors.GameSupervisor

  def start(player_name \\ "Adventurer") do
    IO.puts("\n=== Welcome to Alembic ===\n")

    player_id = "player_#{:erlang.unique_integer([:positive])}"

    {:ok, _} =
      GameSupervisor.start_player(%{
        id: player_id,
        name: player_name,
        position: %Alembic.Entity.Position{current_room_id: "tavern"}
      })

    Alembic.World.Room.add_player("tavern", player_id)

    {:ok, desc} = CommandParser.parse_and_execute(player_id, "look")
    IO.puts(desc <> "\n")

    game_loop(player_id)
  end

  defp game_loop(player_id) do
    IO.write("> ")

    case IO.gets("") do
      :eof ->
        :ok

      input ->
        case CommandParser.parse_and_execute(player_id, String.trim(input)) do
          {:quit, msg} ->
            IO.puts(msg)

          {:ok, ""} ->
            game_loop(player_id)

          {:ok, resp} ->
            IO.puts("\n" <> resp)
            game_loop(player_id)
        end
    end
  end
end
