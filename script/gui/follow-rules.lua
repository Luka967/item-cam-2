local util = require("util")

--- @module "const"
local const = require("__item-cam-2__.script.const")
--- @module "utility"
local utility = require("__item-cam-2__.script.utility")
--- @module "state"
local state = require("__item-cam-2__.script.state")
--- @module "gui-custom"
local gui_custom = require("__item-cam-2__.script.gui-custom")
--- @module "gui-generator"
local gui_generator = require("__item-cam-2__.script.gui-generator")
--- @module "dialog"
local gui_dialog = require("__item-cam-2__.script.gui.dialog")

local gui_follow_rules = {}
gui_follow_rules.gid = "ic2-follow-rules"

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

--- @param existing FollowRuleItemOutOfCrafter
local function construct_item_select_crafter(existing)
    --- @type CustomGuiElement[]
    return {{
        type = "label",
        caption = "If"
    }, {
        type = "choose-elem-button",
        name = "rule-crafter-entity",
        elem_type = "entity-with-quality",
        elem_filters = {{filter = "crafting-machine"}},
        postfix = function (elem)
            elem.elem_value = existing.entity
        end
    }, {
        type = "label",
        caption = "crafted"
    }, {
        type = "choose-elem-button",
        name = "rule-crafter-recipe",
        enabled = false,
        elem_type = "recipe-with-quality",
        postfix = function (elem)
            elem.elem_value = existing.recipe
            elem.elem_filters = filter_crafter_recipe(existing.entity)
            elem.enabled = existing.entity ~= nil
        end
    }, {
        type = "label",
        caption = ", then follow first"
    }, {
        type = "choose-elem-button",
        name = "rule-target",
        enabled = false,
        elem_type = "item-with-quality",
        postfix = function (elem)
            elem.elem_value = existing.target
            elem.elem_filters = filter_crafter_target(existing.recipe)
            elem.enabled = existing.recipe ~= nil
        end
    }}
end

--- @param existing FollowRuleItemOutOfContainer
local function construct_item_select_out_of_container(existing)
    --- @type CustomGuiElement[]
    return {{
        type = "label",
        caption = "If watching"
    }, {
        type = "choose-elem-button",
        name = "rule-container-entity",
        elem_type = "entity-with-quality",
        elem_filters = container_filter,
        postfix = function (elem)
            elem.elem_value = existing.entity
        end
    }, {
        type = "label",
        caption = ", then follow first"
    }, {
        type = "choose-elem-button",
        name = "rule-target",
        enabled = false,
        elem_type = "item-with-quality",
        postfix = function (elem)
            elem.elem_value = existing.target
            elem.enabled = existing.entity ~= nil
        end
    }, {
        type = "label",
        caption = "taken out"
    }}
end

--- @param existing FollowRuleItemFromResource
local function construct_item_select_resource_result(existing)
    --- @type CustomGuiElement[]
    return {{
        type = "label",
        caption = "If"
    }, {
        type = "choose-elem-button",
        name = "rule-mining-result-entity",
        elem_type = "entity-with-quality",
        elem_filters = {{filter = "type", type = "mining-drill"}},
        postfix = function (elem)
            elem.elem_value = existing.entity
        end
    }, {
        type = "label",
        caption = "mined"
    }, {
        type = "choose-elem-button",
        name = "rule-mining-result-resource",
        enabled = false,
        elem_type = "entity",
        postfix = function (elem)
            elem.elem_value = existing.resource
            elem.elem_filters = filter_mining_categories(existing.entity)
            elem.enabled = existing.entity ~= nil
        end
    }, {
        type = "label",
        caption = ", then follow first"
    }, {
        type = "choose-elem-button",
        name = "rule-target",
        enabled = false,
        elem_type = "item-with-quality",
        postfix = function (elem)
            elem.elem_value = existing.target
            elem.elem_filters = filter_mining_results(existing.resource)
            elem.enabled = existing.resource ~= nil
        end
    }}
end

--- @param existing FollowRuleItemFromPlant
local function construct_item_select_plant_result(existing)
    --- @type CustomGuiElement[]
    return {{
        type = "label",
        caption = "If"
    }, {
        type = "choose-elem-button",
        name = "rule-plant-result-entity",
        elem_type = "entity",
        elem_filters = {{filter = "type", type = "plant"}},
        postfix = function (elem)
            elem.elem_value = existing.entity
        end
    }, {
        type = "label",
        caption = "got mined, then follow first"
    }, {
        type = "choose-elem-button",
        name = "rule-target",
        enabled = false,
        elem_type = "item-with-quality",
        postfix = function (elem)
            elem.elem_value = existing.target
            elem.elem_filters = filter_mining_results(existing.entity)
            elem.enabled = not not existing.entity
        end
    }}
end

local constructors_mapped = {
    ["item-out-of-crafter"] = construct_item_select_crafter,
    ["item-out-of-container"] = construct_item_select_out_of_container,
    ["item-from-resource"] = construct_item_select_resource_result,
    ["item-from-plant"] = construct_item_select_plant_result,
}

--- @param rule_entry FollowRule
--- @param idx number
local function construct_item_select(rule_entry, idx)
    local entry_generated = constructors_mapped[rule_entry.type](rule_entry)

    --- @type CustomGuiElement
    local ret = {
        type = "frame",
        direction = "horizontal",
        style = "ic2gui_followrules_entry_frame",
        children = {{
            type = "label",
            name = "rule-index",
            style = "ic2gui_followrules_order_label",
            caption = "#"..idx
        }},
        tags = {idx = idx}
    }
    for _, entry in ipairs(entry_generated) do
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

    return ret
end

--- @type CustomGuiElement
local add_button = {
    type = "drop-down",
    style = "ic2gui_followrules_entry_add_button",
    name = "add-rule",
    items = {
        "+ Add rule",
        "When crafter finished recipe",
        "When taken out of container",
        "When resource node mined",
        "When plant mined"
    },
    selected_index = 1
}

--- @class CustomGuiFollowRulesState: GeneratorGuiBaseState
--- @field modified? boolean
--- @field discard_dialog_open? boolean
--- @field original_rules? FollowRule[]
--- @field modified_rules FollowRule[]

--- @param player LuaPlayer
function gui_follow_rules.open_for(player)
    local original_rules = state.follow_rules[player.index]
    local modified_rules = original_rules and util.copy(original_rules) or {}

    local scroll_pane_children = utility.mapped(modified_rules, construct_item_select)
    table.insert(scroll_pane_children, add_button)

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
            horizontal_scroll_policy = "never",
            children = scroll_pane_children
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

    local gui_state = gui_custom.get_state(player.index, gui_follow_rules.gid)
    gui_state.original_rules = original_rules
    gui_state.modified_rules = modified_rules
end

--- @param scroll_pane LuaGuiElement
local function update_indices(scroll_pane)
    for idx, child in ipairs(scroll_pane.children) do
        if child.name == "add-rule"
            then break end
        child["rule-index"].caption = "#"..idx
    end
end

function gui_follow_rules.register_event_handlers()
    gui_generator.register_event_handlers(gui_follow_rules.gid, {{
        name = gui_follow_rules.gid,
        --- @param gui_state CustomGuiFollowRulesState
        closed = function (event, gui_state)
            if gui_state.discard_dialog_open
                then return end -- Intentionally not closing here
            -- Act as confirm
            state.follow_rules[event.player_index] = gui_state.modified_rules
            gui_follow_rules.close_for(event.player_index)
        end
    }, {
        name = "remote-dialog-cancel",
        --- @param gui_state CustomGuiFollowRulesState
        click = function (event, gui_state)
            -- Shift focus from dialog window back to me
            gui_state.discard_dialog_open = nil
            gui_state.player.opened = gui_state.window
            gui_generator.set_interactible(gui_state.window, true)
        end,
        --- @param gui_state CustomGuiFollowRulesState
        closed = function (event, gui_state)
            -- I must copy paste, for i am the bad program
            gui_state.discard_dialog_open = nil
            gui_state.player.opened = gui_state.window
            gui_generator.set_interactible(gui_state.window, true)
        end
    }, {
        name = "remote-dialog-close",
        click = function (event)
            gui_follow_rules.close_for(event.player_index)
        end
    }, {
        name = "action-row-discard",
        --- @param gui_state CustomGuiFollowRulesState
        click = function (event, gui_state)
            if gui_state.discard_dialog_open
                then return end
            if not gui_state.modified then
                gui_follow_rules.close_for(event.player_index)
                return
            end
            gui_state.discard_dialog_open = true
            gui_generator.set_interactible(gui_state.window, false)
            gui_dialog.open_for({
                player = gui_state.player,
                title = "Confirmation",
                caption = "There are unconfirmed changes.",
                back = true,
                confirm = {
                    caption = "Discard changes",
                    style = "red_confirm_button"
                },
                remote = {
                    window = gui_state.window,
                    back = {gid = gui_follow_rules.gid, name = "remote-dialog-cancel"},
                    confirm = {gid = gui_follow_rules.gid, name = "remote-dialog-close"}
                }
            })
        end
    }, {
        name = "action-row-save",
        --- @param gui_state CustomGuiFollowRulesState
        click = function (event, gui_state)
            gui_follow_rules.close_for(event.player_index)
            game.print("save")
            state.follow_rules[event.player_index] = gui_state.modified_rules
        end
    }, {
        name = "add-rule",
        --- @param gui_state CustomGuiFollowRulesState
        selection_state_changed = function (event, gui_state)
            local selected_index = event.element.selected_index
            if selected_index == 1
                then return end
            local new_rule_type = ({
                [2] = "item-out-of-crafter",
                [3] = "item-out-of-container",
                [4] = "item-from-resource",
                [5] = "item-from-plant"
            })[selected_index]

            local new_rule = {type = new_rule_type}
            table.insert(gui_state.modified_rules, new_rule)

            local new_index = event.element.get_index_in_parent()
            local new_rule_elem = construct_item_select(new_rule, new_index)
            new_rule_elem.index = new_index
            gui_generator.generate_at(event.element.parent, new_rule_elem)

            gui_state.modified = true
            event.element.selected_index = 1
        end
    }, {
        name = "delete-rule",
        --- @param gui_state CustomGuiFollowRulesState
        click = function (event, gui_state)
            local idx = event.element.tags.idx
            --- @cast idx number

            -- Button -> rule frame -> scroll pane
            local scroll_pane = event.element.parent.parent
            --- @cast scroll_pane -nil
            event.element.parent.destroy()
            update_indices(scroll_pane)

            gui_state.modified = true
            table.remove(gui_state.modified_rules, idx)
        end
    }, {
        name = "rule-crafter-entity",
        --- @param gui_state CustomGuiFollowRulesState
        elem_changed = function (event, gui_state)
            local entity_pick = event.element.elem_value
            --- @cast entity_pick PrototypeWithQuality

            local recipe_elem = event.element.parent["rule-crafter-recipe"]
            recipe_elem.enabled = entity_pick ~= nil
            recipe_elem.elem_value = nil
            recipe_elem.elem_filters = filter_crafter_recipe(entity_pick)

            local target_elem = event.element.parent["rule-target"]
            target_elem.enabled = false
            target_elem.elem_value = nil

            local rule_idx = event.element.parent.tags.idx
            --- @cast rule_idx number
            gui_state.modified = true
            gui_state.modified_rules[rule_idx].entity = entity_pick
            gui_state.modified_rules[rule_idx].recipe = nil
            gui_state.modified_rules[rule_idx].target = nil
        end
    }, {
        name = "rule-crafter-recipe",
        --- @param gui_state CustomGuiFollowRulesState
        elem_changed = function (event, gui_state)
            local recipe_pick = event.element.elem_value
            --- @cast recipe_pick PrototypeWithQuality

            local target_elem = event.element.parent["rule-target"]
            target_elem.enabled = recipe_pick ~= nil
            target_elem.elem_value = nil
            target_elem.elem_filters = filter_crafter_target(recipe_pick)

            local rule_idx = event.element.parent.tags.idx
            --- @cast rule_idx number
            gui_state.modified = true
            gui_state.modified_rules[rule_idx].recipe = recipe_pick
            gui_state.modified_rules[rule_idx].target = nil
        end
    }, {
        name = "rule-container-entity",
        --- @param gui_state CustomGuiFollowRulesState
        elem_changed = function (event, gui_state)
            local entity_pick = event.element.elem_value
            --- @cast entity_pick PrototypeWithQuality

            local target_elem = event.element.parent["rule-target"]
            target_elem.enabled = entity_pick ~= nil
            target_elem.elem_value = nil

            local rule_idx = event.element.parent.tags.idx
            --- @cast rule_idx number
            gui_state.modified = true
            gui_state.modified_rules[rule_idx].entity = entity_pick
            gui_state.modified_rules[rule_idx].target = nil
        end
    }, {
        name = "rule-plant-result-entity",
        --- @param gui_state CustomGuiFollowRulesState
        elem_changed = function (event, gui_state)
            local entity_pick = event.element.elem_value
            --- @cast entity_pick string

            local target_elem = event.element.parent["rule-target"]
            target_elem.enabled = entity_pick ~= nil
            target_elem.elem_value = nil
            target_elem.elem_filters = filter_mining_results(entity_pick)

            local rule_idx = event.element.parent.tags.idx
            --- @cast rule_idx number
            gui_state.modified = true
            gui_state.modified_rules[rule_idx].entity = entity_pick
            gui_state.modified_rules[rule_idx].target = nil
        end
    }, {
        name = "rule-mining-result-entity",
        --- @param gui_state CustomGuiFollowRulesState
        elem_changed = function (event, gui_state)
            local entity_pick = event.element.elem_value
            --- @cast entity_pick PrototypeWithQuality

            local resource_elem = event.element.parent["rule-mining-result-resource"]
            resource_elem.enabled = entity_pick ~= nil
            resource_elem.elem_value = nil
            resource_elem.elem_filters = filter_mining_categories(entity_pick)

            local target_elem = event.element.parent["rule-target"]
            target_elem.enabled = false
            target_elem.elem_value = nil

            local rule_idx = event.element.parent.tags.idx
            --- @cast rule_idx number
            gui_state.modified = true
            gui_state.modified_rules[rule_idx].entity = entity_pick
            gui_state.modified_rules[rule_idx].resource = nil
            gui_state.modified_rules[rule_idx].target = nil
        end
    }, {
        name = "rule-mining-result-resource",
        --- @param gui_state CustomGuiFollowRulesState
        elem_changed = function (event, gui_state)
            local resource_pick = event.element.elem_value
            --- @cast resource_pick string

            local target_elem = event.element.parent["rule-target"]
            target_elem.enabled = resource_pick ~= nil
            target_elem.elem_value = nil
            target_elem.elem_filters = filter_mining_results(resource_pick)

            local rule_idx = event.element.parent.tags.idx
            --- @cast rule_idx number
            gui_state.modified = true
            gui_state.modified_rules[rule_idx].resource = resource_pick
            gui_state.modified_rules[rule_idx].target = nil
        end
    }, {
        name = "rule-target",
        --- @param gui_state CustomGuiFollowRulesState
        elem_changed = function (event, gui_state)
            local item_pick = event.element.elem_value
            --- @cast item_pick PrototypeWithQuality

            local rule_idx = event.element.parent.tags.idx
            --- @cast rule_idx number
            gui_state.modified = true
            gui_state.modified_rules[rule_idx].target = item_pick
        end
    }})
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
