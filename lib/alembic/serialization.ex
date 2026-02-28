defmodule Alembic.Serialization do
  @moduledoc """
  Centralized serialization for sending Elixir structs to the Bevy client.

  Provides a protocol-based approach for converting server-side structs
  to client-friendly maps, stripping server-only metadata.
  """

  defprotocol ClientPayload do
    @doc """
    Converts a struct to a map suitable for sending to the Bevy client.
    """
    def to_payload(struct)
  end

  defimpl ClientPayload, for: Alembic.Entity.Position do
    def to_payload(pos) do
      %{
        zone_id: pos.zone_id,
        x: pos.x,
        y: pos.y,
        facing: pos.facing
        # Note: world_x/world_y NOT sent - client doesn't need it
      }
    end
  end

  defimpl ClientPayload, for: Alembic.World.Tile do
    def to_payload(tile) do
      %{
        x: tile.x,
        y: tile.y,
        texture_id: tile.texture_id,
        type: tile.type,
        walkable: tile.walkable,
        elevation: tile.elevation
      }
    end
  end

  defimpl ClientPayload, for: Alembic.Entity.Stats do
    def to_payload(stats) do
      %{
        hp: stats.hp,
        max_hp: stats.max_hp,
        mp: stats.mp,
        max_mp: stats.max_mp,
        attack: stats.attack,
        defense: stats.defense,
        speed: stats.speed
      }
    end
  end

  defimpl ClientPayload, for: Alembic.Entity.Attributes do
    def to_payload(attrs) do
      Map.from_struct(attrs)
    end
  end

  defimpl ClientPayload, for: Alembic.Entity.Equipment do
    def to_payload(equipment) do
      [
        :head,
        :chest,
        :left_leg,
        :right_leg,
        :left_foot,
        :right_foot,
        :left_hand,
        :right_hand,
        :weapon_one,
        :weapon_two,
        :shield,
        :accessory1,
        :accessory2
      ]
      |> Enum.filter(fn slot -> not is_nil(Map.get(equipment, slot)) end)
      |> Enum.into(%{}, fn slot -> {slot, Map.get(equipment, slot)} end)
    end
  end

  defimpl ClientPayload, for: Alembic.Entity.SpriteConfig do
    def to_payload(config) do
      %{
        sprite_sheet: config.sprite_sheet,
        animation_state: config.animation_state,
        frame: config.frame,
        facing: config.facing,
        additional_params: config.additional_params
      }
    end
  end

  defimpl ClientPayload, for: Alembic.Entity.Player do
    def to_payload(player) do
      %{
        id: player.id,
        name: player.name,
        position: ClientPayload.to_payload(player.position),
        stats: ClientPayload.to_payload(player.stats),
        sprite: ClientPayload.to_payload(player.sprite_config)
        # Inventory, skills, etc. sent separately on demand
      }
    end
  end

  defimpl ClientPayload, for: Alembic.Entity.Mob do
    def to_payload(mob) do
      %{
        id: mob.id,
        name: mob.name,
        type: mob.type,
        position: ClientPayload.to_payload(mob.position),
        stats: ClientPayload.to_payload(mob.stats)
      }
    end
  end

  defimpl ClientPayload, for: Alembic.Entity.NPC do
    def to_payload(npc) do
      %{
        id: npc.id,
        name: npc.name,
        type: npc.type,
        position: ClientPayload.to_payload(npc.position)
      }
    end
  end
end
