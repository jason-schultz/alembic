defmodule Alembic.Entity.Attributes do
  @moduledoc """
  A module for managing entity attributes in the Alembic world.

  Attributes are the core stats that define an entity's capabilities:
  - Strength: Physical power, melee damage
  - Dexterity: Agility, accuracy, dodge
  - Constitution: Health, stamina, physical resistance
  - Intelligence: Magical power, mana pool
  - Wisdom: Magical resistance, perception
  - Charisma: Social interactions, merchant prices
  """

  @type t :: %__MODULE__{
          strength: non_neg_integer(),
          dexterity: non_neg_integer(),
          constitution: non_neg_integer(),
          intelligence: non_neg_integer(),
          wisdom: non_neg_integer(),
          charisma: non_neg_integer()
        }

  defstruct strength: 10,
            dexterity: 10,
            constitution: 10,
            intelligence: 10,
            wisdom: 10,
            charisma: 10

  @doc """
  Creates a new set of attributes with the given values.

  ## Examples

      iex> Attributes.new(strength: 15, dexterity: 12)
      %Attributes{strength: 15, dexterity: 12, constitution: 10, ...}
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      strength: Keyword.get(opts, :strength, 10),
      dexterity: Keyword.get(opts, :dexterity, 10),
      constitution: Keyword.get(opts, :constitution, 10),
      intelligence: Keyword.get(opts, :intelligence, 10),
      wisdom: Keyword.get(opts, :wisdom, 10),
      charisma: Keyword.get(opts, :charisma, 10)
    }
  end

  @doc """
  Calculates the attribute modifier (D&D style: (attribute - 10) / 2).
  Used for derived stat calculations.

  ## Examples

      iex> Attributes.modifier(16)
      3

      iex> Attributes.modifier(8)
      -1
  """
  @spec modifier(non_neg_integer()) :: integer()
  def modifier(attribute_value) do
    div(attribute_value - 10, 2)
  end

  @doc """
  Applies a temporary buff/debuff to attributes.
  Returns a new Attributes struct with modified values.

  ## Examples

      iex> attrs = %Attributes{strength: 10}
      iex> Attributes.apply_modifier(attrs, :strength, 5)
      %Attributes{strength: 15, ...}
  """
  @spec apply_modifier(t(), atom(), integer()) :: t()
  def apply_modifier(%__MODULE__{} = attrs, attribute, modifier) do
    current_value = Map.get(attrs, attribute)
    # Attributes can't go below 1
    new_value = max(1, current_value + modifier)
    Map.put(attrs, attribute, new_value)
  end
end
