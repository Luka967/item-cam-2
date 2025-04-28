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

--- @param entity LuaEntity
--- @param inventory_type defines.inventory
--- @param item ItemIDAndQualityIDPair
--- @return FocusWatchdog
function create.item_in_container(entity, inventory_type, item)
    local inventory = entity.get_inventory(inventory_type)

    return {
        type = "item-in-container",
        handle = entity,
        item = item
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
    assert(entity.held_stack.valid_for_read, "Tried creating watchdog item-in-inserter-hand for inserter that has nothing in hand")

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
    assert(first_item.valid_for_read, "Tried creating watchdog item-held-by-robot for robot that has nothing in robot_cargo")

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
--- @field tick_should_mine integer

--- @param entity LuaEntity
--- @return FocusWatchdog
function create.item_coming_from_mining_drill(entity)
    assert(entity.mining_target ~= nil, "Tried creating watchdog item-coming-from-mining-drill for drill that has no mining_target")

    local mining_speed =
        entity.mining_target.prototype.mineable_properties.mining_time
        / (entity.prototype.mining_speed * (1 + entity.speed_bonus))

    local remaining_ticks = math.ceil(math.min(
        mining_speed * (1 - entity.mining_progress),
        mining_speed * (1 - entity.bonus_mining_progress)
    ) / (1 / 60))

    return {
        type = "item-coming-from-mining-drill",
        handle = entity,
        pin = {
            tick_should_mine = game.tick + remaining_ticks
        }
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
--- @field drop_target? LuaEntity

--- @param entity LuaEntity
--- @param item ItemIDAndQualityIDPair
--- @return FocusWatchdog
function create.item_in_cargo_pod(entity, item)
    return {
        type = "item-in-cargo-pod",
        type_changes_surface = true,
        handle = entity,
        item = item,
        pin = {}
    }
end

--- @param entity LuaEntity
--- @param item ItemIDAndQualityIDPair
--- @return FocusWatchdog
function create.item_in_container_with_cargo_hatches(entity, item)
    local inventory = entity.get_inventory(defines.inventory.hub_main)

    return {
        type = "item-in-container-with-cargo-hatches",
        handle = entity,
        item = item
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
    -- Position here is not always updated because of game engine optimizations.
    -- Hats off to boskid for telling me I can use selection_box which hooks to the proper, rendered position instead
    ["item-held-by-robot"] = just_get_handle_selection_box,
    ["item-coming-from-mining-drill"] = just_get_handle_pos,
    ["item-in-rocket-silo"] = just_get_handle_pos,
    ["item-in-rocket"] = just_get_handle_pos,
    ["item-in-cargo-pod"] = just_get_handle_pos,
    ["item-in-container-with-cargo-hatches"] = just_get_handle_pos
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
    ["item-in-cargo-pod"] = just_get_handle_surface,
    ["item-in-container-with-cargo-hatches"] = just_get_handle_surface
}

return {
    create = create,
    get_position = get_position,
    get_surface = get_surface
}
