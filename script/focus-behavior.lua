local focus_select = require("focus-select")
local focus_update = require("focus-update")
local watchdog = require("focus-watchdog")

local focus_behavior = {}

--- @class FocusInstance
--- @field previous_controller defines.controllers
--- @field previous_surface_idx integer
--- @field previous_position MapPosition
--- @field previous_character? LuaEntity
--- @field controlling LuaPlayer
--- @field watching FocusWatchdog
--- @field position MapPosition
--- @field surface LuaSurface
--- @field valid boolean

--- @param controlling LuaPlayer
function focus_behavior.acquire_target(controlling, watching)
    if watching == nil
        then return end
    watching = focus_select(watching)
    if watching == nil
        then return end

    --- @type FocusInstance
    local ret = {
        previous_controller = controlling.controller_type,
        previous_surface_idx = controlling.surface_index,
        previous_position = controlling.position,
        previous_character = controlling.character,
        controlling = controlling,
        watching = watching,
        position = watchdog.get_position[watching.type](watching),
        surface = watchdog.get_surface[watching.type](watching),
        valid = true
    }
    return ret
end

--- @param player LuaPlayer
--- @param to boolean
local function toggle_gui_elements(player, to)
    player.game_view_settings.show_controller_gui = to
    player.game_view_settings.show_entity_tooltip = to
    player.game_view_settings.show_minimap = to
    player.game_view_settings.show_research_info = to
    player.game_view_settings.show_side_menu = to
end

--- @param focus FocusInstance
function focus_behavior.start_following(focus)
    local player = focus.controlling
    player.set_shortcut_toggled("item-cam", true)

    if
        player.cursor_stack
        and player.cursor_stack.valid_for_read
        and player.cursor_stack.name == "item-cam"
    then
        player.clear_cursor()
    end

    if player.character ~= nil then
        player.character.walking_state = {
            direction = player.character.walking_state.direction,
            walking = false
        }
    end

    player.set_controller({type = defines.controllers.ghost})
    toggle_gui_elements(player, false)

    -- Set initial
    player.teleport(focus.position, focus.surface)
    player.zoom = 2
end

--- @param focus FocusInstance
function focus_behavior.stop_following(focus)
    local player = focus.controlling

    focus.valid = false
    player.set_shortcut_toggled("item-cam", false)

    if focus.previous_controller == defines.controllers.editor then
        player.toggle_map_editor()
    else
        player.set_controller({
            type = focus.previous_controller,
            character = focus.previous_character
        })
    end
    toggle_gui_elements(player, true)

    if game.get_surface(focus.previous_surface_idx) == nil then
        player.print("Previous surface is gone. I don't know where to teleport you")
        player.teleport({0, 0}, "nauvis")
    else
        player.teleport(focus.previous_position, focus.previous_surface_idx)
    end
end

local allowed_controllers = {
    [defines.controllers.god] = true,
    [defines.controllers.ghost] = true,
    [defines.controllers.spectator] = true
}

--- @param focus FocusInstance
function focus_behavior.update(focus)
    if not focus.controlling.valid then
        focus.valid = false
        return false
    end

    if not allowed_controllers[focus.controlling.controller_type] then
        focus.valid = false
        return false
    end

    if not focus_update(focus)
        then return false end

    return true
end

--- @param focus FocusInstance
function focus_behavior.update_location(focus)
    local watching = focus.watching
    if not watching.handle.valid
        then return false end

    focus.position = watchdog.get_position[watching.type](watching)
    if watching.type_changes_surface then
        focus.surface = watchdog.get_surface[watching.type](watching)
    end
end

return focus_behavior
