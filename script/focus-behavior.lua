local const = require("const")
local utility = require("utility")
local focus_update = require("focus-update")
local watchdog = require("focus-watchdog")

local focus_behavior = {}

--- @class FocusSmoothingState
--- @field speed? number
--- @field min_speed? number
--- @field mul? number
--- @field final_tick integer

--- @class FocusInstance
--- @field previous_controller defines.controllers
--- @field previous_surface_idx integer
--- @field previous_position MapPosition
--- @field previous_character? LuaEntity
--- @field controlling LuaPlayer
--- @field smoothing? FocusSmoothingState If set, smooth_position chases position at some rate instead of directly copying it
--- @field watching FocusWatchdog
--- @field position MapPosition
--- @field smooth_position MapPosition
--- @field surface LuaSurface
--- @field valid boolean

--- @param controlling LuaPlayer
--- @param initial_watchdog FocusWatchdog
function focus_behavior.acquire_target(controlling, initial_watchdog)
    --- @type FocusInstance
    local ret = {
        previous_controller = controlling.physical_controller_type,
        previous_surface_idx = controlling.physical_surface_index or controlling.surface_index,
        previous_position = controlling.physical_position or controlling.position,
        previous_character = controlling.character,
        controlling = controlling,
        watching = initial_watchdog,
        position = watchdog.get_position[initial_watchdog.type](initial_watchdog),
        smooth_position = watchdog.get_position[initial_watchdog.type](initial_watchdog), -- Need separate object instance!
        surface = watchdog.get_surface[initial_watchdog.type](initial_watchdog),
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
    player.set_shortcut_toggled(const.name_shortcut, true)

    if
        player.cursor_stack
        and player.cursor_stack.valid_for_read
        and player.cursor_stack.name == const.name_selection_item
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
    player.set_shortcut_toggled(const.name_shortcut, false)

    -- Teleport player to proper surface before reassigning controller
    if game.get_surface(focus.previous_surface_idx) == nil then
        player.print("Previous surface is gone. I don't know where to teleport you")
        player.teleport({0, 0}, "nauvis")
    else
        player.teleport(focus.previous_position, focus.previous_surface_idx)
    end

    if focus.previous_controller == defines.controllers.editor then
        player.toggle_map_editor()
    elseif
        focus.previous_controller == defines.controllers.character
        or focus.previous_controller == defines.controllers.remote
    then
        player.set_controller({
            type = defines.controllers.character,
            character = focus.previous_character
        })
    else
        player.set_controller({type = focus.previous_controller})
    end
    toggle_gui_elements(player, true)
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

    if not focus_update.tick(focus)
        then return false end

    return true
end

--- @param focus FocusInstance
local function update_smooth_position(focus)
    local smoothing = focus.smoothing
    local real_d = math.sqrt(utility.sq_distance(focus.smooth_position, focus.position))
    if
        not smoothing
        or game.tick >= smoothing.final_tick
        or real_d < utility.smooth_end_feather
    then
        focus.smoothing = nil
        focus.smooth_position.x = focus.position.x
        focus.smooth_position.y = focus.position.y
        return
    end

    local angle = utility.vec_angle(focus.smooth_position, focus.position)
    local d = real_d * (smoothing.mul or 1)
    d = math.min(focus.smoothing.speed or d, d)
    d = math.max(focus.smoothing.min_speed or 0, d)
    d = math.min(d, real_d)

    focus.smooth_position.x = focus.smooth_position.x + angle.x * d
    focus.smooth_position.y = focus.smooth_position.y + angle.y * d
end

--- @param focus FocusInstance
function focus_behavior.update_location(focus)
    local watching = focus.watching
    if not watching.handle.valid
        then return false end

    local new_surface = watchdog.get_surface[watching.type](watching)
    if new_surface ~= focus.surface and focus.smoothing ~= nil then
        utility.debug("smoothing axed because surface changed")
        focus.smoothing = nil
    end
    focus.surface = new_surface
    focus.position = watchdog.get_position[watching.type](watching)
    update_smooth_position(focus)
end

return focus_behavior
