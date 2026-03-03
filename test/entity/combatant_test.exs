defmodule Alembic.Test.Entity.CombatantTest do
  use ExUnit.Case, async: true

  alias Alembic.Entity.Combatant
  alias Alembic.Entity.{Player, Mob, Stats, Equipment}

  # ============================================================
  # Test Helpers
  # ============================================================

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
    Map.merge(
      %Player{
        id: "test_player",
        name: "Test Hero",
        stats: base_stats(),
        equipment: %Equipment{weapon_one: nil, weapon_two: nil}
      },
      overrides
    )
  end

  defp build_mob(overrides \\ %{}) do
    Map.merge(
      %Mob{
        id: "test_mob",
        name: "Test Mob",
        stats: base_stats()
      },
      overrides
    )
  end

  defp damage(amount, type) do
    %{amount: amount, damage_type: type}
  end

  defp weapon(attack_bonus), do: %{attack_bonus: attack_bonus}

  # ============================================================
  # take_damage/2 - Player
  # ============================================================

  describe "take_damage/2 - Player" do
    test "applies physical damage mitigated by defense" do
      player = build_player()
      # 20 physical - 5 defense = 15 damage
      result = Combatant.take_damage(player, [damage(20, :physical)])
      assert result.stats.hp == 85
    end

    test "applies magical damage mitigated by magic_defense" do
      player = build_player()
      # 15 magic - 5 magic_defense = 10 damage
      result = Combatant.take_damage(player, [damage(15, :magical)])
      assert result.stats.hp == 90
    end

    test "applies elemental damage mitigated by resistance" do
      player = build_player()
      # 10 fire - 3 fire_resistance = 7 damage
      result = Combatant.take_damage(player, [damage(10, :fire)])
      assert result.stats.hp == 93
    end

    test "damage is 0 when resistance fully absorbs damage" do
      player = build_player(%{stats: base_stats(%{resistances: %{fire: 50}})})
      # 5 fire - 50 resistance = fully resisted = 0 damage
      result = Combatant.take_damage(player, [damage(5, :fire)])
      assert result.stats.hp == 100
    end

    test "damage is minimum 1 when partially resisted to near zero" do
      player = build_player(%{stats: base_stats(%{resistances: %{fire: 50}})})
      # 51 fire - 50 resistance = 1 damage
      result = Combatant.take_damage(player, [damage(51, :fire)])
      assert result.stats.hp == 99
    end

    test "applies multi-type damage (fire sword: physical + fire)" do
      player = build_player()
      # 10 physical - 5 defense = 5
      # 2 fire - 3 fire_resistance = fully resisted = 0
      # total = 5 damage
      result = Combatant.take_damage(player, [damage(10, :physical), damage(2, :fire)])
      assert result.stats.hp == 95
    end

    test "applies multi-type damage where all components deal damage" do
      player = build_player()
      # 10 physical - 5 defense = 5
      # 10 fire - 3 fire_resistance = 7
      # total = 12 damage
      result = Combatant.take_damage(player, [damage(10, :physical), damage(10, :fire)])
      assert result.stats.hp == 88
    end

    test "hp cannot go below 0" do
      player = build_player(%{stats: base_stats(%{hp: 10})})
      result = Combatant.take_damage(player, [damage(1000, :physical)])
      assert result.stats.hp == 0
    end

    test "damage type with no resistance uses full amount" do
      player = build_player()
      # :arcane has no resistance entry, so 0 resistance
      result = Combatant.take_damage(player, [damage(15, :arcane)])
      assert result.stats.hp == 85
    end

    test "empty damage list does not change hp" do
      player = build_player()
      result = Combatant.take_damage(player, [])
      assert result.stats.hp == 100
    end

    test "invalid damage components returns entity unchanged" do
      player = build_player()
      result = Combatant.take_damage(player, {10, :physical})
      assert result == player
    end

    test "nil damage components returns entity unchanged" do
      player = build_player()
      result = Combatant.take_damage(player, nil)
      assert result == player
    end
  end

  # ============================================================
  # take_damage/2 - Mob
  # ============================================================

  describe "take_damage/2 - Mob" do
    test "applies physical damage mitigated by defense" do
      mob = build_mob()
      # 20 physical - 5 defense = 15 damage
      result = Combatant.take_damage(mob, [damage(20, :physical)])
      assert result.stats.hp == 85
    end

    test "applies magical damage mitigated by magic_defense" do
      mob = build_mob()
      # 15 magic - 5 magic_defense = 10 damage
      result = Combatant.take_damage(mob, [damage(15, :magical)])
      assert result.stats.hp == 90
    end

    test "applies elemental damage mitigated by resistance" do
      mob = build_mob()
      # 10 fire - 3 fire_resistance = 7 damage
      result = Combatant.take_damage(mob, [damage(10, :fire)])
      assert result.stats.hp == 93
    end

    test "damage is 0 when resistance fully absorbs damage" do
      mob = build_mob(%{stats: base_stats(%{resistances: %{fire: 50}})})
      # 5 fire - 50 resistance = fully resisted = 0 damage
      result = Combatant.take_damage(mob, [damage(5, :fire)])
      assert result.stats.hp == 100
    end

    test "applies multi-type damage (fire sword: physical + fire)" do
      mob = build_mob()
      # 10 physical - 5 defense = 5
      # 2 fire - 3 fire_resistance = fully resisted = 0
      # total = 5 damage
      result = Combatant.take_damage(mob, [damage(10, :physical), damage(2, :fire)])
      assert result.stats.hp == 95
    end

    test "hp cannot go below 0" do
      mob = build_mob(%{stats: base_stats(%{hp: 10})})
      result = Combatant.take_damage(mob, [damage(1000, :physical)])
      assert result.stats.hp == 0
    end
  end

  # ============================================================
  # heal/2
  # ============================================================

  describe "heal/2" do
    test "heal increases hp by amount" do
      player = build_player(%{stats: base_stats(%{hp: 50})})
      result = Combatant.heal(player, 20)
      assert result.stats.hp == 70
    end

    test "heal cannot exceed max_hp" do
      player = build_player(%{stats: base_stats(%{hp: 90})})
      result = Combatant.heal(player, 100)
      assert result.stats.hp == 100
    end

    test "heal on full hp does not change hp" do
      player = build_player()
      result = Combatant.heal(player, 50)
      assert result.stats.hp == 100
    end

    test "heal works on mob" do
      mob = build_mob(%{stats: base_stats(%{hp: 50})})
      result = Combatant.heal(mob, 30)
      assert result.stats.hp == 80
    end

    test "heal on dead entity restores hp" do
      player = build_player(%{stats: base_stats(%{hp: 0})})
      result = Combatant.heal(player, 50)
      assert result.stats.hp == 50
    end
  end

  # ============================================================
  # is_alive?/1
  # ============================================================

  describe "is_alive?/1" do
    test "returns true when hp > 0" do
      player = build_player()
      assert Combatant.is_alive?(player) == true
    end

    test "returns false when hp == 0" do
      player = build_player(%{stats: base_stats(%{hp: 0})})
      assert Combatant.is_alive?(player) == false
    end

    test "returns false after lethal damage" do
      player = build_player(%{stats: base_stats(%{hp: 5})})
      result = Combatant.take_damage(player, [damage(1000, :physical)])
      assert Combatant.is_alive?(result) == false
    end

    test "returns true after non-lethal damage" do
      player = build_player()
      result = Combatant.take_damage(player, [damage(10, :physical)])
      assert Combatant.is_alive?(result) == true
    end

    test "works for mob" do
      mob = build_mob()
      assert Combatant.is_alive?(mob) == true

      dead_mob = build_mob(%{stats: base_stats(%{hp: 0})})
      assert Combatant.is_alive?(dead_mob) == false
    end
  end

  # ============================================================
  # attack_power/1
  # ============================================================

  describe "attack_power/1" do
    test "player with no weapons uses stats.attack only" do
      player = build_player()
      # stats.attack = 10, no weapons
      assert Combatant.attack_power(player) == 10
    end

    test "player with one weapon adds weapon attack bonus" do
      player =
        build_player(%{
          equipment: %Equipment{weapon_one: weapon(15), weapon_two: nil}
        })

      # stats.attack (10) + weapon_one bonus (15) = 25
      assert Combatant.attack_power(player) == 25
    end

    test "player with two weapons adds both weapon bonuses" do
      player =
        build_player(%{
          equipment: %Equipment{weapon_one: weapon(15), weapon_two: weapon(10)}
        })

      # stats.attack (10) + weapon_one (15) + weapon_two (10) = 35
      assert Combatant.attack_power(player) == 35
    end

    test "mob attack power uses stats.attack directly" do
      mob = build_mob()
      assert Combatant.attack_power(mob) == 10
    end

    test "mob with higher attack stat returns correct value" do
      mob = build_mob(%{stats: base_stats(%{attack: 50})})
      assert Combatant.attack_power(mob) == 50
    end
  end
end
