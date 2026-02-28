defmodule Alembic.Entity.Stats do
  @moduledoc """
  A module for managing entity stats in the Alembic world.

  Stats are the derived values used for combat and gameplay:
  - HP/MP: Health and mana pools
  - Attack/Defense: Combat damage and mitigation
  - Resistances: Damage type specific defenses
  - Combat modifiers: Critical, dodge, accuracy
  """

  @type t :: %__MODULE__{
          hp: non_neg_integer(),
          max_hp: non_neg_integer(),
          mp: non_neg_integer(),
          max_mp: non_neg_integer(),
          attack: non_neg_integer(),
          defense: non_neg_integer(),
          magic_defense: non_neg_integer(),
          fire_resistance: non_neg_integer(),
          ice_resistance: non_neg_integer(),
          lightning_resistance: non_neg_integer(),
          poison_resistance: non_neg_integer(),
          bleed_resistance: non_neg_integer(),
          stun_resistance: non_neg_integer(),
          speed: non_neg_integer(),
          critical_chance: float(),
          critical_multiplier: float(),
          dodge_chance: float(),
          accuracy: float()
        }

  defstruct hp: 100,
            max_hp: 100,
            mp: 50,
            max_mp: 50,
            attack: 10,
            defense: 5,
            magic_defense: 5,
            fire_resistance: 0,
            ice_resistance: 0,
            lightning_resistance: 0,
            poison_resistance: 0,
            bleed_resistance: 0,
            stun_resistance: 0,
            speed: 10,
            critical_chance: 0.05,
            critical_multiplier: 1.5,
            dodge_chance: 0.05,
            accuracy: 0.95

  @doc """
  Creates a new stats struct with the given values.

  ## Examples

      iex> Stats.new(hp: 150, max_hp: 150, attack: 20)
      %Stats{hp: 150, max_hp: 150, attack: 20, ...}
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    struct(__MODULE__, opts)
  end

  @doc """
  Returns true if the entity has any HP remaining.
  """
  @spec alive?(t()) :: boolean()
  def alive?(%__MODULE__{hp: hp}), do: hp > 0

  @doc """
  Returns the HP as a percentage of max HP (0.0 to 1.0).

  ## Examples

      iex> stats = %Stats{hp: 50, max_hp: 100}
      iex> Stats.hp_percent(stats)
      0.5
  """
  @spec hp_percent(t()) :: float()
  def hp_percent(%__MODULE__{hp: hp, max_hp: max_hp}) when max_hp > 0 do
    hp / max_hp
  end

  def hp_percent(%__MODULE__{}), do: 0.0

  @doc """
  Returns the MP as a percentage of max MP (0.0 to 1.0).
  """
  @spec mp_percent(t()) :: float()
  def mp_percent(%__MODULE__{mp: mp, max_mp: max_mp}) when max_mp > 0 do
    mp / max_mp
  end

  def mp_percent(%__MODULE__{}), do: 0.0
end
