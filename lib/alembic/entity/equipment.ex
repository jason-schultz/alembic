defmodule Alembic.Entity.Equipment do
  @moduledoc """
  A module for managing entity equipment in the Alembic world.

  Equipment slots follow a standard RPG layout with support for dual wielding.
  Each slot can hold an item struct with bonuses that affect combat stats.
  """

  @type item :: map() | nil

  @type t :: %__MODULE__{
          head: item(),
          chest: item(),
          left_leg: item(),
          right_leg: item(),
          left_foot: item(),
          right_foot: item(),
          left_hand: item(),
          right_hand: item(),
          weapon_one: item(),
          weapon_two: item(),
          shield: item(),
          accessory1: item(),
          accessory2: item()
        }

  defstruct head: nil,
            chest: nil,
            left_leg: nil,
            right_leg: nil,
            left_foot: nil,
            right_foot: nil,
            left_hand: nil,
            right_hand: nil,
            weapon_one: nil,
            weapon_two: nil,
            shield: nil,
            accessory1: nil,
            accessory2: nil

  @equipment_slots [
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

  @doc """
  Equips an item to the specified slot.

  ## Examples

      iex> equipment = %Equipment{}
      iex> sword = %{name: "Iron Sword", attack_bonus: 5}
      iex> Equipment.equip(equipment, :weapon_one, sword)
      %Equipment{weapon_one: %{name: "Iron Sword", attack_bonus: 5}}
  """
  @spec equip(t(), atom(), map()) :: t()
  def equip(%__MODULE__{} = equipment, slot, item) when slot in @equipment_slots do
    Map.put(equipment, slot, item)
  end

  @doc """
  Unequips an item from the specified slot.

  ## Examples

      iex> equipment = %Equipment{weapon_one: %{name: "Iron Sword"}}
      iex> Equipment.unequip(equipment, :weapon_one)
      %Equipment{weapon_one: nil}
  """
  @spec unequip(t(), atom()) :: t()
  def unequip(%__MODULE__{} = equipment, slot) when slot in @equipment_slots do
    Map.put(equipment, slot, nil)
  end

  @doc """
  Returns the total attack bonus from all equipped weapons.
  Used by Combatant.attack_power/1.

  ## Examples

      iex> equipment = %Equipment{
      ...>   weapon_one: %{attack_bonus: 5},
      ...>   weapon_two: %{attack_bonus: 3}
      ...> }
      iex> Equipment.total_attack_bonus(equipment)
      8
  """
  @spec total_attack_bonus(t()) :: non_neg_integer()
  def total_attack_bonus(%__MODULE__{} = equipment) do
    weapon_one_bonus = get_item_stat(equipment.weapon_one, :attack_bonus)
    weapon_two_bonus = get_item_stat(equipment.weapon_two, :attack_bonus)
    weapon_one_bonus + weapon_two_bonus
  end

  @doc """
  Returns the total defense bonus from all equipped armor.

  ## Examples

      iex> equipment = %Equipment{
      ...>   head: %{defense_bonus: 2},
      ...>   chest: %{defense_bonus: 5}
      ...> }
      iex> Equipment.total_defense_bonus(equipment)
      7
  """
  @spec total_defense_bonus(t()) :: non_neg_integer()
  def total_defense_bonus(%__MODULE__{} = equipment) do
    [:head, :chest, :left_leg, :right_leg, :left_foot, :right_foot]
    |> Enum.map(&get_item_stat(Map.get(equipment, &1), :defense_bonus))
    |> Enum.sum()
  end

  @doc """
  Returns true if the entity is dual wielding weapons.
  """
  @spec dual_wielding?(t()) :: boolean()
  def dual_wielding?(%__MODULE__{weapon_one: w1, weapon_two: w2}) do
    not is_nil(w1) and not is_nil(w2)
  end

  @doc """
  Returns true if the equipment slot is valid.
  """
  @spec valid_slot?(atom()) :: boolean()
  def valid_slot?(slot), do: slot in @equipment_slots

  # Private helpers

  defp get_item_stat(nil, _stat), do: 0
  defp get_item_stat(item, stat), do: Map.get(item, stat, 0)
end
