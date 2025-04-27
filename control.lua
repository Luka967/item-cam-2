local focus_behavior = require("script.focus-behavior")
local utility = require("script.utility")

--- @type table<integer, FocusInstance>
local focuses

--- @param player_idx integer
--- @return FocusInstance?
local function get_focus(player_idx)
    return focuses[player_idx]
end
--- @param player_idx integer
--- @param to FocusInstance?
local function set_focus(player_idx, to)
    focuses[player_idx] = to
end

--- @param event EventData.on_player_selected_area
local function start_item_cam(event)
    if event.item ~= "item-cam"
        then return end

    local player = game.get_player(event.player_index)
    local new_focus = focus_behavior.acquire_target(player, event.entities[1])
    if new_focus == nil
        then return end
    focus_behavior.start_following(new_focus)
    set_focus(event.player_index, new_focus)
end

local function stop_item_cam(player_idx)
    local focus = get_focus(player_idx)
    if focus == nil
        then return end
    focus_behavior.stop_following(focus)
    set_focus(player_idx, nil)
end

--- @param event EventData.CustomInputEvent|EventData.on_lua_shortcut
local function toggle_item_cam_shortcut(event)
    if event.player_index == nil
        then return end
    if event.prototype_name ~= "item-cam" and event.input_name ~= "item-cam"
        then return end

    local player = game.get_player(event.player_index)
    if player == nil
        then return end

    if get_focus(event.player_index) ~= nil then
        stop_item_cam(event.player_index)
        return
    end

    if player.cursor_stack ~= nil then
        player.clear_cursor()
    end
    player.cursor_stack.set_stack("item-cam")
end

commands.add_command("stop-item-cam", "Stop following with Item Cam", function (p1)
    stop_item_cam(p1.player_index)
end)
script.on_event("item-cam", toggle_item_cam_shortcut)
script.on_event(defines.events.on_lua_shortcut, toggle_item_cam_shortcut)
script.on_event(defines.events.on_player_selected_area, start_item_cam)

local function first_surface()
    for _, surface in pairs(game.surfaces) do
        return surface
    end
end

script.on_init(function ()
    storage.focuses = storage.focuses or {}
end)

script.on_load(function ()
    focuses = storage.focuses
end)

local next_tick_registration_number
script.on_event(defines.events.on_tick, function ()
    local obj_surface = first_surface()
    if obj_surface == nil
        then return end -- What?

    -- on_tick is raised early into game update.
    -- Player can move their controller past it and tracked entity may get updated in the meantime.
    -- We can hack in an event raise basically after game update with a RegistrationTarget and its on_object_destroyed.
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
    local focus = focuses[player_idx]
    if not focus.valid then
        utility.debug("ambiguous update_focus call for player_idx "..player_idx.." whose focus is invalid")
        set_focus(player_idx, nil)
        return
    end

    local last_type = focus.watching.type
    if not focus_behavior.update(focus) then
        local gps_tag = "[gps="..focus.position.x..","..focus.position.y..","..focus.surface.name.."]"
        local tell_str = "lost focus, last known was "..last_type.." at "..gps_tag
        utility.debug(tell_str)
        focus.controlling.print(tell_str)
        focus_behavior.stop_following(focus)
        set_focus(player_idx, nil)
        return
    elseif focus.watching.type ~= last_type then
        utility.debug("change focus from "..last_type.." to "..focus.watching.type)
        return
    end

    focus_behavior.update_location(focus)
    focus.controlling.teleport(focus.position, focus.surface)
end

script.on_event(defines.events.on_object_destroyed, function (event)
    if next_tick_registration_number ~= event.registration_number
        then return end
    for player_idx in pairs(focuses) do
        update_focus(player_idx)
    end
end)
