local watchdog = require("focus-watchdog")
local transfer_to = require("focus-transfer")
local utility = require("utility")

local handle_invalid_map = {}
local tick_map = {}
local environment_changed_map = {}

--- @param focus FocusInstance
tick_map["item-entity"] = function (focus)
    return true
end

--- @type table<string, fun(handle: LuaEntity): ((LuaEntity | LuaEntity[])[])>
local belt_advance_strategy = {
    ["transport-belt"] = function (handle)
        return {handle.belt_neighbours.outputs}
    end,
    ["splitter"] = function (handle)
        return {handle, handle.belt_neighbours.outputs}
    end,
    ["lane-splitter"] = function (handle)
        return {handle, handle.belt_neighbours.outputs}
    end,
    ["underground-belt"] = function (handle)
        if handle.belt_to_ground_type == "input" then
            return {handle, handle.neighbours}
        else
            return {handle, handle.belt_neighbours.outputs}
        end
    end,
    ["loader"] = function (handle)
        if handle.loader_type == "output" then
            return {handle.belt_neighbours.outputs}
        else
            return {handle.loader_container}
        end
    end,
    ["linked-belt"] = function (handle)
        if handle.linked_belt_type == "output" then
            return {handle.belt_neighbours.outputs}
        else
            return {handle.linked_belt_neighbour}
        end
    end
}

--- @param focus FocusInstance
--- @param handle LuaEntity
--- @param pin PinItemOnBelt
tick_map["item-on-belt"] = function (focus, handle, pin)
    --- @type LuaEntity?
    local next_belt = handle
    --- @type integer?
    local next_line_idx = pin.line_idx

    --- @param item DetailedItemOnLine
    local seek_fn = function (item)
        return item.unique_id == pin.id
    end

    local it = utility.first_on_line(handle.get_transport_line(pin.line_idx), seek_fn)
    if it ~= nil then
        pin.it = it
        return true
    end

    local advance_lookups = belt_advance_strategy[handle.type](handle)
    for _, lookup_entry in ipairs(advance_lookups) do
        if type(lookup_entry) == "nil" then
            -- noop
        elseif lookup_entry.type == nil then
            it, next_line_idx, next_belt = utility.first_on_belts(lookup_entry, seek_fn)
        elseif utility.is_belt[lookup_entry.type] then
            it, next_line_idx = utility.first_on_belt(lookup_entry, seek_fn)
            next_belt = lookup_entry
        else
            -- Loader -> container
            focus.watching = transfer_to.next(lookup_entry, focus.watching.item)
            return true
        end

        if it ~= nil then
            assert(next_belt ~= nil, "tick_map item-on-belt advance didn't give next belt entity")
            assert(next_line_idx ~= nil, "tick_map item-on-belt advance didn't give item line index")
            pin.it = it
            pin.line_idx = next_line_idx
            focus.watching.handle = next_belt
            return true
        end
    end

    utility.debug("watchdog changing: can't find item on belt with my id")
    focus.watching = transfer_to.inserter_nearby(
        handle.surface,
        handle.force,
        utility.aabb_around(focus.position, utility.inserter_search_d),
        focus.position,
        {item = focus.watching.item}
    )
    return true
end

--- @param focus FocusInstance
--- @param handle LuaEntity
tick_map["item-in-inserter-hand"] = function (focus, handle)
    if handle.held_stack.valid_for_read
        then return true end

    utility.debug("watchdog changing: held_stack.valid_for_read false")

    local dropped_into = handle.drop_target
    if dropped_into == nil then
        utility.debug("watchdog lost: dropped_into nil")
        return false
    end

    focus.watching = transfer_to.next(dropped_into, focus.watching.item)
    return true
end

--- @param focus FocusInstance
--- @param handle LuaEntity
tick_map["item-in-container"] = function (focus, handle)
    -- Always query if item got taken.
    -- inventory.get_item_count is expensive for huge space platform cargo
    local first_taken_by = transfer_to.taken_out_of_building(handle, focus.watching.item)
    if first_taken_by ~= nil then
        focus.watching = first_taken_by
    end
    return true
end
local item_in_container = tick_map["item-in-container"]

--- @param focus FocusInstance
--- @param handle LuaEntity
--- @param pin PinItemInCraftingMachine
tick_map["item-in-crafting-machine"] = function (focus, handle, pin)
    if handle.products_finished == pin.initial_products_finished
        then return true end

    if not pin.announced_change then
        utility.debug("watchdog changing: products_finished increased")
        pin.announced_change = true
    end

    local first_taken_by = transfer_to.taken_out_of_building(handle, nil, true)
    if first_taken_by ~= nil then
        -- Crafting machine put its (first) output here
        focus.watching = first_taken_by
    elseif first_taken_by == nil and handle.get_recipe() == nil then
        -- If this is furnace (recycler) and we found no candidates then there were no products
        utility.debug("watchdog lost: first_taken_by nil and handle no longer has recipe, no result to track")
        return false
    end

    return true
end

--- @param focus FocusInstance
--- @param handle LuaEntity
--- @param pin PinItemHeldByRobot
tick_map["item-held-by-robot"] = function (focus, handle, pin)
    local drop_target = pin.drop_target

    local order = handle.robot_order_queue[1]
    if order ~= nil and (
        order.target == drop_target
        or order.secondary_target == drop_target
    ) and utility.all_deliver_robot_order[order.type]
        then return true end

    utility.debug("watchdog changing: first robot order no longer deliver or target changed")

    if drop_target == nil or not drop_target.valid
        then return false end

    focus.watching = transfer_to.next(drop_target, focus.watching.item)
    return true
end

--- @param focus FocusInstance
--- @param handle LuaEntity
--- @param pin PinItemComingFromMiningDrill
tick_map["item-coming-from-mining-drill"] = function (focus, handle, pin)
    local mining_target = handle.mining_target
    if mining_target == nil or not mining_target.valid then
        utility.debug("watchdog lost: no more mining_target")
        return false
    end
    if mining_target ~= pin.last_mining_target or not pin.last_mining_target.valid then
        utility.debug("watchdog updated: new mining_target")
        pin.last_mining_target = mining_target
        pin.expected_products = utility.mining_products{source = mining_target, items = true}
    end
    if pin.expected_products == nil then
        utility.debug("watchdog lost: no expected_products")
        return false
    end

    if game.tick < pin.tick_should_mine
        then return true end

    local drop_target = handle.drop_target
    if drop_target == nil then
        -- TODO: It drops on ground
        utility.debug("watchdog lost: TODO: drill drops on ground, find the item")
        return false
    end

    focus.watching = transfer_to.next(drop_target)
    return true
end

--- @param focus FocusInstance
--- @param handle LuaEntity
tick_map["item-in-rocket-silo"] = function (focus, handle)
    if handle.rocket ~= nil and handle.rocket_silo_status >= defines.rocket_silo_status.launch_starting then
        utility.debug("watchdog changing: rocket_silo_status launch_started")
        focus.watching = watchdog.create.item_in_rocket(handle.rocket, focus.watching.item)
        return true
    end

    return item_in_container(focus, handle)
end

--- @param focus FocusInstance
--- @param handle LuaEntity
tick_map["item-in-rocket"] = function (focus, handle)
    if handle.cargo_pod ~= nil and handle.cargo_pod.cargo_pod_state == "ascending" then
        utility.debug("watchdog changing: cargo_pod_state ascending")
        focus.watching = watchdog.create.item_in_cargo_pod(handle.cargo_pod, focus.watching.item)
    end

    return true
end

--- @param focus FocusInstance
--- @param handle LuaEntity
--- @param pin PinItemInCargoPod
tick_map["item-in-cargo-pod"] = function (focus, handle, pin)
    if
        handle.cargo_pod_state ~= "parking"
        or (pin.drop_target ~= nil and pin.drop_target.valid)
    then
        return true
    end

    local destination = handle.cargo_pod_destination
    if destination.type ~= defines.cargo_destination.station then
        utility.debug("watchdog lost: cargo_pod_destination is not station")
        return false
    end

    local target = destination.station
    if target == nil then
        -- TODO: It drops as a container
        utility.debug("watchdog lost: station is nil")
        return false
    end

    pin.drop_target = transfer_to.bay_associate_owner(target)
    utility.debug("watchdog updated: drop_target selected")

    -- The actual watchdog switch happens when cargo pod entity is destroyed
    return true
end

--- @param focus FocusInstance
--- @param handle LuaEntity
--- @param pin PinItemInCargoPod
handle_invalid_map["item-in-cargo-pod"] = function (focus, handle, pin)
    utility.debug("watchdog changing: handle got destroyed")
    focus.watching = transfer_to.next(pin.drop_target, focus.watching.item)
    return true
end

--- @param focus FocusInstance
--- @param handle LuaEntity
tick_map["item-in-container-with-cargo-hatches"] = function (focus, handle)
    -- The actual watchdog switch happens on environment_changed
    return item_in_container(focus, handle)
end

--- @param focus FocusInstance
--- @param handle LuaEntity
--- @param pin nil
--- @param cause_entity LuaEntity
environment_changed_map["item-in-container-with-cargo-hatches"] = function (focus, handle, pin, cause_entity)
    if
        cause_entity.type ~= "cargo-pod"
        or cause_entity.cargo_pod_state ~= "awaiting_launch"
        or cause_entity.surface ~= handle.surface
        or cause_entity.cargo_pod_origin ~= handle
    then
        return true
    end

    local pod_inventory = cause_entity.get_inventory(defines.inventory.cargo_unit)
    if
        pod_inventory == nil -- Modded pod I guess?
        or pod_inventory.get_item_count(focus.watching.item) == 0
    then
        return true
    end

    focus.watching = watchdog.create.item_in_cargo_pod(cause_entity, focus.watching.item)
    return true
end

--- @param focus FocusInstance
--- @param handle LuaEntity
tick_map["item-coming-from-asteroid-collector"] = function (focus, handle)
    -- It's basically a container
    return item_in_container(focus, handle)
end

--- @class SmoothingDefinition
--- @field speed? number
--- @field min_speed? number
--- @field mul? number
--- @field ticks integer

--- @type table<string, SmoothingDefinition>
local map_smooth_speed_in = {
    ["item-in-inserter-hand"] = {speed = 0.25, ticks = 60}, -- container -> inserter
    ["item-on-belt"] = {speed = 0.25, ticks = 60}, -- container -> loader, vector_to_place_result -> belt
    ["item-in-container-with-cargo-hatches"] = {min_speed = 0.1, mul = 0.1, ticks = 120}, -- cargo pod -> container
    ["item-in-cargo-pod"] = {min_speed = 0.1, mul = 0.1, ticks = 120} -- container -> cargo pod
}
--- @type table<string, SmoothingDefinition>
local map_smooth_speed_out = {
    ["item-in-inserter-hand"] = {speed = 0.25, ticks = 60}, -- inserter -> container
    ["item-on-belt"] = {speed = 0.25, ticks = 60} -- loader -> container
}

--- @type FocusSmoothingState
local __no_smoothing = {
    final_tick = 0,
    speed = 0,
    min_speed = nil,
    mul = nil
}
---@param a number
---@param b number
---@param nil_larger boolean
local function max_with_nil(a, b, nil_larger)
    if a == nil or b == nil then
        if nil_larger then return nil
        else return a or b end
    end
    return math.max(a, b)
end

--- @param focus FocusInstance
--- @param kind table<string, SmoothingDefinition>
--- @param type string
local function extend_smooth(focus, kind, type)
    local new_smoothing = kind[type]
    if not new_smoothing
        then return end

    local prev = focus.smoothing or __no_smoothing
    local next = {
        final_tick = game.tick + new_smoothing.ticks,
        speed = new_smoothing.speed,
        min_speed = new_smoothing.min_speed,
        mul = new_smoothing.mul
    }
    next.final_tick = math.max(next.final_tick, prev.final_tick)
    next.speed = max_with_nil(next.speed, prev.speed, true)
    next.min_speed = max_with_nil(next.min_speed, prev.min_speed, false)
    next.mul = max_with_nil(next.mul, prev.mul, false)

    if
        new_smoothing.speed ~= nil
        and next.min_speed ~= nil
        and new_smoothing.speed > next.min_speed
    then
        -- If previous had min_speed, but new_smoothing defines speed, that should become next's min_speed
        next.min_speed = new_smoothing.speed
    end

    local previous_final_tick = focus.smoothing and focus.smoothing.final_tick or game.tick
    local extended_by = next.final_tick - previous_final_tick
    focus.smoothing = next
    utility.debug("smoothing extended "..extended_by.." ticks: "..serpent.line(prev).." -> "..serpent.line(next))
end

--- @param map table<string, fun(focus: FocusInstance, handle: LuaEntity, pin?: any, cause_entity?: LuaEntity): boolean>
--- @param focus FocusInstance
--- @param required boolean
--- @param cause_entity? LuaEntity
local function apply_fn(map, focus, required, cause_entity)
    local watching = focus.watching
    local last_watching_type = watching.type

    local fn = map[last_watching_type]
    if not fn then
        return required end
    if not fn(focus, watching.handle, watching.pin, cause_entity)
        then return false end
    if focus.watching == nil
        then return false end

    if focus.watching.type == last_watching_type
        then return true end
    utility.debug("focus watchdog changed from "..last_watching_type.." to "..focus.watching.type)
    extend_smooth(focus, map_smooth_speed_out, last_watching_type)
    extend_smooth(focus, map_smooth_speed_in, focus.watching.type)
    return true
end

local focus_update = {}

--- @param focus FocusInstance
function focus_update.tick(focus)
    if not focus.watching.handle.valid and not apply_fn(handle_invalid_map, focus, true)
        then return false end

    return apply_fn(tick_map, focus, true)
end

--- @param focus FocusInstance
--- @param cause_entity LuaEntity
function focus_update.environment_changed(focus, cause_entity)
    return apply_fn(environment_changed_map, focus, false, cause_entity)
end

return focus_update
