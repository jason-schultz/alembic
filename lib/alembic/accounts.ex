defmodule Alembic.Accounts do
  @moduledoc """
  Handles player authentication and account management.
  TODO: Replace stub with real database lookup.
  """

  @doc """
  Gets a player by their auth token.
  Currently a stub - replace with real DB lookup.
  """
  def get_player_by_token(token) do
    # TODO: Replace with real database lookup
    # Ecto.Repo.get_by(Player, token: token)

    # Stub: accept any token for development
    {:ok, %{id: Base.encode16(token, case: :lower)}}
  end
end
