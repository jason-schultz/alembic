defmodule Alembic.Entity.Base do
  @moduledoc """
  Base module for entity GenServers (Player, Mob, NPC).

  Provides common GenServer callbacks and client API functions.
  """

  defmacro __using__(opts) do
    registry = Keyword.fetch!(opts, :registry)

    quote do
      use GenServer
      require Logger

      alias Alembic.Entity.Position

      # Client API - shared across all entities

      def start_link(opts) do
        id = Keyword.fetch!(opts, :id)
        GenServer.start_link(__MODULE__, opts, name: via_tuple(id))
      end

      def get_state(entity_id) do
        GenServer.call(via_tuple(entity_id), :get_state)
      end

      def move(entity_id, direction) when direction in [:north, :south, :east, :west] do
        GenServer.call(via_tuple(entity_id), {:move, direction})
      end

      def set_position(entity_id, %Position{} = position) do
        GenServer.call(via_tuple(entity_id), {:set_position, position})
      end

      # Server Callbacks - shared across all entities

      @impl true
      def handle_call(:get_state, _from, state) do
        {:reply, state, state}
      end

      @impl true
      def handle_call({:move, direction}, _from, state) do
        new_position = Position.move(state.position, direction)

        # Validate with zone - child module can override
        case validate_move(state, new_position) do
          :ok ->
            new_state = %{state | position: new_position}
            {:reply, {:ok, new_position}, new_state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
      end

      @impl true
      def handle_call({:set_position, position}, _from, state) do
        new_state = %{state | position: position}
        {:reply, :ok, new_state}
      end

      # Private

      def via_tuple(entity_id) do
        {:via, Registry, {unquote(registry), entity_id}}
      end

      # Default validation - child modules SHOULD override
      # Returns :ok | {:error, String.t()}
      @spec validate_move(any(), Position.t()) :: :ok | {:error, String.t()}
      defp validate_move(_state, %Position{} = position) do
        # Basic validation: coordinates must be non-negative
        # Child modules should override to check with Zone
        if position.x >= 0 and position.y >= 0 do
          :ok
        else
          {:error, "Invalid coordinates"}
        end
      end

      # Allow child modules to override
      defoverridable validate_move: 2
    end
  end
end
