--- @module "const"
local const = require("__item-cam-2__.script.const")
--- @module "utility"
local utility = require("__item-cam-2__.script.utility")
--- @module "gui-generator"
local gui_generator = require("__item-cam-2__.script.gui-generator")

local gui_follow_rules = {}
gui_follow_rules.gid = "test-gid"

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

--- @param elem_value PrototypeWithQuality|nil
local function filter_crafter_recipe(elem_value)
    if elem_value == nil
        then return end
    local categories = prototypes.entity[elem_value.name].crafting_categories
    if categories == nil
        then return {} end
    local ret = utility.keys_mapped(categories, function (entry)
        --- @type RecipePrototypeFilter
        return {
            filter = "category",
            category = entry,
            mode = "or"
        }
    end)
    table.insert(ret, {
        filter = "hidden",
        mode = "or"
    })
    return ret
end

--- @param entry (ItemProduct|FluidProduct|ResearchProgressProduct)
local function map_product_to_filter(entry)
    if entry.type ~= "item"
        then return end
    --- @type ItemPrototypeFilter
    return {
        filter = "name",
        name = entry.name,
        mode = "or"
    }
end

--- @param elem_value PrototypeWithQuality|nil
local function filter_crafter_target(elem_value)
    if elem_value == nil
        then return end
    local its_products = prototypes.recipe[elem_value.name].products
    return utility.mapped(its_products, map_product_to_filter)
end

--- @param elem_value PrototypeWithQuality|nil
local function filter_mining_categories(elem_value)
    if elem_value == nil
        then return end
    local categories = prototypes.entity[elem_value.name].resource_categories
    if categories == nil
        then return {} end
    return utility.keys_mapped_flattened(prototypes.entity, function (name, proto)
        --- @cast proto LuaEntityPrototype

        if proto.type ~= "resource"
            then return end
        if not categories[proto.resource_category]
            then return end
        --- @type EntityPrototypeFilter[]
        return {{
            filter = "type",
            type = "resource",
            mode = "or"
        }, {
            filter = "name",
            name = name,
            mode = "and"
        }}
    end)
end

--- @param elem_value string|nil
local function filter_mining_results(elem_value)
    if elem_value == nil
        then return end
    local mineable = prototypes.entity[elem_value].mineable_properties
    if mineable == nil or not mineable.minable or mineable.products == nil
        then return {} end
    return utility.mapped(mineable.products, map_product_to_filter)
end

local function construct_item_select_crafter()
    --- @type CustomGuiElement[]
    return {{
        type = "label",
        caption = "If"
    }, {
        type = "choose-elem-button",
        name = "rule-crafter-entity",
        elem_type = "entity-with-quality",
        elem_filters = {{filter = "crafting-machine"}}
    }, {
        type = "label",
        caption = "crafted"
    }, {
        type = "choose-elem-button",
        name = "rule-crafter-recipe",
        enabled = false,
        elem_type = "recipe-with-quality"
    }, {
        type = "label",
        caption = ", then follow first"
    }, {
        type = "choose-elem-button",
        name = "rule-target",
        enabled = false,
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
        name = "rule-container-entity",
        elem_type = "entity-with-quality",
        elem_filters = container_filter
    }, {
        type = "label",
        caption = ", then follow first"
    }, {
        type = "choose-elem-button",
        name = "rule-target",
        enabled = false,
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
        name = "rule-plant-result-entity",
        elem_type = "entity",
        elem_filters = {{filter = "type", type = "plant"}},
    }, {
        type = "label",
        caption = "got mined, then follow first"
    }, {
        type = "choose-elem-button",
        name = "rule-target",
        enabled = false,
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
        name = "rule-mining-result-entity",
        elem_type = "entity-with-quality",
        elem_filters = {{filter = "type", type = "mining-drill"}}
    }, {
        type = "label",
        caption = "mined"
    }, {
        type = "choose-elem-button",
        name = "rule-mining-result-resource",
        enabled = false,
        elem_type = "entity"
    }, {
        type = "label",
        caption = ", then follow first"
    }, {
        type = "choose-elem-button",
        name = "rule-target",
        enabled = false,
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
            type = "label",
            style = "ic2gui_followrules_order_label",
            caption = "#"..idx
        }},
        tags = {idx = idx}
    }
    local merging = kind()
    for _, entry in ipairs(merging) do
        table.insert(ret.children, entry)
    end

    --- @type CustomGuiElement[]
    local right_side = {{
        type = "empty-widget",
        style = "ic2gui_followrules_entry_empty_space"
    }, {
        type = "empty-widget",
        style = "ic2gui_followrules_entry_draggable_space",
        name = "drag-rule"
    }, {
        type = "sprite-button",
        style = "ic2gui_followrules_entry_delete_button",
        sprite = "utility.close",
        name = "delete-rule"
    }}

    for _, entry in ipairs(right_side) do
        table.insert(ret.children, entry)
    end

    -- TODO: Delete button

    return ret
end

--- @type CustomGuiElement
local add_button = {
    type = "drop-down",
    style = "ic2gui_followrules_entry_add_button",
    name = "add-rule",
    caption = "+ Add rule",
    items = {
        "Test 1",
        "Test 2",
        "Test 3",
    }
}

function gui_follow_rules.register_event_handlers()
    gui_generator.register_event_handlers(gui_follow_rules.gid, {{
        name = gui_follow_rules.gid,
        closed = function (event)
            gui_follow_rules.close_for(event.player_index)
        end
    }, {
        name = "action-row-discard",
        click = function (event)
            gui_follow_rules.close_for(event.player_index)
            game.print("discard")
        end
    }, {
        name = "action-row-save",
        click = function (event)
            gui_follow_rules.close_for(event.player_index)
            game.print("save")
        end
    }, {
        name = "add-rule",
        selection_state_changed = function (event)
            game.print("add rule")
            event.element.selected_index = 0
        end
    }, {
        name = "delete-rule",
        click = function (event)
            local idx = event.element.parent.tags.idx
            --- @cast idx number
            event.element.parent.destroy()
            game.print("delete "..idx)
        end
    }, {
        name = "rule-crafter-entity",
        elem_changed = function (event)
            local crafter_pick = event.element.elem_value
            --- @cast crafter_pick PrototypeWithQuality

            local recipe_elem = event.element.parent["rule-crafter-recipe"]
            recipe_elem.enabled = crafter_pick ~= nil
            recipe_elem.elem_value = nil
            recipe_elem.elem_filters = filter_crafter_recipe(crafter_pick)

            local target_elem = event.element.parent["rule-target"]
            target_elem.enabled = false
            target_elem.elem_value = nil
        end
    }, {
        name = "rule-crafter-recipe",
        elem_changed = function (event)
            local recipe_pick = event.element.elem_value
            --- @cast recipe_pick PrototypeWithQuality

            local target_elem = event.element.parent["rule-target"]
            target_elem.enabled = recipe_pick ~= nil
            target_elem.elem_value = nil
            target_elem.elem_filters = filter_crafter_target(recipe_pick)
        end
    }, {
        name = "rule-container-entity",
        elem_changed = function (event)
            local entity_pick = event.element.elem_value
            local target_elem = event.element.parent["rule-target"]
            target_elem.enabled = entity_pick ~= nil
            target_elem.elem_value = nil
        end
    }, {
        name = "rule-plant-result-entity",
        elem_changed = function (event)
            local entity_pick = event.element.elem_value
            --- @cast entity_pick PrototypeWithQuality

            local target_elem = event.element.parent["rule-target"]
            target_elem.enabled = entity_pick ~= nil
            target_elem.elem_value = nil
            target_elem.elem_filters = filter_mining_results(entity_pick)
        end
    }, {
        name = "rule-mining-result-entity",
        elem_changed = function (event)
            local drill_pick = event.element.elem_value
            --- @cast drill_pick PrototypeWithQuality

            local resource_elem = event.element.parent["rule-mining-result-resource"]
            resource_elem.enabled = drill_pick ~= nil
            resource_elem.elem_value = nil
            resource_elem.elem_filters = filter_mining_categories(drill_pick)

            local target_elem = event.element.parent["rule-target"]
            target_elem.enabled = false
            target_elem.elem_value = nil
        end
    }, {
        name = "rule-mining-result-resource",
        elem_changed = function (event)
            local resource_pick = event.element.elem_value
            --- @cast resource_pick string

            local target_elem = event.element.parent["rule-target"]
            target_elem.enabled = resource_pick ~= nil
            target_elem.elem_value = nil
            target_elem.elem_filters = filter_mining_results(resource_pick)
        end
    }})
end

--- @param player LuaPlayer
function gui_follow_rules.open_for(player)
    player.opened = gui_generator.generate_at(player.gui.screen, {
        gid = gui_follow_rules.gid,
        is_window_root = true,
        type = "frame",
        name = gui_follow_rules.gid,
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
                construct_item_select(5, construct_item_select_mining_result),
                add_button
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
function gui_follow_rules.close_for(player_index)
    local player = game.get_player(player_index)
    if player == nil
        then return end
    player.gui.screen[gui_follow_rules.gid].destroy()
    player.set_shortcut_toggled(const.name_options_shortcut, false)
end

return gui_follow_rules
