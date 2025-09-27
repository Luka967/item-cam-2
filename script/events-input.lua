local const = require("const")
local state = require("state")
local focus_behavior = require("focus-behavior")
local focus_select = require("focus-select")
local utility = require("utility")

local gui_follow_rules = require("gui.follow-rules")

--- @param player_idx integer
local function get_focus_for_player(player_idx)
    for _, focus in pairs(state.focuses) do
        if
            type(focus.tags) == "table"
            and type(focus.tags.self_managed) == "boolean" and focus.tags.self_managed
            and type(focus.tags.player_idx) == "number" and focus.tags.player_idx == player_idx
        then
            return focus
        end
    end
    return nil -- For union with nil
end

--- @param event EventData.on_player_selected_area
local function start_item_cam(event)
    if event.item ~= const.name_selection_item
        then return end

    local player = game.get_player(event.player_index)
    if player == nil
        then return end

    player.clear_cursor()

    local closest_selection = focus_select.closest(event.entities, utility.aabb_center(event.area))
    if closest_selection == nil
        then return end

    local new_focus = focus_behavior.create(state.follow_rules[player.index])
    new_focus.tags = {
        self_managed = true,
        player_idx = event.player_index
    }
    focus_behavior.add_controllable_player(new_focus, player)

    focus_behavior.assign_target_initial(new_focus, closest_selection)
    focus_behavior.start_following(new_focus)
end

--- @param player_idx integer
local function stop_item_cam(player_idx)
    local focus = get_focus_for_player(player_idx)
    if focus == nil
        then return end
    focus_behavior.destroy(focus)
end

--- @param event EventData.CustomInputEvent|EventData.on_lua_shortcut
local function toggle_item_cam_shortcut(event)
    local player = game.get_player(event.player_index)
    if player == nil
        then return end

    local focus = get_focus_for_player(event.player_index)
    if focus ~= nil then
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

--- @param event EventData.CustomInputEvent
script.on_event(const.name_keybind, function (event)
    toggle_item_cam_shortcut(event)
end)

script.on_event(defines.events.on_player_cursor_stack_changed, function (event)
    local player = game.get_player(event.player_index)
    if player == nil
        then return end

    local is_select_shortcut =
        player.cursor_stack ~= nil
        and player.cursor_stack.valid_for_read
        and player.cursor_stack.name == const.name_selection_item
    player.set_shortcut_toggled(const.name_shortcut, is_select_shortcut)
end)

script.on_event(defines.events.on_lua_shortcut, function (event)
    if event.prototype_name == const.name_shortcut then
        toggle_item_cam_shortcut(event)
        return
    end

    if event.prototype_name ~= const.name_options_shortcut
        then return end

    local player = game.get_player(event.player_index)
    if player == nil
        then return end
    if not player.is_shortcut_toggled(const.name_options_shortcut) then
        gui_follow_rules.open_for(player)
    else
        gui_follow_rules.close_for(player.index)
    end
end)

script.on_event(defines.events.on_player_selected_area, start_item_cam)
script.on_event(defines.events.on_player_alt_reverse_selected_area, start_item_cam)
script.on_event(defines.events.on_player_reverse_selected_area, start_item_cam)
