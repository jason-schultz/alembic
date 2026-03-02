defmodule Alembic.Test.Entity.CombatantTest do
  use ExUnit.Case, async: true

  alias Alembic.Entity.{Combatant, DamageComponent, Mob, Player, Stats, Equipment}

  # --- Fixtures ---

  defp base_stats(overrides \\ %{}) do
    Map.merge(
      %Stats{
        hp: 100,
        max_hp: 100,
        mp: 50,
        max_mp: 50,
        attack: 10,
        defense: 5,
        magic_defense: 5,
        speed: 10,
        critical_chance: 0.05,
        critical_multiplier: 1.5,
        dodge_chance: 0.05,
        accuracy: 0.95,
        resistances: %{
          fire: 3,
          ice: 3,
          lightning: 3,
          poison: 2,
          bleed: 2,
          stun: 2
        }
      },
      overrides
    )
  end

  defp build_player(overrides \\ %{}) do
    stats = Map.get(overrides, :stats, base_stats())

    %Player{
      id: "player_1",
      name: "Test Player",
      stats: stats,
      equipment: %Equipment{weapon_one: nil, weapon_two: nil},
      skills: %{},
      inventory: []
    }
  end

  defp build_mob(overrides \\ %{}) do
    stats = Map.get(overrides, :stats, base_stats())

    %Mob{
      id: "mob_1",
      name: "Test Mob",
      stats: stats
    }
  end

  defp damage(amount, type) do
    %DamageComponent{amount: amount, damage_type: type}
  end

  # --- take_damage/2 ---

  describe "take_damage/2 - Player" do
    test "applies physical damage mitigated by defense" do
      player = build_player()
      # 10 physical - 5 defense = 5 damage
      result = Combatant.take_damage(player, [damage(10, :physical)])
      assert result.stats.hp == 95
    end

    test "applies fire damage mitigated by fire_resistance" do
      player = build_player()
      # 10 fire - 3 fire_resistance = 7 damage
      result = Combatant.take_damage(player, [damage(10, :fire)])
      assert result.stats.hp == 93
    end

    test "applies multi-type damage (fire sword: physical + fire)" do
      player = build_player()
      # 10 physical - 5 defense = 5
      # 2 fire - 3 fire_resistance = max(0, -1) = 0
      # total = 5 damage
      result = Combatant.take_damage(player, [damage(10, :physical), damage(2, :fire)])
      assert result.stats.hp == 95
    end

    test "hp does not go below 0" do
      player = build_player(%{stats: base_stats(%{hp: 5})})
      result = Combatant.take_damage(player, [damage(100, :physical)])
      assert result.stats.hp == 0
    end

    test "damage is 0 when resistance exceeds damage amount" do
      player = build_player(%{stats: base_stats(%{resistances: %{fire: 50}})})
      result = Combatant.take_damage(player, [damage(5, :fire)])
      # 5 fire - 50 resistance = max(0, -45) = 0
      assert result.stats.hp == 100
    end

    test "returns error when damage_components is not a list" do
      player = build_player()
      result = Combatant.take_damage(player, damage(10, :physical))
      assert result.stats.hp == player.stats.hp
      assert result == player
    end

    test "applies ice damage mitigated by ice_resistance" do
      player = build_player()
      result = Combatant.take_damage(player, [damage(10, :ice)])
      assert result.stats.hp == 93
    end

    test "applies lightning damage mitigated by lightning_resistance" do
      player = build_player()
      result = Combatant.take_damage(player, [damage(10, :lightning)])
      assert result.stats.hp == 93
    end

    test "applies poison damage mitigated by poison_resistance" do
      player = build_player()
      result = Combatant.take_damage(player, [damage(10, :poison)])
      assert result.stats.hp == 92
    end

    test "applies bleed damage mitigated by bleed_resistance" do
      player = build_player()
      result = Combatant.take_damage(player, [damage(10, :bleed)])
      assert result.stats.hp == 92
    end

    test "applies stun damage mitigated by stun_resistance" do
      player = build_player()
      result = Combatant.take_damage(player, [damage(10, :stun)])
      assert result.stats.hp == 92
    end

    test "applies magical damage mitigated by magic_defense" do
      player = build_player()
      result = Combatant.take_damage(player, [damage(10, :magical)])
      assert result.stats.hp == 95
    end
  end

  describe "take_damage/2 - Mob" do
    test "applies physical damage mitigated by defense" do
      mob = build_mob()
      result = Combatant.take_damage(mob, [damage(10, :physical)])
      assert result.stats.hp == 95
    end

    test "applies fire damage mitigated by fire_resistance" do
      mob = build_mob()
      result = Combatant.take_damage(mob, [damage(10, :fire)])
      assert result.stats.hp == 93
    end

    test "applies multi-type damage (fire sword: physical + fire)" do
      mob = build_mob()
      result = Combatant.take_damage(mob, [damage(10, :physical), damage(2, :fire)])
      assert result.stats.hp == 95
    end

    test "hp does not go below 0" do
      mob = build_mob(%{stats: base_stats(%{hp: 5})})
      result = Combatant.take_damage(mob, [damage(100, :physical)])
      assert result.stats.hp == 0
    end

    test "returns error when damage_components is not a list" do
      mob = build_mob()
      result = Combatant.take_damage(mob, damage(10, :physical))
      assert result.stats.hp == mob.stats.hp
      assert result == mob
    end
  end

  # --- heal/2 ---

  describe "heal/2" do
    test "heals player by given amount" do
      player = build_player(%{stats: base_stats(%{hp: 50})})
      result = Combatant.heal(player, 20)
      assert result.stats.hp == 70
    end

    test "heal does not exceed max_hp for player" do
      player = build_player(%{stats: base_stats(%{hp: 95})})
      result = Combatant.heal(player, 20)
      assert result.stats.hp == 100
    end

    test "heals mob by given amount" do
      mob = build_mob(%{stats: base_stats(%{hp: 50})})
      result = Combatant.heal(mob, 20)
      assert result.stats.hp == 70
    end

    test "heal does not exceed max_hp for mob" do
      mob = build_mob(%{stats: base_stats(%{hp: 95})})
      result = Combatant.heal(mob, 20)
      assert result.stats.hp == 100
    end
  end

  # --- is_alive?/1 ---

  describe "is_alive?/1" do
    test "returns true when player hp > 0" do
      player = build_player()
      assert Combatant.is_alive?(player)
    end

    test "returns false when player hp is 0" do
      player = build_player(%{stats: base_stats(%{hp: 0})})
      refute Combatant.is_alive?(player)
    end

    test "returns true when mob hp > 0" do
      mob = build_mob()
      assert Combatant.is_alive?(mob)
    end

    test "returns false when mob hp is 0" do
      mob = build_mob(%{stats: base_stats(%{hp: 0})})
      refute Combatant.is_alive?(mob)
    end
  end

  # --- attack_power/1 ---

  describe "attack_power/1" do
    test "returns base attack for player with no weapons" do
      player = build_player()
      assert Combatant.attack_power(player) == 10
    end

    test "includes weapon_one attack bonus for player" do
      weapon = %{attack_bonus: 5}
      player = build_player()
      player = %{player | equipment: %{player.equipment | weapon_one: weapon}}
      assert Combatant.attack_power(player) == 15
    end

    test "includes both weapon bonuses for dual wielding player" do
      weapon_one = %{attack_bonus: 5}
      weapon_two = %{attack_bonus: 3}
      player = build_player()

      player = %{
        player
        | equipment: %{player.equipment | weapon_one: weapon_one, weapon_two: weapon_two}
      }

      assert Combatant.attack_power(player) == 18
    end

    test "returns base attack stat for mob" do
      mob = build_mob()
      assert Combatant.attack_power(mob) == 10
    end
  end
end
