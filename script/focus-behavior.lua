local const = require("const")
local utility = require("utility")
local focus_update = require("focus-update")
local focus_watchdog = require("focus-watchdog")
local focus_follow_rules = require("focus-follow-rules")

local focus_behavior = {}

--- @class FocusSmoothingState
--- @field speed? number
--- @field min_speed? number
--- @field mul? number
--- @field final_tick integer

--- @class FocusControllablePlayer
--- @field type "player"
--- @field player LuaPlayer
--- @field camera_element? LuaGuiElement

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
        player = controlling
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
function focus_behavior.assign_target_initial(focus, watching)
    focus.watching = watching
    focus.position = focus_watchdog.get_position[watching.type](watching)
    focus.smooth_position = {x = focus.position.x, y = focus.position.y}
    focus.surface = focus_watchdog.get_surface[watching.type](watching)

    focus_follow_rules.apply_matching(focus)
end

--- @param player LuaPlayer
--- @param camera_elem LuaGuiElement
local function set_player_camera_size(player, camera_elem)
    camera_elem.position.x = 0
    camera_elem.position.y = 0
    local res = player.display_resolution
    camera_elem.style.width = res.width / player.display_scale / player.display_density_scale
    camera_elem.style.height = res.height / player.display_scale / player.display_density_scale
end

--- @param focus FocusInstance
function focus_behavior.start_following(focus)
    assert(focus.watching ~= nil, "focus instance has no initial watchdog set")

    focus.valid = true

    for _, controlling in ipairs(focus.controlling) do
        if controlling.type == "player" then
            local camera_elem = controlling.player.gui.screen.add({
                type = "camera",
                name = "item-cam-2-camera",
                position = focus.position,
                surface_index = focus.surface.index,
                zoom = 2
            })
            set_player_camera_size(controlling.player, camera_elem)

            controlling.camera_element = camera_elem
        else
            controlling.element.position = focus.position
            controlling.element.surface_index = focus.surface.index
        end
    end
end

--- @param focus FocusInstance
function focus_behavior.stop_following(focus)
    focus.valid = false

    for _, controlling in ipairs(focus.controlling) do
        if controlling.type == "player" then
            local camera_elem_zoom = controlling.camera_element.zoom
            controlling.camera_element.destroy()
            controlling.camera_element = nil

            local player_settings = settings.get_player_settings(controlling.player)
            if player_settings[const.name_setting_camera_stopping_opens_remote].value then
                controlling.player.set_controller({
                    type = defines.controllers.remote,
                    position = focus.smooth_position,
                    surface = focus.surface
                })
                controlling.player.zoom = camera_elem_zoom
            end
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

    local new_surface = focus_watchdog.get_surface[watching.type](watching)
    if new_surface ~= focus.surface and focus.smoothing ~= nil then
        utility.debug("smoothing axed because surface changed")
        focus.smoothing = nil
    end
    focus.surface = new_surface
    focus.position = focus_watchdog.get_position[watching.type](watching)
    update_smooth_position(focus)

    -- Control the controlling
    for _, controlling in ipairs(focus.controlling) do
        if controlling.type == "player" then
            local camera_elem = controlling.camera_element
            assert(camera_elem ~= nil, "camera_element for controlling player is nil")

            set_player_camera_size(controlling.player, camera_elem)
            camera_elem.position = focus.smooth_position
            camera_elem.surface_index = focus.surface.index
        else
            controlling.element.position = focus.smooth_position
            controlling.element.surface_index = focus.surface.index
        end
    end
end

return focus_behavior
