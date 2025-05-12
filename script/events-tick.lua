local const = require("const")
local state = require("state")
local utility = require("utility")
local focus_behavior = require("focus-behavior")
local focus_update = require("focus-update")

local map_trigger_effects = {}

--- @param event EventData.on_script_trigger_effect
local function check_environment_changed_next_tick(event)
    table.insert(state.env_changed_next_tick, event.cause_entity)
end
-- When created both cargo_pod_origin and cargo_pod_destination read nil.
-- Defer calling environment_changed to next tick when the cargo pod sees where it is and not where it isn't
map_trigger_effects[const.name_trigger_check_cargo_pod_follow] = check_environment_changed_next_tick
map_trigger_effects[const.name_trigger_check_plant_follow] = check_environment_changed_next_tick

local function first_surface()
    for _, surface in pairs(game.surfaces) do
        return surface
    end
end
local next_tick_registration_number
script.on_event(defines.events.on_tick, function ()
    local obj_surface = first_surface()
    if obj_surface == nil
        then return end -- What?

    -- on_tick is raised early into this tick.
    -- Player can move their controller past it and tracked entity may get updated in the meantime.
    -- We can hack in an event raise basically after all of this tick's update logic
    -- with a small overhead RegistrationTarget and its on_object_destroyed.
    -- Thank you boskid, I hope this becomes standard API later
    local foo = rendering.draw_line({
        from = {0, 0},
        to = {0, 0},
        width = 0,
        color = {0, 0, 0, 0},
        surface = obj_surface
    })
    next_tick_registration_number = script.register_on_object_destroyed(foo)
    foo.destroy()
end)

--- @param player_idx integer
local function tick_one_focus(player_idx)
    local focus = state.focuses.get(player_idx)
    if not focus.valid then
        utility.debug("ambiguous tick_one_focus call for player_idx "..player_idx.." whose focus is invalid")
        state.focuses.set(player_idx, nil)
        return
    end

    for _, env_changed_entity in ipairs(state.env_changed_next_tick) do
        focus_update.environment_changed(focus, env_changed_entity)
    end

    local last_type = focus.watching.type
    if focus_behavior.update(focus) then
        focus_behavior.update_location(focus)
        focus.controlling.teleport(focus.smooth_position, focus.surface)
        return
    end

    state.focuses.set(player_idx, nil)
    if not focus.controlling.valid
        then return end
    focus_behavior.stop_following(focus)

    local gps_tag = "[gps="..focus.position.x..","..focus.position.y..","..focus.surface.name.."]"
    local tell_str = "lost focus, last known was "..last_type.." at "..gps_tag
    utility.debug(tell_str)
    focus.controlling.print(tell_str)
end

script.on_event(defines.events.on_object_destroyed, function (event)
    if next_tick_registration_number ~= event.registration_number
        then return end
    for player_idx in pairs(state.focuses.v) do
        tick_one_focus(player_idx)
    end

    -- Clear env changed array
    local env_changed_cnt = #state.env_changed_next_tick
    for i = 1, env_changed_cnt do
        state.env_changed_next_tick[i] = nil
    end
end)

script.on_event(defines.events.on_script_trigger_effect, function (event)
    if event.cause_entity == nil
        then return end
    local fn = map_trigger_effects[event.effect_id]
    if not fn
        then return end
    fn(event)
end)
