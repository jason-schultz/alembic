March 7, 2026
Added get_handler/1 to Player using GenServer.call instead of :sys.get_state
Removed dead code: GameSupervisor, GameLoop, CommandParser, Commands, Movement, Combat, Endpoint, Message, PlayerChannel
Fixed Accounts duplicate function clause
Added zone_info, room_info, spawn_position packet macros (0x0200, 0x0201, 0x0202)
Added room_id field to Position struct for zone vs room routing
Wired player movement through Zone.move_player_facing and Room.move_player_facing
Added move_player_facing to Zone with tile-based transition detection
Added broadcast_to_others to Zone using registry lookup instead of stored pids
Built CampaignLoader — reads and parses priv/campaigns/<id>/campaign.json at boot
Added zone_definitions and room_definitions to World.Server state for on-demand loading
Fixed World.Server.init to start real Zone and Room processes from loaded structs
Fixed World.Server time tick bug (was sending unhandled message instead of advancing time directly)
Added get_spawn_position to World.Server
Fixed viewport_update encoder to use texture_id instead of asset_id
Added zone_info, room_info, spawn_position, viewport_update encoder functions with proper binary encoding (replacing :erlang.term_to_binary)
Implemented send_world_sync in ConnectionHandler — sends zone/room info, spawn position, and viewport tiles to client after successful auth
Campaign main_story now loads and boots successfully with real world data