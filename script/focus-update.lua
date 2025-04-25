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
    local best_guess, line_idx = utility.minimum_on_belt(target_belt_entity, function (candidate, line)
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

--- @param focus FocusInstance
--- @param entity LuaEntity
local function watch_next(focus, entity)
    local entity_type = entity.type
    if utility.is_belt[entity_type] then
        return watch_newest_item_on_belt_candidate(
            entity,
            {item = focus.watching.item}
        )
    elseif entity_type == "inserter" then
        return watchdog.create.item_in_inserter_hand(entity)
    elseif utility.is_crafting_machine[entity_type] then
        return watchdog.create.item_in_crafting_machine(entity)
    elseif utility.is_container[entity_type] then
        return watchdog.create.item_in_container(
            entity,
            utility.is_container[entity_type],
            focus.watching.item
        )
    end
end

--- @param focus FocusInstance
--- @param entity LuaEntity
local function watch_drop_target(focus, entity)
    if entity.prototype.vector_to_place_result == nil
        then return end

    if entity.drop_target ~= nil then
        return watch_next(focus, entity.drop_target)
    end

    local dropped_item_entity = entity.surface.find_entities_filtered({
        position = entity.drop_position,
        type = {"item-entity"}
    })
    if dropped_item_entity == nil
        then return end
    return watch_next(focus, dropped_item_entity)
end

--- @param focus FocusInstance
local function item_entity(focus)
    return true
end

--- @param focus FocusInstance
local function item_on_belt(focus)
    --- @type PinItemOnBelt
    local pin = focus.watching.pin
    local handle = focus.watching.handle

    --- @type integer?
    local next_line_idx = pin.line_idx
    --- @type LuaEntity?
    local next_belt = handle

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
local function item_in_inserter_hand(focus)
    --- @type LuaEntity
    local handle = focus.watching.handle

    if handle.held_stack.valid_for_read
        then return true end

    utility.debug("watchdog changing: held_stack.valid_for_read false")

    local dropped_into = handle.drop_target
    if dropped_into == nil
        then return false end

    focus.watching = watch_next(focus, dropped_into)
    return true
end

--- @param focus FocusInstance
local function item_in_container(focus)
    --- @type ItemIDAndQualityIDPair
    local item = focus.watching.item
    --- @type PinItemInContainer
    local pin = focus.watching.pin

    local item_count = pin.inventory.get_item_count(item)
    if item_count == 0 and pin.last_tick_count == 0 then
        -- Where did it go?
        return false
    elseif item_count >= pin.last_tick_count then
        pin.last_tick_count = item_count
        return true
    end

    utility.debug("watchdog changing: item_count decreased")

    --- @type LuaEntity
    local handle = focus.watching.handle
    -- Taken by bot or inserter
    focus.watching = watch_inserter_candidate(
        handle.surface,
        utility.aabb_expand(handle.bounding_box, utility.inserter_search_d),
        handle.position,
        {item = item, swinging_towards = true}
    ) or watch_robot_candidate(
        handle.surface,
        utility.aabb_expand(handle.bounding_box, utility.robot_search_d),
        handle.position,
        {item = item}
    )
    return true
end

--- @param focus FocusInstance
local function item_in_crafting_machine(focus)
    local entity = focus.watching.handle
    if entity.products_finished == focus.watching.pin.initial_products_finished
        then return true end

    utility.debug("watchdog changing: products_finished increased")

    local first_taken_by = watch_inserter_candidate(
        entity.surface,
        utility.aabb_expand(entity.bounding_box, utility.inserter_search_d),
        entity.position,
        {source = entity}
    ) or watch_robot_candidate(
        entity.surface,
        utility.aabb_expand(entity.bounding_box, utility.robot_search_d),
        entity.position,
        __restrictions_noop
    ) or watch_drop_target(focus, entity)

    if first_taken_by ~= nil then
        -- Crafting machine put its (first) output here
        focus.watching = first_taken_by
    elseif first_taken_by == nil and entity.get_recipe() == nil then
        -- If this is furnace (recycler) and we found no candidates then there were no products
        return false
    end

    return true
end

--- @param focus FocusInstance
local function item_held_by_robot(focus)
    local handle = focus.watching.handle

    if #handle.robot_order_queue == 0
        then return false end

    local order = handle.robot_order_queue[1]
    if utility.all_deliver_robot_order[order.type]
        then return true end

    local dropping_to = focus.watching.pin.drop_target
    if dropping_to == nil or not dropping_to.valid
        then return false end

    focus.watching = watch_next(focus, dropping_to)
end

local map = {
    ["item-entity"] = item_entity,
    ["item-on-belt"] = item_on_belt,
    ["item-in-inserter-hand"] = item_in_inserter_hand,
    ["item-in-container"] = item_in_container,
    ["item-in-crafting-machine"] = item_in_crafting_machine,
    ["item-held-by-robot"] = item_held_by_robot
}

--- @param focus FocusInstance
return function (focus)
    if not focus.watching.handle.valid then
        focus.valid = false
        return false
    end

    local fn = map[focus.watching.type]

    if not fn or not fn(focus) or focus.watching == nil then
        focus.valid = false
        return false
    end

    return true
end
