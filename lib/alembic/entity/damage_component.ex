defmodule Alembic.Entity.DamageComponent do
  @moduledoc """
  A struct representing a single component of damage.

  Used for multi-type damage scenarios like a fire sword that does
  both physical and fire damage. Each component has an amount and type.

  ## Examples

      # Fire sword attack
      [
        %DamageComponent{amount: 10, damage_type: :physical},
        %DamageComponent{amount: 2, damage_type: :fire}
      ]
  """

  alias Alembic.Entity.DamageType

  @type t :: %__MODULE__{
          amount: non_neg_integer(),
          damage_type: DamageType.damage_type()
        }

  defstruct amount: 0,
            damage_type: :physical

  @doc """
  Creates a new damage component.

  ## Examples

      iex> DamageComponent.new(10, :physical)
      %DamageComponent{amount: 10, damage_type: :physical}

      iex> DamageComponent.new(5, :fire)
      %DamageComponent{amount: 5, damage_type: :fire}
  """
  @spec new(non_neg_integer(), DamageType.damage_type()) :: t()
  def new(amount, damage_type) when amount >= 0 do
    %__MODULE__{
      amount: amount,
      damage_type: damage_type
    }
  end

  @doc """
  Creates a list of damage components from a keyword list.

  ## Examples

      iex> DamageComponent.from_keyword([physical: 10, fire: 2])
      [
        %DamageComponent{amount: 10, damage_type: :physical},
        %DamageComponent{amount: 2, damage_type: :fire}
      ]
  """
  @spec from_keyword(keyword()) :: list(t())
  def from_keyword(damage_list) do
    Enum.map(damage_list, fn {type, amount} ->
      new(amount, type)
    end)
  end

  @doc """
  Returns the total damage across all components (ignoring type).

  ## Examples

      iex> components = [
      ...>   %DamageComponent{amount: 10, damage_type: :physical},
      ...>   %DamageComponent{amount: 2, damage_type: :fire}
      ...> ]
      iex> DamageComponent.total_damage(components)
      12
  """
  @spec total_damage(list(t())) :: non_neg_integer()
  def total_damage(components) when is_list(components) do
    Enum.reduce(components, 0, fn component, acc ->
      acc + component.amount
    end)
  end
end

defmodule Alembic.Entity.DamageType do
  @moduledoc """
  Defines the different types of damage in the Alembic world.

  Each damage type has corresponding resistance stats on entities.
  """

  @damage_types [:physical, :magical, :fire, :ice, :lightning, :poison, :bleed, :stun]

  @type damage_type :: :physical | :magical | :fire | :ice | :lightning | :poison | :bleed | :stun

  @doc """
  Returns all valid damage types.
  """
  @spec all() :: list(damage_type())
  def all, do: @damage_types

  @doc """
  Returns true if the damage type is valid.
  """
  @spec valid?(atom()) :: boolean()
  def valid?(type), do: type in @damage_types

  @doc """
  Returns the stat name for resistance to the given damage type.

  ## Examples

      iex> DamageType.resistance_stat(:fire)
      :fire_resistance

      iex> DamageType.resistance_stat(:physical)
      :defense
  """
  @spec resistance_stat(damage_type()) :: atom()
  def resistance_stat(:physical), do: :defense
  def resistance_stat(:magical), do: :magic_defense
  def resistance_stat(type) when type in @damage_types, do: :"#{type}_resistance"
end
