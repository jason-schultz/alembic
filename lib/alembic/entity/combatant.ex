defprotocol Alembic.Entity.Combatant do
  @moduledoc """
  A protocol for entities that can engage in combat. This includes players, NPCs, and monsters.
  """

  @doc """
  Applies damage to the entity based on the provided damage components. Each component is mitigated by the entity's stats.
  """
  def take_damage(entity, damage_components)
  def heal(entity, amount)
  def is_alive?(entity)
  def attack_power(entity)
end

defimpl Alembic.Entity.Combatant, for: [Alembic.Entity.Player, Alembic.Entity.Mob] do
  @doc """
  Applies damage to the entity based on the provided damage components. Each component is mitigated by the entity's stats.
  ## Examples

      iex> player = build_player(%{stats: base_stats(%{hp: 100, defense: 5})})
      iex> damage_components = [%DamageComponent{amount: 20, damage_type: :physical}]
      iex> Combatant.take_damage(player, damage_components)
      %Player{stats: %{hp: 85}}

      iex> mob = build_mob(%{stats: base_stats(%{hp: 50, magic_defense: 3})})
      iex> damage_components = [%DamageComponent{amount: 10, damage_type: :magic}]
      iex> Combatant.take_damage(mob, damage_components)
      %Mob{stats: %{hp: 43}}
  """
  def take_damage(entity, damage_components) when is_list(damage_components) do
    handle_take_damage(entity, damage_components)
  end

  # Just return the entity unchanged if damage_components is not a list (invalid input)
  def take_damage(entity, _damage_components), do: entity

  def heal(entity, amount) do
    new_hp = min(entity.stats.hp + amount, entity.stats.max_hp)
    %{entity | stats: %{entity.stats | hp: new_hp}}
  end

  def is_alive?(entity), do: entity.stats.hp > 0

  def attack_power(entity) do
    handle_attack_power(entity)
  end

  defp handle_weapon_bonus(nil), do: 0
  defp handle_weapon_bonus(weapon), do: weapon.attack_bonus

  defp handle_attack_power(%Alembic.Entity.Player{} = player) do
    [player.equipment.weapon_one, player.equipment.weapon_two]
    |> Enum.map(&handle_weapon_bonus/1)
    |> Enum.sum()
    |> Kernel.+(player.stats.attack)
  end

  defp handle_attack_power(%Alembic.Entity.Mob{} = mob), do: mob.stats.attack

  defp handle_take_damage(%Alembic.Entity.Player{} = player, damage_components)
       when is_list(damage_components) do
    # Implement player-specific damage logic here (e.g., armor, buffs, dodge, etc)
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

  defp calculate_total_damage(damage_components, %Alembic.Entity.Stats{} = stats) do
    Enum.reduce(damage_components, 0, fn component, acc ->
      acc + calculate_attack_mitigation(component.amount, stats, component.damage_type)
    end)
  end

  defp get_resistance(stats, :physical), do: stats.defense
  defp get_resistance(stats, :magical), do: stats.magic_defense
  defp get_resistance(stats, damage_type), do: Map.get(stats.resistances, damage_type, 0)

  defp calculate_attack_mitigation(amount, stats, damage_type) do
    resistance = get_resistance(stats, damage_type)
    reduced = amount - resistance

    cond do
      resistance >= amount -> 0
      reduced <= 0 -> 1
      true -> reduced
    end
  end
end
