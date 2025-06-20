--- @param controlling FocusControllablePlayer
local function _0_9_1_player_stop_controlling(controlling)
    local player = controlling.player

    -- Teleport player to proper surface before reassigning controller
    if game.get_surface(controlling.previous_surface_idx) == nil then
        player.print("Previous surface is gone. I don't know where to teleport you")
        player.teleport({0, 0}, "nauvis")
    else
        player.teleport(controlling.previous_position, controlling.previous_surface_idx)
    end

    if controlling.previous_controller == defines.controllers.editor then
        player.toggle_map_editor()
    elseif
        controlling.previous_controller == defines.controllers.character
        or controlling.previous_controller == defines.controllers.remote
    then
        player.set_controller({
            type = defines.controllers.character,
            character = controlling.previous_character
        })
    else
        player.set_controller({type = controlling.previous_controller})
    end

    player.game_view_settings.show_controller_gui = true
    player.game_view_settings.show_entity_tooltip = true
    player.game_view_settings.show_minimap = true
    player.game_view_settings.show_research_info = true
    player.game_view_settings.show_side_menu = true
end

--- @module "state"
local state = require("__item-cam-2__.script.state")
--- @module "utility"
local utility = require("__item-cam-2__.script.utility")
--- @module "focus-behavior"
local focus_behavior = require("__item-cam-2__.script.focus-behavior")

state.retrieve_from_storage()
for player_idx, focus in pairs(state.focuses) do
    local player = game.get_player(player_idx)
    assert(player ~= nil, "player that's being controlled is somehow nil")

    local controlling = utility.first(focus.controlling, function (entry)
        if entry.type == "player" and entry.player == player then
            return entry
        end
    end)

    if controlling ~= nil then
        _0_9_1_player_stop_controlling(controlling)
        focus_behavior.start_following(focus) -- This will create the gui element
    end
end
