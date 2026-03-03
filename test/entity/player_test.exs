defmodule Alembic.Test.Entity.PlayerTest do
  use ExUnit.Case, async: false
  require Logger

  alias Alembic.Entity.Player
  alias Alembic.Entity.Stats

  @player_id "test_player_#{:erlang.unique_integer([:positive])}"

  setup do
    # Start a fresh player for each test with a unique id
    player_id = "test_player_#{:erlang.unique_integer([:positive])}"

    {:ok, _pid} =
      Alembic.Supervisors.PlayerSupervisor.start_player(player_id,
        id: player_id,
        name: "Test Hero",
        handler_pid: self()
      )

    on_exit(fn ->
      case Registry.lookup(Alembic.Registry.PlayerRegistry, player_id) do
        [{pid, _}] -> GenServer.stop(pid, :normal)
        [] -> :ok
      end
    end)

    %{player_id: player_id}
  end

  describe "init" do
    test "player initializes with correct id and name", %{player_id: player_id} do
      [{pid, _}] = Registry.lookup(Alembic.Registry.PlayerRegistry, player_id)
      player = :sys.get_state(pid)

      assert player.id == player_id
      assert player.name == "Test Hero"
    end

    test "player initializes with default name when not provided" do
      player_id = "test_player_#{:erlang.unique_integer([:positive])}"

      {:ok, pid} =
        Alembic.Supervisors.PlayerSupervisor.start_player(player_id,
          id: player_id,
          handler_pid: self()
        )

      player = :sys.get_state(pid)
      assert player.name == "Unnamed Hero"

      GenServer.stop(pid, :normal)
    end

    test "player initializes with handler_pid", %{player_id: player_id} do
      [{pid, _}] = Registry.lookup(Alembic.Registry.PlayerRegistry, player_id)
      player = :sys.get_state(pid)

      assert player.handler_pid == self()
    end

    test "player is registered in PlayerRegistry", %{player_id: player_id} do
      result = Registry.lookup(Alembic.Registry.PlayerRegistry, player_id)
      assert match?([{_, _}], result)
    end
  end

  describe "set_handler/2" do
    test "set_handler updates handler_pid with a pid", %{player_id: player_id} do
      new_handler = spawn(fn -> Process.sleep(1000) end)
      Player.set_handler(player_id, new_handler)
      Process.sleep(50)

      [{pid, _}] = Registry.lookup(Alembic.Registry.PlayerRegistry, player_id)
      player = :sys.get_state(pid)

      assert player.handler_pid == new_handler
    end

    test "set_handler clears handler_pid with nil", %{player_id: player_id} do
      Player.set_handler(player_id, nil)
      Process.sleep(50)

      [{pid, _}] = Registry.lookup(Alembic.Registry.PlayerRegistry, player_id)
      player = :sys.get_state(pid)

      assert player.handler_pid == nil
    end

    test "set_handler returns error for non-existent player" do
      result = Player.set_handler("non_existent_player", self())
      assert result == {:error, :not_found}
    end

    test "set_handler nil returns error for non-existent player" do
      result = Player.set_handler("non_existent_player", nil)
      assert result == {:error, :not_found}
    end
  end

  describe "disconnect/1" do
    test "disconnect stops the player GenServer", %{player_id: player_id} do
      [{pid, _}] = Registry.lookup(Alembic.Registry.PlayerRegistry, player_id)
      assert Process.alive?(pid)

      Player.disconnect(player_id)
      Process.sleep(50)

      refute Process.alive?(pid)
    end

    test "disconnect removes player from registry", %{player_id: player_id} do
      Player.disconnect(player_id)
      Process.sleep(50)

      assert Registry.lookup(Alembic.Registry.PlayerRegistry, player_id) == []
    end

    test "disconnect on non-existent player returns :ok" do
      result = Player.disconnect("non_existent_player")
      assert result == :ok
    end
  end
end
