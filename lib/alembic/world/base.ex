defmodule Alembic.World.Base do
  @moduledoc """
  Base module for world GenServers (Zone, Room).

  Provides common GenServer callbacks and client API functions for
  managing tile grids, player positions, and viewport rendering.
  """

  defmacro __using__(opts) do
    registry = Keyword.fetch!(opts, :registry)
    viewport_width = Keyword.get(opts, :viewport_width, 20)
    viewport_height = Keyword.get(opts, :viewport_height, 12)
    tick_interval = Keyword.get(opts, :tick_interval, 100)

    quote do
      use GenServer
      require Logger

      alias Alembic.World.Tile
      alias Alembic.Serialization.ClientPayload

      @viewport_width unquote(viewport_width)
      @viewport_height unquote(viewport_height)
      @tick_interval unquote(tick_interval)

      # Client API - shared across Zone and Room

      @doc """
      Starts the GenServer for the given world data.
      """
      def start_link(world_data) do
        GenServer.start_link(__MODULE__, world_data, name: via_tuple(world_data.id))
      end

      @doc """
      Returns the full state. Primarily for debugging/GM use.
      """
      def get_state(world_id) do
        GenServer.call(via_tuple(world_id), :get_state)
      end

      @doc """
      Returns the world's offset coordinates (for zones/rooms that track world position).
      """
      def get_world_offset(world_id) do
        GenServer.call(via_tuple(world_id), :get_world_offset)
      end

      @doc """
      Returns the viewport tiles and entities surrounding the given position.
      """
      def get_viewport(world_id, x, y) do
        GenServer.call(via_tuple(world_id), {:get_viewport, x, y})
      end

      @doc """
      Adds a player to the world at the given position.
      """
      def player_enter(world_id, player_id, x, y) do
        GenServer.cast(via_tuple(world_id), {:player_enter, player_id, x, y})
      end

      @doc """
      Removes a player from the world.
      """
      def player_leave(world_id, player_id) do
        GenServer.cast(via_tuple(world_id), {:player_leave, player_id})
      end

      @doc """
      Moves a player to a new position.
      Validates the move against tile walkability before applying.
      """
      def move_player(world_id, player_id, x, y) do
        GenServer.call(via_tuple(world_id), {:move_player, player_id, x, y})
      end

      # Server Callbacks - shared across Zone and Room

      @impl true
      def init(world_data) do
        Logger.info("#{world_type()} #{world_data.id} (#{world_data.name}) starting...")

        if tick_enabled?() do
          schedule_tick()
        end

        {:ok, world_data}
      end

      @impl true
      def handle_call(:get_state, _from, state) do
        {:reply, state, state}
      end

      @impl true
      def handle_call(:get_world_offset, _from, state) do
        offset = {Map.get(state, :world_offset_x, 0), Map.get(state, :world_offset_y, 0)}
        {:reply, offset, state}
      end

      @impl true
      def handle_call({:get_viewport, x, y}, _from, state) do
        viewport = build_viewport(state, x, y)
        {:reply, viewport, state}
      end

      @impl true
      def handle_call({:move_player, player_id, x, y}, _from, state) do
        case validate_move(state, x, y) do
          :ok ->
            new_state = update_player_position(state, player_id, x, y)
            broadcast_viewport(new_state, player_id, x, y)
            {:reply, :ok, new_state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
      end

      @impl true
      def handle_cast({:player_enter, player_id, x, y}, state) do
        Logger.info("Player #{player_id} entered #{world_type()} #{state.id} at (#{x}, #{y})")
        new_players = Map.put(state.players, player_id, {x, y})
        new_state = %{state | players: new_players}
        broadcast_viewport(new_state, player_id, x, y)
        {:noreply, new_state}
      end

      @impl true
      def handle_cast({:player_leave, player_id}, state) do
        Logger.info("Player #{player_id} left #{world_type()} #{state.id}")
        new_players = Map.delete(state.players, player_id)
        {:noreply, %{state | players: new_players}}
      end

      @impl true
      def handle_info(:tick, state) do
        new_state = process_tick(state)
        schedule_tick()
        {:noreply, new_state}
      end

      # Private helpers - shared logic

      defp via_tuple(world_id) do
        {:via, Registry, {unquote(registry), world_id}}
      end

      defp schedule_tick do
        Process.send_after(self(), :tick, @tick_interval)
      end

      defp validate_move(state, x, y) do
        cond do
          x < 0 or x >= state.width -> {:error, "Position out of bounds"}
          y < 0 or y >= state.height -> {:error, "Position out of bounds"}
          not Tile.walkable?(get_tile(state, x, y)) -> {:error, "Tile is not walkable"}
          true -> :ok
        end
      end

      defp update_player_position(state, player_id, x, y) do
        %{state | players: Map.put(state.players, player_id, {x, y})}
      end

      defp get_tile(state, x, y) do
        Map.get(state.tiles, {x, y}, %Tile{
          x: x,
          y: y,
          texture_id: "void",
          type: :void,
          walkable: false
        })
      end

      defp build_viewport(state, center_x, center_y) do
        half_w = div(@viewport_width, 2)
        half_h = div(@viewport_height, 2)

        tiles =
          for x <- (center_x - half_w)..(center_x + half_w),
              y <- (center_y - half_h)..(center_y + half_h),
              x >= 0 and x < state.width,
              y >= 0 and y < state.height do
            state
            |> get_tile(x, y)
            |> ClientPayload.to_payload()
          end

        entities =
          state.players
          |> Enum.filter(fn {_id, {px, py}} ->
            abs(px - center_x) <= half_w and abs(py - center_y) <= half_h
          end)
          |> Enum.map(fn {id, {px, py}} ->
            %{type: :player, id: id, x: px, y: py}
          end)

        %{
          tiles: tiles,
          entities: entities,
          center: %{x: center_x, y: center_y}
        }
      end

      defp broadcast_viewport(state, player_id, x, y) do
        viewport = build_viewport(state, x, y)
        # TODO: wire up to PlayerChannel when network layer is built
        Logger.debug(
          "Broadcasting viewport to player #{player_id} in #{world_type()} #{state.id}"
        )
      end

      # Default implementations - child modules can override

      defp process_tick(state) do
        # Default: no-op tick processing
        # Zones override to handle mob AI, spawns, etc.
        # Rooms might not need ticking at all
        state
      end

      defp world_type do
        # Default: extract from module name (Zone or Room)
        __MODULE__
        |> Module.split()
        |> List.last()
      end

      defp tick_enabled? do
        # Default: ticking is enabled
        # Rooms might override to return false
        true
      end

      # Allow child modules to override
      defoverridable process_tick: 1, world_type: 0, tick_enabled?: 0
    end
  end
end
