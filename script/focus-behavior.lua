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

--- @class FocusControllablePlayer
--- @field type "player"
--- @field player LuaPlayer
--- @field previous_controller defines.controllers
--- @field previous_surface_idx integer
--- @field previous_position MapPosition
--- @field previous_character? LuaEntity

--- @class FocusControllableCameraGui
--- @field type "gui-camera"
--- @field element LuaGuiElement

--- @alias FocusControllable FocusControllablePlayer|FocusControllableCameraGui

--- @class FocusInstance
--- @field controlling FocusControllable[]
--- @field smoothing? FocusSmoothingState If set, smooth_position chases position at some rate instead of directly copying it
--- @field watching? FocusWatchdog
--- @field follow_rules? FollowRule[]
--- @field follow_rules_cnt? number
--- @field follow_rules_start_idx? number
--- @field position MapPosition
--- @field smooth_position MapPosition
--- @field surface LuaSurface
--- @field valid boolean

--- @param follow_rules? FollowRule[]
function focus_behavior.create(follow_rules)
    --- @type FocusInstance
    local ret = {
        valid = false,
        controlling = {},
        position = {x = 0, y = 0},
        smooth_position = {x = 0, y = 0},
        surface = game.surfaces["nauvis"]
    }
    if follow_rules ~= nil then
        ret.follow_rules = follow_rules
        ret.follow_rules_cnt = #follow_rules
        ret.follow_rules_start_idx = 1
    end
    return ret
end

--- @param focus FocusInstance
--- @param controlling LuaPlayer
function focus_behavior.add_controlling_player(focus, controlling)
    --- @type FocusControllablePlayer
    local adding = {
        type = "player",
        player = controlling,
        previous_controller = controlling.physical_controller_type,
        previous_surface_idx = controlling.physical_surface_index or controlling.surface_index,
        previous_position = controlling.physical_position or controlling.position,
        previous_character = controlling.character,
    }
    table.insert(focus.controlling, adding)
end

--- @param focus FocusInstance
--- @param controlling LuaGuiElement
function focus_behavior.add_controlling_camera(focus, controlling)
    --- @type FocusControllableCameraGui
    local adding = {
        type = "gui-camera",
        element = controlling
    }
    table.insert(focus.controlling, adding)
end

--- @param focus FocusInstance
--- @param watching FocusWatchdog
function focus_behavior.assign_target_inital(focus, watching)
    focus.watching = watching
    focus.position = watchdog.get_position[watching.type](watching)
    focus.smooth_position = {x = focus.position.x, y = focus.position.y}
    focus.surface = watchdog.get_surface[watching.type](watching)
end

--- @param player LuaPlayer
--- @param to boolean
local function player_toggle_gui_elements(player, to)
    player.game_view_settings.show_controller_gui = to
    player.game_view_settings.show_entity_tooltip = to
    player.game_view_settings.show_minimap = to
    player.game_view_settings.show_research_info = to
    player.game_view_settings.show_side_menu = to
end

--- @param focus FocusInstance
--- @param player LuaPlayer
local function player_start_controlling(focus, player)
    if player.character ~= nil then
        player.character.walking_state = {
            direction = player.character.walking_state.direction,
            walking = false
        }
    end

    player.set_controller({type = defines.controllers.ghost})
    player_toggle_gui_elements(player, false)

    -- Set initial
    player.teleport(focus.position, focus.surface)
    player.zoom = 2
end

--- @param focus FocusInstance
function focus_behavior.start_following(focus)
    assert(focus.watching ~= nil, "focus instance has no inital watchdog set")

    focus.valid = true

    for _, controlling in ipairs(focus.controlling) do
        if controlling.type == "player" then
            player_start_controlling(focus, controlling.player)
        else
            controlling.element.position = focus.position
            controlling.element.surface_index = focus.surface.index
        end
    end
end

--- @param focus FocusInstance
--- @param controlling FocusControllablePlayer
local function player_stop_controlling(focus, controlling)
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
    player_toggle_gui_elements(player, true)
end

--- @param focus FocusInstance
function focus_behavior.stop_following(focus)
    focus.valid = false

    for _, controlling in ipairs(focus.controlling) do
        if controlling.type == "player" then
            player_stop_controlling(focus, controlling)
        end
    end
end

--- @param focus FocusInstance
local function update_smooth_position(focus)
    local smoothing = focus.smoothing
    local real_d = math.sqrt(utility.sq_distance(focus.smooth_position, focus.position))
    if
        not smoothing
        or game.tick >= smoothing.final_tick
        or real_d < const.smooth_end_feather
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
function focus_behavior.update(focus)
    utility.filtered_in_place(focus.controlling, function (entry)
        if entry.type == "player" and entry.player.valid
            then return true end
        if entry.type == "gui-camera" and entry.element.valid
            then return true end
    end)

    if #focus.controlling == 0 then
        focus.valid = false
        return
    end

    if not focus_update.tick(focus) then
        focus.valid = false
        return
    end

    -- Update location
    local watching = focus.watching
    --- @cast watching -nil

    local new_surface = watchdog.get_surface[watching.type](watching)
    if new_surface ~= focus.surface and focus.smoothing ~= nil then
        utility.debug("smoothing axed because surface changed")
        focus.smoothing = nil
    end
    focus.surface = new_surface
    focus.position = watchdog.get_position[watching.type](watching)
    update_smooth_position(focus)

    -- Control the controlling
    for _, controlling in ipairs(focus.controlling) do
        if controlling.type == "player" then
            controlling.player.teleport(focus.smooth_position, focus.surface)
        else
            controlling.element.position = focus.smooth_position
            controlling.element.surface_index = focus.surface.index
        end
    end
end

return focus_behavior
