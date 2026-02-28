defprotocol Alembic.Entity.Combatant do
  @moduledoc """
  A protocol for entities that can engage in combat. This includes players, NPCs, and monsters.
  """

  def take_damage(entity, damage_components)
  def heal(entity, amount)
  def is_alive?(entity)
  def attack_power(entity)
end

defimpl Alembic.Entity.Combatant, for: [Alembic.Entity.Player, Alembic.Entity.Mob] do
  def take_damage(entity, damage_components) when is_list(damage_components) do
    handle_take_damage(entity, damage_components)
  end

  def take_damage(_entity, _damage_components) do
    {:error, "Damage component must be a list of Alembic.Entity.DamageComponent structs"}
  end

  def heal(entity, amount) do
    new_hp = min(entity.stats.hp + amount, entity.stats.max_hp)
    %{entity | stats: %{entity.stats | hp: new_hp}}
  end

  def is_alive?(entity), do: entity.stats.hp > 0

  def attack_power(entity) do
    handle_attack_power(entity)
  end

  defp handle_attack_power(%Alembic.Entity.Player{} = player) do
    base = player.stats.attack

    weapon_one_bonus =
      if player.equipment.weapon_one, do: player.equipment.weapon_one.attack_bonus, else: 0

    weapon_two_bonus =
      if player.equipment.weapon_two, do: player.equipment.weapon_two.attack_bonus, else: 0

    base + weapon_one_bonus + weapon_two_bonus
  end

  defp handle_attack_power(%Alembic.Entity.Mob{} = mob), do: mob.stats.attack

  defp handle_take_damage(%Alembic.Entity.Player{} = player, damage_components)
       when is_list(damage_components) do
    # Implement player-specific damage logic here (e.g., armor, buffs)
    total_damage = calculate_total_damage(damage_components, player.stats)
    new_hp = max(0, player.stats.hp - total_damage)
    %{player | stats: %{player.stats | hp: new_hp}}
  end

  defp handle_take_damage(%Alembic.Entity.Mob{} = mob, damage_components)
       when is_list(damage_components) do
    # Implement mob-specific damage logic here (e.g., resistances)
    total_damage = calculate_total_damage(damage_components, mob.stats)
    new_hp = max(0, mob.stats.hp - total_damage)
    %{mob | stats: %{mob.stats | hp: new_hp}}
  end

  defp calculate_attack_mitigation(amount, %Alembic.Entity.Stats{} = stats, :physical) do
    max(1, amount - stats.defense)
  end

  defp calculate_attack_mitigation(amount, %Alembic.Entity.Stats{} = stats, :magical) do
    max(1, amount - stats.magic_defense)
  end

  defp calculate_attack_mitigation(amount, %Alembic.Entity.Stats{} = stats, :fire) do
    max(1, amount - stats.fire_resistance)
  end

  defp calculate_attack_mitigation(amount, %Alembic.Entity.Stats{} = stats, :ice) do
    max(1, amount - stats.ice_resistance)
  end

  defp calculate_attack_mitigation(amount, %Alembic.Entity.Stats{} = stats, :lightning) do
    max(1, amount - stats.lightning_resistance)
  end

  defp calculate_attack_mitigation(amount, %Alembic.Entity.Stats{} = stats, :poison) do
    max(1, amount - stats.poison_resistance)
  end

  defp calculate_attack_mitigation(amount, %Alembic.Entity.Stats{} = stats, :bleed) do
    max(1, amount - stats.bleed_resistance)
  end

  defp calculate_attack_mitigation(amount, %Alembic.Entity.Stats{} = stats, :stun) do
    max(1, amount - stats.stun_resistance)
  end

  defp calculate_total_damage(damage_components, %Alembic.Entity.Stats{} = stats) do
    Enum.reduce(damage_components, 0, fn component, acc ->
      acc + calculate_attack_mitigation(component.amount, stats, component.damage_type)
    end)
  end
end
