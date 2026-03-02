defmodule Alembic.Network.Acceptor do
  use GenServer
  require Logger

  @port 7777

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    {:ok, socket} =
      :gen_tcp.listen(@port, [:binary, packet: :raw, active: true, reuseaddr: true, nodelay: true])

    Logger.info("Alembic Server listening on port #{@port}")

    # Spawn a separate process for blocking accept loop
    # This frees the GenServer to handle other messages
    spawn_link(fn -> accept_loop(socket) end)
    {:ok, %{socket: socket}}
  end

  def handle_info(:accept, state) do
    {:ok, client} = :gen_tcp.accept(state.socket)
    {:ok, handler} = Alembic.Network.ConnectionHandler.start_link(client)
    :gen_tcp.controlling_process(client, handler)
    send(self(), :accept)
    {:noreply, state}
  end

  def terminate(_reason, %{socket: socket}) do
    Logger.info("Acceptor shutting down, closing listening socket")
    :gen_tcp.close(socket)
  end

  defp accept_loop(socket) do
    case :gen_tcp.accept(socket) do
      {:ok, client} ->
        Logger.info("New connection accepted")

        case DynamicSupervisor.start_child(
               Alembic.Supervisors.ConnectionSupervisor,
               {Alembic.Network.ConnectionHandler, client}
             ) do
          {:ok, handler} ->
            # Transfer socket ownership to the handler process
            :gen_tcp.controlling_process(client, handler)
            Logger.debug("Connection handed off to handler #{inspect(handler)}")

          {:error, reason} ->
            Logger.error("Failed to start connection handler: #{inspect(reason)}")
            :gen_tcp.close(client)
        end

        # Keep accepting new connections
        accept_loop(socket)

      {:error, :closed} ->
        Logger.info("Acceptor socket closed, stopping accept loop")

      {:error, reason} ->
        Logger.error("Accept error: #{inspect(reason)}")
        accept_loop(socket)
    end
  end
end
