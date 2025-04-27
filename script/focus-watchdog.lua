local utility = require("utility")

--- @class FocusWatchdog
--- @field type string
--- @field type_changes_surface? boolean
--- @field handle LuaEntity
--- @field pin any
--- @field item? ItemIDAndQualityIDPair
--- @field position MapPosition
--- @field surface LuaSurface

local create = {}

--- @class PinItemInContainer
--- @field inventory LuaInventory
--- @field last_tick_count integer

--- @param entity LuaEntity
--- @param inventory_type defines.inventory
--- @param item ItemIDAndQualityIDPair
--- @return FocusWatchdog
function create.item_in_container(entity, inventory_type, item)
    local inventory = entity.get_inventory(inventory_type)

    return {
        type = "item-in-container",
        handle = entity,
        item = item,
        pin = {
            inventory = inventory,
            last_tick_count = inventory.get_item_count(item)
        }
    }
end

--- @class PinItemOnBelt
--- @field it DetailedItemOnLine
--- @field id integer
--- @field line_idx integer

--- @param item_on_line DetailedItemOnLine
--- @param line_idx integer
--- @param belt_entity LuaEntity
--- @return FocusWatchdog
function create.item_on_belt(item_on_line, line_idx, belt_entity)
    return {
        type = "item-on-belt",
        handle = belt_entity,
        item = {
            name = item_on_line.stack.name,
            quality = item_on_line.stack.quality
        },
        pin = {
            it = item_on_line,
            id = item_on_line.unique_id,
            line_idx = line_idx,
        }
    }
end

--- @param entity LuaEntity
--- @return FocusWatchdog
function create.item_in_inserter_hand(entity)
    if not entity.held_stack.valid_for_read then
        error("Tried creating watchdog item-in-inserter-hand for inserter that has nothing in hand")
    end
    return {
        type = "item-in-inserter-hand",
        handle = entity,
        item = {
            name = entity.held_stack.name,
            quality = entity.held_stack.quality
        }
    }
end

--- @class PinItemInCraftingMachine
--- @field initial_products_finished integer

--- @param entity LuaEntity
--- @return FocusWatchdog
function create.item_in_crafting_machine(entity)
    return {
        type = "item-in-crafting-machine",
        handle = entity,
        pin = {
            initial_products_finished = entity.products_finished
        }
    }
end

--- @class PinItemHeldByRobot
--- @field inventory LuaInventory
--- @field drop_target LuaEntity

--- @param entity LuaEntity
--- @return FocusWatchdog
function create.item_held_by_robot(entity)
    local first_item = entity.get_inventory(defines.inventory.robot_cargo)[1]
    if not first_item.valid_for_read then
        error("Tried creating watchdog item-held-by-robot for robot that has nothing in robot_cargo")
    end
    local first_order = entity.robot_order_queue[1]

    return {
        type = "item-held-by-robot",
        handle = entity,
        item = {
            name = first_item.name,
            quality = first_item.quality
        },
        pin = {
            drop_target = first_order.target or first_order.secondary_target
        }
    }
end

--- @class PinItemComingFromMiningDrill
--- @field last_mining_target? LuaEntity
--- @field expected_products? string[]

--- @param entity LuaEntity
--- @return FocusWatchdog
function create.item_coming_from_mining_drill(entity)
    return {
        type = "item-coming-from-mining-drill",
        handle = entity,
        pin = {}
    }
end

--- @class PinItemInRocketSilo
--- @field inventory LuaInventory

--- @param entity LuaEntity
--- @param item ItemIDAndQualityIDPair
--- @return FocusWatchdog
function create.item_in_rocket_silo(entity, item)
    return {
        type = "item-in-rocket-silo",
        handle = entity,
        item = item,
        pin = {
            inventory = entity.get_inventory(defines.inventory.rocket_silo_rocket)
        }
    }
end

--- @param entity LuaEntity
--- @param item ItemIDAndQualityIDPair
--- @return FocusWatchdog
function create.item_in_rocket(entity, item)
    return {
        type = "item-in-rocket",
        handle = entity,
        item = item
    }
end

--- @class PinItemInCargoPod
--- @field rocket_entity? LuaEntity
--- @field last_position? MapPosition
--- @field drop_target? LuaEntity

--- @param entity LuaEntity
--- @param item ItemIDAndQualityIDPair
--- @param rocket_entity LuaEntity
--- @return FocusWatchdog
function create.item_in_cargo_pod(entity, item, rocket_entity)
    return {
        type = "item-in-cargo-pod",
        type_changes_surface = true,
        handle = entity,
        item = item,
        pin = {
            rocket_entity = rocket_entity,
            last_position = entity.position
        }
    }
end

--- @param watchdog FocusWatchdog
local function just_get_handle_pos(watchdog)
    return watchdog.handle.position
end
--- @param watchdog FocusWatchdog
local function just_get_handle_selection_box(watchdog)
    return utility.aabb_center(watchdog.handle.selection_box)
end
--- @type table<string, fun(watchdog: FocusWatchdog): MapPosition>
local get_position = {
    ["item-in-container"] = just_get_handle_pos,
    ["item-on-belt"] = function (watchdog)
        return watchdog.handle.get_line_item_position(watchdog.pin.line_idx, watchdog.pin.it.position)
    end,
    ["item-in-inserter-hand"] = function (watchdog)
        return watchdog.handle.held_stack_position
    end,
    ["item-in-crafting-machine"] = just_get_handle_pos,
    -- Position here is not always updated for optimization purposes.
    -- Hats off to boskid for telling me I can use selection_box
    -- which hooks to the proper, rendered position instead
    ["item-held-by-robot"] = just_get_handle_selection_box,
    ["item-coming-from-mining-drill"] = just_get_handle_pos,
    ["item-in-rocket-silo"] = just_get_handle_pos,
    ["item-in-rocket"] = just_get_handle_pos,
    ["item-in-cargo-pod"] = function (watchdog)
        local handle = watchdog.handle
        --- @type PinItemInCargoPod
        local pin = watchdog.pin

        if handle.cargo_pod_state == "descending" or handle.cargo_pod_state == "parking" then
            return handle.position
        else
            return pin.last_position
        end
    end
}

--- @param watchdog FocusWatchdog
local function just_get_handle_surface(watchdog)
    return watchdog.handle.surface
end
--- @type table<string, fun(watchdog: FocusWatchdog): LuaSurface>
local get_surface = {
    ["item-in-container"] = just_get_handle_surface,
    ["item-in-crafting-machine"] = just_get_handle_surface,
    ["item-held-by-robot"] = just_get_handle_surface,
    ["item-in-inserter-hand"] = just_get_handle_surface,
    ["item-on-belt"] = just_get_handle_surface,
    ["item-coming-from-mining-drill"] = just_get_handle_surface,
    ["item-in-rocket-silo"] = just_get_handle_surface,
    ["item-in-rocket"] = just_get_handle_surface,
    ["item-in-cargo-pod"] = just_get_handle_surface
}

return {
    create = create,
    get_position = get_position,
    get_surface = get_surface
}
