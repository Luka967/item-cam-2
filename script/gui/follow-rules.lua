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
        caption = {"gui-follow-rules.rule-if"}
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
        caption = {"gui-follow-rules.rule-crafted"}
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
        caption = {"gui-follow-rules.rule-then-first"}
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
        caption = {"gui-follow-rules.rule-if-watching"}
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
        caption = {"gui-follow-rules.rule-then-first"}
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
        caption = {"gui-follow-rules.rule-taken-out"}
    }}
end

--- @param existing FollowRuleItemFromResource
local function construct_item_select_resource_result(existing)
    --- @type CustomGuiElement[]
    return {{
        type = "label",
        caption = {"gui-follow-rules.rule-if"}
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
        caption = {"gui-follow-rules.rule-drill-mined-resource"}
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
        caption = {"gui-follow-rules.rule-then-first"}
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
        caption = {"gui-follow-rules.rule-if"}
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
        caption = {"", {"gui-follow-rules.rule-plant-got-mined"}, {"gui-follow-rules.rule-then-first"}}
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
            caption = {"gui-follow-rules.rule-index", tostring(idx)}
        }, {
            type = "flow",
            name = "rule-move-buttons",
            direction = "vertical",
            style = "ic2gui_followrules_order_buttons",
            children = {{
                type = "sprite-button",
                name = "rule-move-up",
                style = "ic2gui_followrules_entry_move_up_button",
            }, {
                type = "sprite-button",
                name = "rule-move-down",
                style = "ic2gui_followrules_entry_move_down_button"
            }}
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
        {"", "+ ", {"gui-follow-rules.rule-add-placeholder"}},
        {"gui-follow-rules.rule-add-crafter-finished-recipe"},
        {"gui-follow-rules.rule-add-taken-out-of-container"},
        {"gui-follow-rules.rule-add-resource-mined"},
        {"gui-follow-rules.rule-add-plant-mined"}
    },
    selected_index = 1
}

--- @class CustomGuiFollowRulesState: GeneratorGuiBaseState
--- @field modified? boolean
--- @field discard_dialog_open? boolean
--- @field original_rules? FollowRule[]
--- @field modified_rules FollowRule[]

--- This actually sets index depending on element position, so it assumes it's accurate
--- @param gui_state CustomGuiFollowRulesState
--- @param scroll_pane LuaGuiElement
local function update_indices(gui_state, scroll_pane)
    local cnt = #gui_state.modified_rules
    for idx = 1, cnt do
        local rule_frame = scroll_pane.children[idx]
        rule_frame["rule-index"].caption = {"gui-follow-rules.rule-index", tostring(idx)}
        rule_frame["rule-move-buttons"]["rule-move-up"].enabled = idx ~= 1
        rule_frame["rule-move-buttons"]["rule-move-down"].enabled = idx ~= cnt
        rule_frame.tags = {idx = idx}
    end
end

--- @param player LuaPlayer
function gui_follow_rules.open_for(player)
    local original_rules = state.follow_rules[player.index]
    local modified_rules = original_rules and util.copy(original_rules) or {}

    local scroll_pane_children = utility.mapped(modified_rules, construct_item_select)
    table.insert(scroll_pane_children, add_button)

    local opened_gui = gui_generator.generate_at(player.gui.screen, {
        gid = gui_follow_rules.gid,
        is_window_root = true,
        type = "frame",
        name = gui_follow_rules.gid,
        caption = {"gui-follow-rules.title"},
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
            caption = {"gui-follow-rules.evaluation-behavior"}
        }, {
            type = "label",
            style = "ic2gui_followrules_detail_label",
            caption = {"gui-follow-rules.evaluation-rule-1"}
        }, {
            type = "label",
            style = "ic2gui_followrules_detail_label",
            caption = {"gui-follow-rules.evaluation-rule-2"}
        }, {
            type = "label",
            style = "ic2gui_followrules_detail_label_last",
            caption = {"gui-follow-rules.evaluation-rule-3"}
        }, {
            type = "scroll-pane",
            name = "rule-scroll-pane",
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
                caption = {"gui.discard"},
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
                caption = {"gui.save"},
                tooltip = {"gui-follow-rules.save"}
            }}
        }}
    })
    player.opened = opened_gui
    player.set_shortcut_toggled(const.name_options_shortcut, true)

    local gui_state = gui_custom.get_state(player.index, gui_follow_rules.gid)
    assert(gui_state ~= nil, "gui_custom state is nil for newly opened follow rules")
    gui_state.original_rules = original_rules
    gui_state.modified_rules = modified_rules

    -- The gui while being generated is unaware of rule count.
    -- We already have rule element state being updated in two places.
    -- That should be consolidated into a create-then-update aswell,
    -- instead of it being janky copy paste...
    update_indices(gui_state, opened_gui["rule-scroll-pane"])
end

---@param gui_state CustomGuiFollowRulesState
---@param scroll_pane LuaGuiElement
---@param from_idx integer
---@param to_idx integer
---@param inc integer
local function swap_indices(gui_state, scroll_pane, from_idx, to_idx, inc)
    if from_idx == to_idx
        then return end

    local cur_idx = from_idx
    repeat
        scroll_pane.swap_children(cur_idx, cur_idx + inc)

        local tmp = gui_state.modified_rules[cur_idx + inc]
        gui_state.modified_rules[cur_idx + inc] = gui_state.modified_rules[cur_idx]
        gui_state.modified_rules[cur_idx] = tmp

        cur_idx = cur_idx + inc
    until cur_idx == to_idx

    update_indices(gui_state, scroll_pane)
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
                title = {"gui.confirmation"},
                caption = {"generic-unconfirmed-changes"},
                back = true,
                confirm = {
                    caption = {"discard-changes"},
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
            state.follow_rules[event.player_index] = gui_state.modified_rules
        end
    }, {
        name = "add-rule",
        --- @param gui_state CustomGuiFollowRulesState
        selection_state_changed = function (event, gui_state)
            local selected_index = event.element.selected_index
            if selected_index == 1
                then return end
            gui_state.modified = true

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
            update_indices(gui_state, event.element.parent)
            event.element.selected_index = 1
        end
    }, {
        name = "delete-rule",
        --- @param gui_state CustomGuiFollowRulesState
        click = function (event, gui_state)
            -- Button -> rule frame -> scroll pane
            local scroll_pane = event.element.parent.parent
            local idx = event.element.parent.tags.idx
            --- @cast scroll_pane -nil
            --- @cast idx number

            gui_state.modified = true

            event.element.parent.destroy()
            table.remove(gui_state.modified_rules, idx)
            update_indices(gui_state, scroll_pane)
        end
    }, {
        name = "rule-move-up",
        --- @param gui_state CustomGuiFollowRulesState
        click = function (event, gui_state)
            -- Button -> buttons flow -> rule frame
            local old_idx = event.element.parent.parent.tags.idx
            local scroll_pane = event.element.parent.parent.parent
            --- @cast old_idx number
            --- @cast scroll_pane -nil

            gui_state.modified = true

            local new_idx = old_idx - 1
            if event.shift then new_idx = new_idx - 4 end
            if event.control then new_idx = 1 end
            new_idx = math.max(new_idx, 1)

            swap_indices(gui_state, scroll_pane, old_idx, new_idx, -1)
        end
    }, {
        name = "rule-move-down",
        --- @param gui_state CustomGuiFollowRulesState
        click = function (event, gui_state)
            local old_idx = event.element.parent.parent.tags.idx
            local scroll_pane = event.element.parent.parent.parent
            --- @cast old_idx number
            --- @cast scroll_pane -nil

            gui_state.modified = true

            local new_idx = old_idx + 1
            if event.shift then new_idx = new_idx + 4 end
            if event.control then new_idx = #gui_state.modified_rules end
            new_idx = math.min(new_idx, #gui_state.modified_rules)

            swap_indices(gui_state, scroll_pane, old_idx, new_idx, 1)
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
