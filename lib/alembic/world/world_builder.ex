defmodule Alembic.World.WorldBuilder do
  @moduledoc """
  Sets up the initial world with rooms.
  """

  alias Alembic.World.Room
  alias Alembic.Entity.NPC
  alias Alembic.Supervisors.GameSupervisor

  @doc """
  Initializes the starting rooms for the game world.
  """
  def setup_world do
    # Define initial rooms
    rooms = [
      %{
        id: "tavern",
        name: "The Rusty Dragon Tavern",
        description:
          "A cozy tavern with warm firelight flickering across wooden tables. The smell of ale and roasted meat fills the air. You can see exits to the north and east.",
        exits: %{
          "north" => "town_square",
          "east" => "back_alley"
        }
      },
      %{
        id: "town_square",
        name: "Town Square",
        description:
          "A bustling town square with a fountain in the center. Merchants hawk their wares from nearby stalls. The tavern lies to the south, and a dark forest looms to the north.",
        exits: %{
          "south" => "tavern",
          "north" => "dark_forest"
        }
      },
      %{
        id: "dark_forest",
        name: "Edge of the Dark Forest",
        description:
          "Twisted trees cast long shadows across the forest floor. Strange sounds echo from deeper within. The town square is to the south, offering safety and warmth.",
        exits: %{
          "south" => "town_square"
        }
      },
      %{
        id: "back_alley",
        name: "Back Alley",
        description:
          "A narrow, dimly lit alley behind the tavern. Crates and barrels are stacked against the walls. The tavern entrance is to the west.",
        exits: %{
          "west" => "tavern"
        }
      }
    ]

    # Start each room as a GenServer process
    Enum.each(rooms, fn room_attrs ->
      {:ok, _pid} = Room.start_link(room_attrs)
    end)

    # Define NPCs
    npcs = [
      %{
        id: "barkeep_rusty_dragon",
        name: "Grimbold the Barkeep",
        description:
          "A stout dwarf with a magnificent grey beard and a friendly smile. His eyes twinkle with mirth as he polishes glasses behind the bar.",
        type: :merchant,
        position: %Alembic.Entity.Position{
          current_room_id: "tavern",
          facing: :south
        },
        dialogue: [
          "Welcome to the Rusty Dragon! What'll it be?",
          "Finest ale this side of the mountains, guaranteed!",
          "I've been keepin' this tavern for nigh on forty years now.",
          "If you're lookin' for adventure, try the town square. Always somethin' happenin' there.",
          "That old forest to the north? Best stay away from there after dark, friend."
        ],
        inventory: ["ale", "bread", "cheese", "health potion"],
        hostile: false
      },
      %{
        id: "patron_ale_drinker",
        name: "Weathered Patron",
        description:
          "A middle-aged human slumped over the bar, nursing a mug of ale. Their clothes are worn from travel.",
        type: :ambient,
        position: %Alembic.Entity.Position{
          current_room_id: "tavern",
          facing: :east
        },
        dialogue: [
          "*hiccup* This ale... best in town...",
          "I've seen things in that forest... things I can't unsee...",
          "Leave me be, I'm tryin' to forget.",
          "*mumbles incoherently*",
          "You new 'round here? Word of advice: don't trust the merchants in the square."
        ],
        inventory: ["ale"],
        hostile: false
      }
    ]

    # Start each NPC as a GenServer process
    Enum.each(npcs, fn npc_attrs ->
      {:ok, _pid} = GameSupervisor.start_npc(npc_attrs)
    end)

    :ok
  end
end
