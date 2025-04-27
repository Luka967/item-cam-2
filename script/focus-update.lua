local watchdog = require("focus-watchdog")
local utility = require("utility")

--- @class WatchInserterCandidateRestrictions
--- @field source? LuaEntity
--- @field target? LuaEntity
--- @field item? ItemIDAndQualityIDPair
--- @field swinging_towards? boolean

local __restrictions_noop = {}

--- @param surface LuaSurface
--- @param search_area BoundingBox
--- @param ref_pos MapPosition
--- @param restrictions WatchInserterCandidateRestrictions
local function watch_inserter_candidate(surface, search_area, ref_pos, restrictions)
    local best_guess = utility.minimum_of(surface.find_entities_filtered({
        area = search_area,
        type = "inserter"
    }), function (candidate)
        local held_stack = candidate.held_stack
        if not held_stack.valid_for_read
            then return end
        if restrictions.item ~= nil and (
            held_stack.name ~= restrictions.item.name
            or held_stack.quality ~= restrictions.item.quality
        ) then return end
        if restrictions.source ~= nil and candidate.pickup_target ~= restrictions.source
            then return end
        if restrictions.target ~= nil and candidate.drop_target ~= restrictions.target
            then return end

        local d_ref_pos_to_hand = utility.distance(ref_pos, candidate.held_stack_position)
        if
            restrictions.swinging_towards
            and utility.distance(ref_pos, candidate.position) < d_ref_pos_to_hand
        then return end

        return d_ref_pos_to_hand
    end)

    if best_guess ~= nil then
        return watchdog.create.item_in_inserter_hand(best_guess)
    end
end

--- @class WatchRobotCandidateRestrictions
--- @field item? ItemIDAndQualityIDPair

--- @param surface LuaSurface
--- @param search_area BoundingBox
--- @param ref_pos MapPosition
--- @param restrictions WatchRobotCandidateRestrictions
local function watch_robot_candidate(surface, search_area, ref_pos, restrictions)
    restrictions = restrictions or __restrictions_noop

    local best_guess = utility.minimum_of(surface.find_entities_filtered({
        area = search_area,
        type = utility.all_bot
    }), function (candidate)
        -- It would have been nicer to check for a pickup order.
        -- But because they actually update only every 20 ticks, we'd need a giant surface area scanned every tick
        -- just so that we catch the bot before it updates when order target (ref_pos) is reached.
        -- And here we do these checks *after* they update, so the pickup order is gone
        local inventory = candidate.get_inventory(defines.inventory.robot_cargo)
        local first_stack = inventory[1]
        if not first_stack.valid_for_read
            then return end

        if restrictions.item ~= nil and (
            first_stack.name ~= restrictions.item.name
            or first_stack.quality ~= restrictions.item.quality
        ) then return end

        return utility.distance(ref_pos, candidate.position)
    end)

    if best_guess ~= nil then
        return watchdog.create.item_held_by_robot(best_guess)
    end
end

--- @class WatchItemOnBeltCandidateRestrictions
--- @field item? ItemIDAndQualityIDPair

--- @param target_belt_entity LuaEntity
--- @param restrictions WatchItemOnBeltCandidateRestrictions
local function watch_newest_item_on_belt_candidate(target_belt_entity, restrictions)
    local best_guess, line_idx = utility.minimum_on_belt(target_belt_entity, function (candidate)
        if restrictions.item ~= nil and (
            candidate.stack.name ~= restrictions.item.name
            or candidate.stack.quality ~= restrictions.item.quality
        ) then return end

        return candidate.unique_id
    end)

    if best_guess and line_idx then
        return watchdog.create.item_on_belt(best_guess, line_idx, target_belt_entity)
    end
end

--- @param entity LuaEntity
--- @param item? ItemIDAndQualityIDPair
local function watch_next(entity, item)
    local entity_type = entity.type
    if utility.is_belt[entity_type] then
        return watch_newest_item_on_belt_candidate(
            entity,
            {item = item}
        )
    end
    if entity_type == "inserter" then
        return watchdog.create.item_in_inserter_hand(entity)
    end
    if utility.is_crafting_machine[entity_type] then
        return watchdog.create.item_in_crafting_machine(entity)
    end
    if utility.is_container[entity_type] then
        --- Transfer to pickup inserter can happen in same tick.
        --- If it did we'd see 0 count in inventory
        local inventory_type = utility.is_container[entity_type]
        local inventory = entity.get_inventory(inventory_type)

        if inventory.get_item_count(item) > 0 then
            if #entity.cargo_hatches > 0
                then return watchdog.create.item_in_container_with_cargo_hatches(entity, item) end
            return watchdog.create.item_in_container(entity, inventory_type, item)
        end

        utility.debug("watchdog watch_next: item from container was already taken by inserter")
        return watch_inserter_candidate(
            entity.surface,
            utility.aabb_expand(entity.bounding_box, utility.inserter_search_d),
            entity.position,
            {item = item, source = entity}
        )
    end
end

--- @param entity LuaEntity
--- @param item? ItemIDAndQualityIDPair
local function watch_drop_target(entity, item)
    if entity.prototype.vector_to_place_result == nil
        then return end

    if entity.drop_target ~= nil then
        return watch_next(entity.drop_target, item)
    end

    local dropped_item_entity = entity.surface.find_entities_filtered({
        position = entity.drop_position,
        type = {"item-entity"}
    })
    if dropped_item_entity == nil
        then return end
    return watch_next(dropped_item_entity, item)
end

--- @param entity LuaEntity
--- @param item? ItemIDAndQualityIDPair
--- @param also_drop_target? boolean
local function watch_taken_out_of_building(entity, item, also_drop_target)
    return
        (also_drop_target and watch_drop_target(entity, item))
        or watch_inserter_candidate(
            entity.surface,
            utility.aabb_expand(entity.bounding_box, utility.inserter_search_d),
            entity.position,
            {source = entity, item = item}
        ) or watch_robot_candidate(
            entity.surface,
            utility.aabb_expand(entity.bounding_box, utility.robot_search_d),
            entity.position,
            {item = item}
        )
end

--- @param focus FocusInstance
local function item_entity(focus)
    return true
end

--- @param focus FocusInstance
--- @param handle LuaEntity
--- @param pin PinItemOnBelt
local function item_on_belt(focus, handle, pin)
    --- @type LuaEntity?
    local next_belt = handle
    --- @type integer?
    local next_line_idx = pin.line_idx

    local seek_fn = function (item)
        return item.unique_id == pin.id
    end

    local it = utility.first_on_line(handle.get_transport_line(pin.line_idx), seek_fn)

    -- Passed through splitter or through part of underground
    if it == nil and handle.type ~= "transport-belt" then
        it, next_line_idx = utility.first_on_belt(handle, seek_fn)
    end

    -- Passed to output side of underground
    if it == nil and handle.type == "underground-belt" and handle.belt_to_ground_type == "input" then
        it, next_line_idx, next_belt = utility.first_on_belts({handle.neighbours}, seek_fn)
    end

    -- Passed to next belt
    if it == nil then
        it, next_line_idx, next_belt = utility.first_on_belts(handle.belt_neighbours.outputs, seek_fn)
    end

    -- Taken by inserter, bot, or deconstructed
    if it == nil then
        utility.debug("watchdog changing: can't find item on belt with my id")
        focus.watching = watch_inserter_candidate(
            handle.surface,
            utility.aabb_around(focus.position, utility.inserter_search_d),
            focus.position,
            {item = focus.watching.item}
        )
        return true
    end

    if it == nil
        then return false end
    focus.watching.handle = next_belt
    pin.it = it
    pin.line_idx = next_line_idx
    return true
end

--- @param focus FocusInstance
--- @param handle LuaEntity
local function item_in_inserter_hand(focus, handle)
    --- @type LuaEntity
    local handle = focus.watching.handle

    if handle.held_stack.valid_for_read
        then return true end

    utility.debug("watchdog changing: held_stack.valid_for_read false")

    local dropped_into = handle.drop_target
    if dropped_into == nil then
        utility.debug("watchdog lost: dropped_into nil")
        return false
    end

    focus.watching = watch_next(dropped_into, focus.watching.item)
    return true
end

--- @param focus FocusInstance
--- @param handle LuaEntity
--- @param pin PinItemInContainer
local function item_in_container(focus, handle, pin)
    --- @type ItemIDAndQualityIDPair
    local item = focus.watching.item

    local item_count = pin.inventory.get_item_count(item)
    if item_count == 0 and pin.last_tick_count == 0 then
        -- Where did it go?
        utility.debug("watchdog lost: item wasn't even here last tick")
        return false
    elseif item_count >= pin.last_tick_count then
        pin.last_tick_count = item_count
        return true
    end

    utility.debug("watchdog changing: item_count decreased")

    -- Taken by bot or inserter
    focus.watching = watch_taken_out_of_building(handle, item, true)
    return true
end

--- @param focus FocusInstance
--- @param handle LuaEntity
local function item_in_crafting_machine(focus, handle)
    if handle.products_finished == focus.watching.pin.initial_products_finished
        then return true end

    utility.debug("watchdog changing: products_finished increased")

    local first_taken_by = watch_taken_out_of_building(handle, nil, true)
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
local function item_held_by_robot(focus, handle, pin)
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

    focus.watching = watch_next(drop_target, focus.watching.item)
    return true
end

--- @param focus FocusInstance
--- @param handle LuaEntity
--- @param pin PinItemComingFromMiningDrill
local function item_coming_from_mining_drill(focus, handle, pin)
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
    if drop_target ~= nil then
        if not utility.is_belt[drop_target.type] then
            focus.watching = watch_next(drop_target)
        end

        local drop_line_idx = utility.mining_drill_drop_belt_line_idx[handle.direction]

        local best_guess, line_idx = utility.minimum_on_belt(drop_target, function (candidate, line_idx)
            if line_idx ~= drop_line_idx or not utility.contains(pin.expected_products, candidate.stack.name)
                then return end
            return utility.distance(
                handle.drop_position,
                drop_target.get_line_item_position(line_idx, candidate.position)
            )
        end)

        if best_guess and line_idx then
            focus.watching = watchdog.create.item_on_belt(best_guess, line_idx, drop_target)
        end
    else
        -- TODO: It drops on ground
        utility.debug("watchdog lost: TODO: drill drops on ground, find the item")
        return false
    end

    return true
end

--- @param focus FocusInstance
--- @param handle LuaEntity
--- @param pin PinItemInRocketSilo
local function item_in_rocket_silo(focus, handle, pin)
    if handle.rocket ~= nil and handle.rocket_silo_status >= defines.rocket_silo_status.launch_starting then
        utility.debug("watchdog changing: rocket_silo_status launch_started")
        focus.watching = watchdog.create.item_in_rocket(handle.rocket, focus.watching.item)
        return true -- Don't check inventory afterwards
    end

    if pin.inventory.get_item_count(focus.watching.item) == 0 then
        utility.debug("watchdog changing: get_item_count for tracked item 0")
        focus.watching = watch_taken_out_of_building(handle, focus.watching.item)
    end

    return true
end

--- @param focus FocusInstance
--- @param handle LuaEntity
local function item_in_rocket(focus, handle)
    if handle.cargo_pod ~= nil and handle.cargo_pod.cargo_pod_state == "ascending" then
        utility.debug("watchdog changing: cargo_pod_state ascending")
        focus.watching = watchdog.create.item_in_cargo_pod(handle.cargo_pod, focus.watching.item)
    end

    return true
end

--- @param destination CargoDestination
local function select_pod_drop_target(destination)
    if destination.type ~= defines.cargo_destination.station then
        utility.debug("watchdog select_pod_drop_target: cargo_pod_destination is not station")
        return nil
    end

    local target = destination.station
    if target == nil then
        utility.debug("watchdog select_pod_drop_target: station is nil")
        return nil
    end

    if target.type ~= "cargo-bay"
        then return target end

    if destination.space_platform ~= nil
        then return destination.space_platform.hub end
    if destination.surface ~= nil then
        -- TODO: It goes into landing pad, but API has no association backwards to landing pad
        utility.debug("watchdog select_pod_drop_target: TODO: going to cargo-bay but can't associate landing pad")
        return nil
    end
end
--- @param focus FocusInstance
--- @param handle LuaEntity
--- @param pin PinItemInCargoPod
local function item_in_cargo_pod(focus, handle, pin)
    if pin.drop_target == nil and handle.cargo_pod_state == "parking" then
        local destination = select_pod_drop_target(handle.cargo_pod_destination)

        utility.debug("watchdog updated: drop_target selected")
        pin.drop_target = destination
        return true
    end

    -- The actual watchdog switch happens after destroy
    return true
end
--- @param focus FocusInstance
--- @param handle LuaEntity
--- @param pin PinItemInCargoPod
local function item_in_cargo_pod_after_destroy(focus, handle, pin)
    utility.debug("watchdog changing: handle got destroyed")
    focus.watching = watch_next(pin.drop_target, focus.watching.item)
    return true
end

--- @param entity LuaEntity
local function watch_outgoing_cargo_pod(entity, item)
    local has_busy_outgoing_hatch = utility.first(entity.cargo_hatches, function (hatch)
        return hatch.is_output_compatible and (hatch.busy or hatch.reserved)
    end)
    if not has_busy_outgoing_hatch
        then return end

    local nearby_pod = entity.surface.find_entities_filtered({
        area = entity.bounding_box,
        type = {"cargo-pod"}
    })
    for _, candidate in ipairs(nearby_pod) do
        local inventory = candidate.get_inventory(defines.inventory.cargo_unit)
        if inventory.get_item_count(item) > 0 then
            return watchdog.create.item_in_cargo_pod(candidate, item)
        end
    end
end

--- @param focus FocusInstance
--- @param handle LuaEntity
--- @param pin PinItemInContainerWithCargoHatches
local function item_in_container_with_cargo_hatches(focus, handle, pin)
    local item = focus.watching.item

    local first_taken_by =
        watch_outgoing_cargo_pod(handle, item)
        or utility.first(handle.get_cargo_bays(), function (bay)
            if not bay.valid
                then return end
            return watch_outgoing_cargo_pod(bay, item)
        end)

    if first_taken_by ~= nil then
        focus.watching = first_taken_by
        return true
    end

    -- It's also a container. Inherit container update behavior
    return item_in_container(focus, handle, pin)
end

local map = {
    ["item-entity"] = item_entity,
    ["item-on-belt"] = item_on_belt,
    ["item-in-inserter-hand"] = item_in_inserter_hand,
    ["item-in-container"] = item_in_container,
    ["item-in-crafting-machine"] = item_in_crafting_machine,
    ["item-held-by-robot"] = item_held_by_robot,
    ["item-coming-from-mining-drill"] = item_coming_from_mining_drill,
    ["item-in-rocket-silo"] = item_in_rocket_silo,
    ["item-in-rocket"] = item_in_rocket,
    ["item-in-cargo-pod"] = item_in_cargo_pod,
    ["item-in-container-with-cargo-hatches"] = item_in_container_with_cargo_hatches
}
local map_after_destroy = {
    ["item-in-cargo-pod"] = item_in_cargo_pod_after_destroy
}

--- @param focus FocusInstance
return function (focus)
    if not focus.watching.handle.valid then
        local fnd = map_after_destroy[focus.watching.type]
        if
            not fnd
            or not fnd(focus, focus.watching.handle, focus.watching.pin)
            or focus.watching == nil -- After calling fnd
        then
            focus.valid = false
            return false
        end
    end

    local fn = map[focus.watching.type]

    if
        not fn
        or not fn(focus, focus.watching.handle, focus.watching.pin)
        or focus.watching == nil -- After calling fn
    then
        focus.valid = false
        return false
    end

    return true
end
