local focus_behavior = require("script.focus-behavior")
local utility = require("script.utility")

--- @type FocusInstance?
local focus

script.on_event(defines.events.on_lua_shortcut, function (event)
    if event.player_index == nil
        then return end
    if event.prototype_name ~= "item-cam"
        then return end

    local player = game.get_player(event.player_index)
    if player == nil
        then return end

    if focus ~= nil then
        focus_behavior.stop_following(focus)
        focus = nil
        return
    end

    if player.cursor_stack ~= nil then
        player.clear_cursor()
    end
    player.cursor_stack.set_stack("item-cam")
end)

script.on_event(defines.events.on_player_selected_area, function (event)
    if event.item ~= "item-cam"
        then return end

    local player = game.get_player(event.player_index)
    local new_focus = focus_behavior.acquire_target(player, event.entities[1])
    if new_focus == nil
        then return end
    focus_behavior.start_following(new_focus)
    focus = new_focus
end)

local function first_surface()
    for _, surface in pairs(game.surfaces) do
        return surface
    end
end

local next_tick_registration_number
script.on_event(defines.events.on_tick, function (event)
    if focus == nil
        then return end

    local obj_surface = first_surface()
    if obj_surface == nil
        then return end

    -- on_tick is raised early into game update.
    -- Player can move their controller past it and tracked entity may get updated in the meantime.
    -- We can hack in an event raise basically after game update with a RegistrationTarget and its on_object_destroyed.
    -- Thank you boskid, I hope this becomes standard API later
    local dummy = rendering.draw_line({
        from = {0, 0},
        to = {0, 0},
        width = 0,
        color = {0, 0, 0, 0},
        surface = obj_surface
    })
    next_tick_registration_number = script.register_on_object_destroyed(dummy)
    dummy.destroy()
end)

script.on_event(defines.events.on_object_destroyed, function (event)
    if next_tick_registration_number ~= event.registration_number
        then return end
    if focus == nil
        then return end

    local last_type = focus.watching.type
    if not focus_behavior.update(focus) then
        game.print("lost focus, last was at "..last_type.." [gps="..focus.position.x..","..focus.position.y.."]")
        focus_behavior.stop_following(focus)
        focus = nil
        return
    elseif focus.watching.type ~= last_type then
        utility.debug("change focus from "..last_type.." to "..focus.watching.type)
        return
    end

    focus_behavior.update_location(focus)
    focus.controlling.teleport(focus.position, focus.surface)
end)
