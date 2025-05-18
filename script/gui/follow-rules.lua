--- @module "const"
local const = require("__item-cam-2__.script.const")
--- @module "gui-generator"
local gui_generator = require("__item-cam-2__.script.gui-generator")

local gui_follow_behavior = {}
gui_follow_behavior.gid = "test-gid"

local container_types = {
    "cargo-landing-pad", "space-platform-hub", "rocket-silo",
    "container", "logistic-container", "cargo-wagon"
}
local container_filter = {}
for idx, type in ipairs(container_types) do
    table.insert(container_filter, {
        filter = "type",
        type = type,
        mode = idx > 1 and "or" or nil
    })
end

local function construct_item_select_crafter()
    --- @type CustomGuiElement[]
    return {{
        type = "label",
        caption = "If"
    }, {
        type = "choose-elem-button",
        elem_type = "entity-with-quality",
        elem_filters = {{filter = "crafting-machine"}}
    }, {
        type = "label",
        caption = "crafted"
    }, {
        type = "choose-elem-button",
        elem_type = "recipe-with-quality"
    }, {
        type = "label",
        caption = ", then follow first"
    }, {
        type = "choose-elem-button",
        elem_type = "item-with-quality"
    }}
end

local function construct_item_select_out_of_container()
    --- @type CustomGuiElement[]
    return {{
        type = "label",
        caption = "If watching"
    }, {
        type = "choose-elem-button",
        elem_type = "entity-with-quality",
        elem_filters = container_filter
    }, {
        type = "label",
        caption = ", then follow first"
    }, {
        type = "choose-elem-button",
        elem_type = "item-with-quality"
    }, {
        type = "label",
        caption = "taken out"
    }}
end

local function construct_item_select_plant_result()
    --- @type CustomGuiElement[]
    return {{
        type = "label",
        caption = "If"
    }, {
        type = "choose-elem-button",
        elem_type = "entity-with-quality",
        elem_filters = {{filter = "type", type = "plant"}}
    }, {
        type = "label",
        caption = "got mined, then follow first"
    }, {
        type = "choose-elem-button",
        elem_type = "item-with-quality"
    }}
end

local function construct_item_select_mining_result()
    --- @type CustomGuiElement[]
    return {{
        type = "label",
        caption = "If"
    }, {
        type = "choose-elem-button",
        elem_type = "entity-with-quality",
        elem_filters = {{filter = "type", type = "mining-drill"}}
    }, {
        type = "label",
        caption = "mined"
    }, {
        type = "choose-elem-button",
        elem_type = "entity",
        elem_filters = {{filter = "type", type = "resource"}}
    }, {
        type = "label",
        caption = ", then follow first"
    }, {
        type = "choose-elem-button",
        elem_type = "item-with-quality"
    }}
end

--- @param idx number
--- @param kind fun(): CustomGuiElement[]
local function construct_item_select(idx, kind)
    --- @type CustomGuiElement
    local ret = {
        type = "frame",
        direction = "horizontal",
        style = "ic2gui_followrules_entry_frame",
        children = {{
            type = "empty-widget",
            style = "ic2gui_followrules_draggable_space"
        }, {
            type = "label",
            style = "ic2gui_followrules_order_label",
            caption = "#"..idx
        }}
    }
    local merging = kind()
    for _, entry in ipairs(merging) do
        table.insert(ret.children, entry)
    end

    -- TODO: Delete button

    return ret
end

function gui_follow_behavior.register_event_handlers()
    gui_generator.register_event_handlers(gui_follow_behavior.gid, {{
        name = gui_follow_behavior.gid,
        closed = function (event)
            gui_follow_behavior.close_for(event.player_index)
        end
    }, {
        name = "action-row-discard",
        click = function (event)
            gui_follow_behavior.close_for(event.player_index)
            game.print("discard")
        end
    }, {
        name = "action-row-save",
        click = function (event)
            gui_follow_behavior.close_for(event.player_index)
            game.print("save")
        end
    }})
end

--- @param player LuaPlayer
function gui_follow_behavior.open_for(player)
    player.opened = gui_generator.generate_at(player.gui.screen, {
        gid = gui_follow_behavior.gid,
        is_window_root = true,
        type = "frame",
        name = gui_follow_behavior.gid,
        caption = "Item Cam 2 follow rules",
        direction = "vertical",
        postfix = function (elem)
            elem.auto_center = true
        end,
        children = {{
            type = "label",
            style = "ic2gui_followrules_detail_label",
            caption = {"gui-follow-rules.details"}
        }, {
            type = "label",
            style = "ic2gui_followrules_detail_label_semibold",
            caption = "Evaluation behavior:"
        }, {
            type = "label",
            style = "ic2gui_followrules_detail_label",
            caption = {"gui-follow-rules.evaluation-detail-1"}
        }, {
            type = "label",
            style = "ic2gui_followrules_detail_label",
            caption = {"gui-follow-rules.evaluation-detail-2"}
        }, {
            type = "label",
            style = "ic2gui_followrules_detail_label_last",
            caption = {"gui-follow-rules.evaluation-detail-3"}
        }, {
            type = "scroll-pane",
            style = "ic2gui_followrules_entry_list_scroll",
            vertical_scroll_policy = "always",
            children = {
                construct_item_select(1, construct_item_select_plant_result),
                construct_item_select(2, construct_item_select_crafter),
                construct_item_select(3, construct_item_select_crafter),
                construct_item_select(4, construct_item_select_out_of_container),
                construct_item_select(5, construct_item_select_mining_result)
                -- TODO: Add button
            }
        }, {
            type = "flow",
            direction = "horizontal",
            style = "dialog_buttons_horizontal_flow",
            children = {{
                type = "button",
                name = "action-row-discard",
                style = "red_back_button",
                caption = "Discard",
            }, {
                type = "empty-widget",
                name = "action-row-drag",
                style = "ic2gui_followrules_action_draggable_space",
                postfix = function (elem, window)
                    elem.drag_target = window
                end
            }, {
                type = "button",
                name = "action-row-save",
                style = "confirm_button",
                caption = "Save"
            }}
        }}
    })
    player.set_shortcut_toggled(const.name_options_shortcut, true)
end

--- @param player_index number
function gui_follow_behavior.close_for(player_index)
    local player = game.get_player(player_index)
    if player == nil
        then return end
    player.gui.screen[gui_follow_behavior.gid].destroy()
    player.set_shortcut_toggled(const.name_options_shortcut, false)
end

return gui_follow_behavior
