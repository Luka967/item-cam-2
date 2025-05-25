local utility = require("utility")
local follow_rules = require("focus-follow-rules")

--- @class FocusWatchdog
--- @field type string
--- @field valid boolean
--- @field handle LuaEntity
--- @field pin any
--- @field item_wl? FocusItemWhitelist Future item lookup whitelist

local create = {}

--- @param focus FocusInstance
--- @param entity LuaEntity
function create.item_on_ground(focus, entity)
    --- @type FocusWatchdog
    return {
        type = "item-on-ground",
        valid = true,
        handle = entity,
        item_wl = {item = utility.item_proto(entity.stack)}
    }
end

--- @param focus FocusInstance
--- @param entity LuaEntity
--- @param item PrototypeWithQuality
function create.item_in_container(focus, entity, item)
    local type = "item-in-container"
    if entity.type == "rocket-silo" then
        type = "item-in-rocket-silo"
    end
    if #entity.cargo_hatches > 0 then
        type = "item-in-container-with-cargo-hatches"
    end

    --- @type FocusWatchdog
    return {
        type = type,
        valid = true,
        handle = entity,
        item_wl = {item = item}
    }
end

--- @class PinItemOnBelt
--- @field it DetailedItemOnLine
--- @field id integer
--- @field line_idx integer

--- @param focus FocusInstance
--- @param item_on_line DetailedItemOnLine
--- @param line_idx integer
--- @param belt_entity LuaEntity
function create.item_on_belt(focus, item_on_line, line_idx, belt_entity)
    --- @type FocusWatchdog
    return {
        type = "item-on-belt",
        valid = true,
        handle = belt_entity,
        item_wl = {item = utility.item_proto(item_on_line.stack)},
        --- @type PinItemOnBelt
        pin = {
            it = item_on_line,
            id = item_on_line.unique_id,
            line_idx = line_idx,
        }
    }
end

--- @param focus FocusInstance
--- @param entity LuaEntity
function create.item_in_inserter_hand(focus, entity)
    assert(entity.held_stack.valid_for_read, "inserter has nothing in hand")

    --- @type FocusWatchdog
    return {
        type = "item-in-inserter-hand",
        valid = true,
        handle = entity,
        item_wl = {item = utility.item_proto(entity.held_stack)}
    }
end

--- @class PinItemInCraftingMachine
--- @field initial_products_finished integer
--- @field expected_products? string[]
--- @field announced_change? boolean

--- @param focus FocusInstance
--- @param entity LuaEntity
function create.item_in_crafting_machine(focus, entity)
    --- @type FocusWatchdog
    return {
        type = "item-in-crafting-machine",
        valid = true,
        handle = entity,
        --- @type PinItemInCraftingMachine
        pin = {
            initial_products_finished = entity.products_finished
        }
    }
end

--- @class PinItemHeldByRobot
--- @field drop_target LuaEntity

--- @param focus FocusInstance
--- @param entity LuaEntity
--- @param item PrototypeWithQuality
function create.item_held_by_robot(focus, entity, item)
    local first_order = entity.robot_order_queue[1]
    local drop_target = first_order.target or first_order.secondary_target
    assert(drop_target, "robot has no drop target")

    --- @type FocusWatchdog
    return {
        type = "item-held-by-robot",
        valid = true,
        handle = entity,
        item_wl = {item = item},
        --- @type PinItemHeldByRobot
        pin = {
            drop_target = drop_target
        }
    }
end

--- @class PinItemComingFromMiningDrill
--- @field tick_should_mine integer

--- @param focus FocusInstance
--- @param entity LuaEntity
function create.item_coming_from_mining_drill(focus, entity)
    local mining_target = entity.mining_target
    assert(mining_target, "drill has no mining_target")

    local mining_speed =
        mining_target.prototype.mineable_properties.mining_time
        / (entity.prototype.mining_speed * (1 + entity.speed_bonus))

    -- This is VERY sensitive in case of drill->container->loader
    local remaining_ticks = math.ceil(math.min(
        mining_speed * (1 - entity.mining_progress),
        mining_speed / entity.force.mining_drill_productivity_bonus * (1 - entity.bonus_mining_progress)
    ) / (1 / 60))

    local mining_products = mining_target.prototype.mineable_properties.products
    assert(mining_products, "mining target has no products")

    --- @type FocusWatchdog
    return {
        type = "item-coming-from-mining-drill",
        valid = true,
        handle = entity,
        item_wl = {
            items = utility.products_filtered(mining_products, {items = true})
        },
        --- @type PinItemComingFromMiningDrill
        pin = {
            tick_should_mine = game.tick + remaining_ticks
        }
    }
end

--- @param focus FocusInstance
--- @param entity LuaEntity
--- @param item PrototypeWithQuality
function create.item_in_rocket(focus, entity, item)
    --- @type FocusWatchdog
    return {
        type = "item-in-rocket",
        valid = true,
        handle = entity,
        item_wl = {item = item}
    }
end

--- @class PinItemInCargoPod
--- @field drop_target? LuaEntity

--- @param focus FocusInstance
--- @param entity LuaEntity
--- @param item PrototypeWithQuality
function create.item_in_cargo_pod(focus, entity, item)
    --- @type FocusWatchdog
    return {
        type = "item-in-cargo-pod",
        valid = true,
        handle = entity,
        item_wl = {item = item},
        --- @type PinItemInCargoPod
        pin = {}
    }
end

--- @param focus FocusInstance
--- @param entity LuaEntity
function create.item_coming_from_asteroid_collector(focus, entity)
    --- @type FocusWatchdog
    return {
        type = "item-coming-from-asteroid-collector",
        valid = true,
        handle = entity,
        item_wl = utility.__no_wl
    }
end

--- @param focus FocusInstance
--- @param entity LuaEntity
--- @param item PrototypeWithQuality
function create.seed_in_agricultural_tower(focus, entity, item)
    --- @type FocusWatchdog
    return {
        type = "seed-in-agricultural-tower",
        valid = true,
        handle = entity,
        item_wl = {item = item}
    }
end

--- @class PinPlantGrowing
--- @field last_tick_towers_nearby LuaEntity[]
--- @field last_tick_crane_destinations MapPosition[]

--- @param focus FocusInstance
--- @param entity LuaEntity
function create.plant_growing(focus, entity)
    local mine_products = entity.prototype.mineable_properties.products
    assert(mine_products, "plant has no products")

    local towers_nearby = utility.search_agricultural_towers_owning_plant(entity)
    local towers_crane_destinations = utility.mapped(towers_nearby, function (entry)
        return entry.crane_destination
    end)

    --- @type FocusWatchdog
    return {
        type = "plant-growing",
        valid = true,
        handle = entity,
        item_wl = {
            items = utility.products_filtered(mine_products, {items = true})
        },
        --- @type PinPlantGrowing
        pin = {
            last_tick_towers_nearby = towers_nearby,
            last_tick_crane_destinations = towers_crane_destinations
        }
    }
end

--- @param focus FocusInstance
--- @param entity LuaEntity
function create.item_coming_from_agricultural_tower(focus, entity)
    --- @type FocusWatchdog
    return {
        type = "item-coming-from-agricultural-tower",
        valid = true,
        handle = entity,
        item_wl = utility.__no_wl
    }
end

--- @param focus FocusInstance
--- @param entity LuaEntity
function create.end_lab(focus, entity)
    --- @type FocusWatchdog
    return {
        type = "end-lab",
        valid = true,
        handle = entity,
        item_wl = utility.__no_wl
    }
end

--- @param watchdog FocusWatchdog
local function just_get_handle_pos(watchdog)
    return watchdog.handle.position
end
--- Selection box hooks to player's selection logic on game engine side.
--- Here we use it for things whose logical positions don't match where they're rendered,
--- i.e. bots and rolling stock on elevated rail
--- Hats off to boskid for this workaround
--- @param watchdog FocusWatchdog
local function just_get_handle_selection_box(watchdog)
    return utility.aabb_center(watchdog.handle.selection_box)
end
--- @type table<string, fun(watchdog: FocusWatchdog): MapPosition>
local get_position = {
    ["item-on-ground"] = just_get_handle_pos,
    ["item-in-container"] = just_get_handle_selection_box, -- Includes wagons, so just make it a catch-all
    ["item-on-belt"] = function (watchdog)
        return watchdog.handle.get_line_item_position(watchdog.pin.line_idx, watchdog.pin.it.position)
    end,
    ["item-in-inserter-hand"] = function (watchdog)
        return watchdog.handle.held_stack_position
    end,
    ["item-in-crafting-machine"] = just_get_handle_pos,
    ["item-held-by-robot"] = just_get_handle_selection_box,
    ["item-coming-from-mining-drill"] = just_get_handle_pos,
    ["item-in-rocket-silo"] = just_get_handle_pos,
    ["item-in-rocket"] = just_get_handle_pos,
    ["item-in-cargo-pod"] = just_get_handle_pos,
    ["item-in-container-with-cargo-hatches"] = just_get_handle_pos,
    ["item-coming-from-asteroid-collector"] = just_get_handle_pos,
    ["seed-in-agricultural-tower"] = just_get_handle_pos,
    ["plant-growing"] = just_get_handle_selection_box,
    ["item-coming-from-agricultural-tower"] = just_get_handle_pos,
    ["end-lab"] = just_get_handle_pos
}

--- @param watchdog FocusWatchdog
local function just_get_handle_surface(watchdog)
    return watchdog.handle.surface
end
--- @type table<string, fun(watchdog: FocusWatchdog): LuaSurface>
local get_surface = {
    ["item-on-ground"] = just_get_handle_surface,
    ["item-in-container"] = just_get_handle_surface,
    ["item-in-crafting-machine"] = just_get_handle_surface,
    ["item-held-by-robot"] = just_get_handle_surface,
    ["item-in-inserter-hand"] = just_get_handle_surface,
    ["item-on-belt"] = just_get_handle_surface,
    ["item-coming-from-mining-drill"] = just_get_handle_surface,
    ["item-in-rocket-silo"] = just_get_handle_surface,
    ["item-in-rocket"] = just_get_handle_surface,
    ["item-in-cargo-pod"] = just_get_handle_surface,
    ["item-in-container-with-cargo-hatches"] = just_get_handle_surface,
    ["item-coming-from-asteroid-collector"] = just_get_handle_surface,
    ["seed-in-agricultural-tower"] = just_get_handle_surface,
    ["plant-growing"] = just_get_handle_surface,
    ["item-coming-from-agricultural-tower"] = just_get_handle_surface,
    ["end-lab"] = just_get_handle_surface
}

return {
    create = create,
    get_position = get_position,
    get_surface = get_surface
}
