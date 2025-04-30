local state = require("state")
local utility = require("utility")
local focus_behavior = require("focus-behavior")

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
local function update_focus(player_idx)
    local focus = state.focuses.get(player_idx)
    if not focus.valid then
        utility.debug("ambiguous update_focus call for player_idx "..player_idx.." whose focus is invalid")
        state.focuses.set(player_idx, nil)
        return
    end

    local last_type = focus.watching.type
    if focus_behavior.update(focus) then
        focus_behavior.update_location(focus)
        focus.controlling.teleport(focus.smooth_position, focus.surface)
        return
    end

    local gps_tag = "[gps="..focus.position.x..","..focus.position.y..","..focus.surface.name.."]"
    local tell_str = "lost focus, last known was "..last_type.." at "..gps_tag
    utility.debug(tell_str)
    focus.controlling.print(tell_str)

    focus_behavior.stop_following(focus)
    state.focuses.set(player_idx, nil)
end

script.on_event(defines.events.on_object_destroyed, function (event)
    if next_tick_registration_number ~= event.registration_number then
        -- This is a landing pad getting destroyed
        state.landing_pads.forget(event.registration_number)
        return
    end
    for player_idx in pairs(state.focuses.v) do
        update_focus(player_idx)
    end
end)
