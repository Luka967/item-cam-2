local const = require("const")
local state = require("state")
local focus_behavior = require("focus-behavior")
local focus_select = require("focus-select")
local utility = require("utility")

--- @param event EventData.on_player_selected_area
local function start_item_cam(event)
    if event.item ~= const.name_selection_item
        then return end

    local player = game.get_player(event.player_index)
    if player == nil
        then return end

    local closest_selection = focus_select(event.entities, utility.aabb_center(event.area))
    if closest_selection == nil
        then return end

    local new_focus = focus_behavior.acquire_target(player, closest_selection)
    if new_focus == nil
        then return end

    focus_behavior.start_following(new_focus)
    state.focuses.set(event.player_index, new_focus)
end

--- @param player_idx integer
local function stop_item_cam(player_idx)
    local focus = state.focuses.get(player_idx)
    if focus == nil
        then return end
    focus_behavior.stop_following(focus)
    state.focuses.set(player_idx, nil)
end

--- @param event EventData.CustomInputEvent|EventData.on_lua_shortcut
local function toggle_item_cam_shortcut(event)
    if event.player_index == nil
        then return end
    if event.prototype_name ~= const.name_shortcut and event.input_name ~= const.name_keybind
        then return end

    local player = game.get_player(event.player_index)
    if player == nil
        then return end

    if state.focuses.get(event.player_index) ~= nil then
        stop_item_cam(event.player_index)
        return
    end

    if player.cursor_stack ~= nil then
        player.clear_cursor()
    end
    player.cursor_stack.set_stack(const.name_selection_item)
end

commands.add_command("stop-item-cam", "Stop following with Item Cam", function (p1)
    stop_item_cam(p1.player_index)
end)
script.on_event(const.name_keybind, toggle_item_cam_shortcut)
script.on_event(defines.events.on_lua_shortcut, toggle_item_cam_shortcut)
script.on_event(defines.events.on_player_selected_area, start_item_cam)
