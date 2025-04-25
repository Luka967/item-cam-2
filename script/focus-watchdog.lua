local utility = require("utility")

--- @class FocusWatchdog
--- @field type string
--- @field type_changes_surface? boolean
--- @field handle LuaEntity
--- @field pin any
--- @field item? ItemIDAndQualityIDPair
--- @field position MapPosition
--- @field surface LuaSurface
--- @field get_position (fun(): MapPosition)
--- @field get_surface (fun(): LuaSurface)

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
    local item = entity.held_stack.valid_for_read
        and {
            name = entity.held_stack.name,
            quality = entity.held_stack.quality
        }
        or nil
    return {
        type = "item-in-inserter-hand",
        handle = entity,
        item = item
    }
end

--- @class PinItemInCraftingMachine
--- @field inventory LuaInventory

--- @param entity LuaEntity
--- @return FocusWatchdog
function create.item_in_crafting_machine(entity)
    local inventory
    if entity.type == "assembling-machine" then
        inventory = entity.get_inventory(defines.inventory.assembling_machine_output)
    elseif entity.type == "furnace" then
        inventory = entity.get_inventory(defines.inventory.furnace_result)
    end

    return {
        type = "item-in-crafting-machine",
        handle = entity,
        pin = {
            inventory = inventory
        }
    }
end

--- @class PinItemHeldByRobot
--- @field inventory LuaInventory

--- @param entity LuaEntity
--- @return FocusWatchdog
function create.item_held_by_robot(entity)
    local inventory = entity.get_inventory(defines.inventory.robot_cargo)
    local first_item = inventory[1]
    if not first_item.valid_for_read then
        error("Tried creating watchdog item-held-by-robot for robot that has nothing in cargo")
    end

    return {
        type = "item-held-by-robot",
        handle = entity,
        item = {
            name = first_item.name,
            quality = first_item.quality
        },
        pin = {
            inventory = inventory
        }
    }
end


--- @param watchdog FocusWatchdog
local function just_get_handle_pos(watchdog)
    return watchdog.handle.position
end
--- @type table<string, fun(watchdog: FocusWatchdog): MapPosition>
local get_position = {
    ["entity-direct"] = just_get_handle_pos,
    ["item-in-container"] = just_get_handle_pos,
    ["item-in-crafting-machine"] = just_get_handle_pos,
    ["item-in-inserter-hand"] = function (watchdog)
        return watchdog.handle.held_stack_position
    end,
    ["item-on-belt"] = function (watchdog)
        return watchdog.handle.get_line_item_position(watchdog.pin.line_idx, watchdog.pin.it.position)
    end,
    ["item-held-by-robot"] = function (watchdog)
        -- Position here is not always updated for optimization purposes.
        -- Hats off to boskid for telling me I can use selection_box
        -- which hooks to the proper, rendered position instead
        return utility.aabb_center(watchdog.handle.selection_box)
    end
}

--- @param watchdog FocusWatchdog
local function just_get_handle_surface(watchdog)
    return watchdog.handle.surface
end
--- @type table<string, fun(watchdog: FocusWatchdog): LuaSurface>
local get_surface = {
    ["entity-direct"] = just_get_handle_surface,
    ["item-in-container"] = just_get_handle_surface,
    ["item-in-crafting-machine"] = just_get_handle_surface,
    ["item-held-by-robot"] = just_get_handle_surface,
    ["item-in-inserter-hand"] = just_get_handle_surface,
    ["item-on-belt"] = just_get_handle_surface
}

return {
    create = create,
    get_position = get_position,
    get_surface = get_surface
}
