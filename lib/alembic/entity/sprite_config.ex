defmodule Alembic.Entity.SpriteConfig do
  @moduledoc """
  A module for managing sprite configurations for entities in the Alembic world.

  Defines the visual representation of entities for the Bevy client renderer.
  Includes sprite sheet reference, animation state, and current frame for
  handling sprite animation cycles.
  """

  @type animation_state :: :idle | :walk | :run | :attack | :cast | :hurt | :death

  @type t :: %__MODULE__{
          sprite_sheet: String.t(),
          animation_state: animation_state(),
          frame: non_neg_integer(),
          facing: atom(),
          additional_params: map()
        }

  defstruct sprite_sheet: "default",
            animation_state: :idle,
            frame: 0,
            facing: :south,
            additional_params: %{}

  @animation_states [:idle, :walk, :run, :attack, :cast, :hurt, :death]

  @doc """
  Creates a new sprite configuration.

  ## Examples

      iex> SpriteConfig.new("player_warrior", :idle)
      %SpriteConfig{sprite_sheet: "player_warrior", animation_state: :idle, frame: 0}
  """
  @spec new(String.t(), animation_state(), keyword()) :: t()
  def new(sprite_sheet, animation_state \\ :idle, opts \\ []) do
    %__MODULE__{
      sprite_sheet: sprite_sheet,
      animation_state: animation_state,
      frame: Keyword.get(opts, :frame, 0),
      facing: Keyword.get(opts, :facing, :south),
      additional_params: Keyword.get(opts, :additional_params, %{})
    }
  end

  @doc """
  Sets the animation state and resets the frame counter.

  ## Examples

      iex> config = %SpriteConfig{animation_state: :idle, frame: 5}
      iex> SpriteConfig.set_animation(config, :walk)
      %SpriteConfig{animation_state: :walk, frame: 0}
  """
  @spec set_animation(t(), animation_state()) :: t()
  def set_animation(%__MODULE__{} = config, new_state) when new_state in @animation_states do
    %{config | animation_state: new_state, frame: 0}
  end

  @doc """
  Advances the sprite frame (for animation ticks).

  ## Examples

      iex> config = %SpriteConfig{frame: 2}
      iex> SpriteConfig.next_frame(config)
      %SpriteConfig{frame: 3}
  """
  @spec next_frame(t()) :: t()
  def next_frame(%__MODULE__{frame: frame} = config) do
    %{config | frame: frame + 1}
  end

  @doc """
  Updates the facing direction.
  Typically called when an entity moves or rotates.

  ## Examples

      iex> config = %SpriteConfig{facing: :south}
      iex> SpriteConfig.set_facing(config, :north)
      %SpriteConfig{facing: :north}
  """
  @spec set_facing(t(), atom()) :: t()
  def set_facing(%__MODULE__{} = config, facing) when facing in [:north, :south, :east, :west] do
    %{config | facing: facing}
  end

  @doc """
  Resets the frame counter to 0.
  Useful when looping an animation.
  """
  @spec reset_frame(t()) :: t()
  def reset_frame(%__MODULE__{} = config) do
    %{config | frame: 0}
  end

  @doc """
  Returns true if the animation state is valid.
  """
  @spec valid_animation_state?(atom()) :: boolean()
  def valid_animation_state?(state), do: state in @animation_states
end
