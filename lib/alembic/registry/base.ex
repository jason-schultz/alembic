defmodule Alembic.Registry.Base do
  @moduledoc """
  A base module for creating registries with shared functionality.

  ## Usage

      defmodule Alembic.Registry.PlayerRegistry do
        use Alembic.Registry.Base, entity_name: :player
      end

  This will inject all common registry functions (lookup, whereis, exists?, etc.)
  and generate entity-specific list functions like `list_player_ids/0`.
  """

  defmacro __using__(opts) do
    entity_name = Keyword.fetch!(opts, :entity_name)
    entity_name_plural = Keyword.get(opts, :entity_name_plural, :"#{entity_name}s")

    quote do
      @registry_name __MODULE__

      @doc """
      Returns the name of the registry.
      """
      def registry_name, do: @registry_name

      @doc """
      Looks up an entity by its ID.

      Returns `{:ok, pid}` if found, `{:error, :not_found}` otherwise.
      """
      def lookup(entity_id) do
        case Registry.lookup(@registry_name, entity_id) do
          [{pid, _}] -> {:ok, pid}
          [] -> {:error, :not_found}
        end
      end

      @doc """
      Looks up an entity by its ID and returns the PID directly.

      Returns the PID if found, `nil` otherwise.
      """
      def whereis(entity_id) do
        case lookup(entity_id) do
          {:ok, pid} -> pid
          {:error, :not_found} -> nil
        end
      end

      @doc """
      Checks if an entity with the given ID exists.
      """
      def exists?(entity_id) do
        case lookup(entity_id) do
          {:ok, _pid} -> true
          {:error, :not_found} -> false
        end
      end

      @doc """
      Lists all registered #{unquote(entity_name)} IDs.
      """
      def unquote(:"list_#{entity_name}_ids")() do
        Registry.select(@registry_name, [{{:"$1", :_, :_}, [], [:"$1"]}])
      end

      @doc """
      Lists all #{unquote(entity_name)} PIDs.
      """
      def unquote(:"list_#{entity_name}_pids")() do
        Registry.select(@registry_name, [{{:_, :"$1", :_}, [], [:"$1"]}])
      end

      @doc """
      Returns the count of registered #{unquote(entity_name_plural)}.
      """
      def count do
        Registry.count(@registry_name)
      end

      @doc """
      Returns a via tuple for the given #{unquote(entity_name)} ID.

      This is useful for GenServer calls when you need to reference a #{unquote(entity_name)}.
      """
      def via_tuple(entity_id) do
        {:via, Registry, {@registry_name, entity_id}}
      end

      # Allow registries to override or add custom functions
      defoverridable lookup: 1, whereis: 1, exists?: 1, count: 0, via_tuple: 1
    end
  end
end
