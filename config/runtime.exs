import Config

config :alembic,
  worlds_path: System.get_env("ALEMBIC_WORLDS_PATH") || "priv/campaigns",
  asset_port: String.to_integer(System.get_env("ALEMBIC_ASSET_PORT") || "8080"),
  tcp_port: String.to_integer(System.get_env("ALEMBIC_TCP_PORT") || "7777")
