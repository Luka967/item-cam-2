local watchdog = require("focus-watchdog")
local utility = require("utility")

--- @param item? ItemIDAndQualityIDPair
--- @param last_position MapPosition
--- @param area BoundingBox
--- @param surface LuaSurface
local function watch_inserter_candidate(item, last_position, area, surface)
    local best_guess = utility.minimum_of(surface.find_entities_filtered({
        area = area,
        type = "inserter"
    }), function (inserter_entity)
        if item ~= nil then
            local held_stack = inserter_entity.held_stack
            if not held_stack.valid_for_read
                or held_stack.name ~= item.name
                or held_stack.quality ~= item.quality
            then return end
        end

        return utility.distance(last_position, inserter_entity.held_stack_position)
    end)

    if best_guess ~= nil then
        return watchdog.create.item_in_inserter_hand(best_guess)
    end
end

--- @param targeted_entity LuaEntity
local function watch_bot_candidate(targeted_entity)
    local targeted_entity_position = targeted_entity.position

    local best_guess = utility.minimum_of(targeted_entity.surface.find_entities_filtered({
        area = utility.aabb_expand(targeted_entity.bounding_box, utility.bot_search_d),
        type = utility.all_bot
    }), function (bot_entity)
        local first_order = bot_entity.robot_order_queue[1]
        if not utility.all_pickup_robot_order[first_order]
            then return end
        if first_order.target ~= targeted_entity and first_order.secondary_target ~= targeted_entity
            then return end

        return utility.distance(targeted_entity_position, bot_entity.position)
    end)

    if best_guess ~= nil then
        return watchdog.create.item_held_by_robot(best_guess)
    end
end

--- @param last_position MapPosition
--- @param target_belt_entity LuaEntity
--- @param item ItemIDAndQualityIDPair
local function watch_item_on_belt_candidate(last_position, target_belt_entity, item)
    local best_guess, line_idx = utility.minimum_on_belt(target_belt_entity, function (potential, line)
        if potential.stack.name ~= item.name or potential.stack.quality ~= item.quality
            then return end
        return utility.distance(last_position, line.get_line_item_position(potential.position))
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
        focus.watching = watch_item_on_belt_candidate(
            focus.position,
            entity,
            focus.watching.item
        )
    elseif entity_type == "inserter" then
        focus.watching = watchdog.create.item_in_inserter_hand(entity)
    elseif utility.is_crafting_machine[entity_type] then
        focus.watching = watchdog.create.item_in_crafting_machine(entity)
    elseif utility.is_container[entity_type] then
        local inventory_type = utility.is_container[entity_type]
        focus.watching = watchdog.create.item_in_container(entity, inventory_type, focus.watching.item)
    else
        return false
    end

    return true
end

--- @param focus FocusInstance
local function item_entity(focus)
    return true
end

--- @param focus FocusInstance
local function item_on_belt(focus)
    --- @type PinItemOnBelt
    local pin = focus.watching.pin
    local belt_entity = focus.watching.handle

    --- @type integer|nil
    local next_line_idx = pin.line_idx
    --- @type LuaEntity|nil
    local next_belt = belt_entity

    local seek_fn = function (item)
        return item.unique_id == pin.id
    end

    local it = utility.first_on_line(belt_entity.get_transport_line(pin.line_idx), seek_fn)

    -- Passed through splitter or through part of underground
    if it == nil and belt_entity.type ~= "transport-belt" then
        it, next_line_idx = utility.first_on_belt(belt_entity, seek_fn)
    end

    -- Passed to output side of underground
    if it == nil and belt_entity.type == "underground-belt" and belt_entity.belt_to_ground_type == "input" then
        it, next_line_idx, next_belt = utility.first_on_belts({belt_entity.neighbours}, seek_fn)
    end

    -- Passed to next belt
    if it == nil then
        it, next_line_idx, next_belt = utility.first_on_belts(belt_entity.belt_neighbours.outputs, seek_fn)
    end

    -- Taken by inserter, bot, or deconstructed
    if it == nil then
        focus.watching = watch_inserter_candidate(
            focus.watching.item,
            focus.position,
            utility.aabb_around(focus.position, utility.inserter_search_d),
            belt_entity.surface
        )
        return true
    end

    if it == nil or next_belt == nil or next_line_idx == nil
        then return false end
    focus.watching.handle = next_belt
    pin.it = it
    pin.line_idx = next_line_idx
    return true
end

--- @param focus FocusInstance
local function item_in_inserter_hand(focus)
    --- @type LuaEntity
    local inserter_entity = focus.watching.handle
    --- @type ItemIDAndQualityIDPair
    local item = focus.watching.item

    if inserter_entity.held_stack.valid_for_read then
        if item == nil then
            focus.watching.item = {
                name = inserter_entity.held_stack.name,
                quality = inserter_entity.held_stack.quality
            }
        end
        return true
    end

    local dropped_into = inserter_entity.drop_target
    if dropped_into == nil
        then return false end

    return watch_next(focus, dropped_into)
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

    --- @type LuaEntity
    local entity = focus.watching.handle
    -- Taken by bot or inserter
    focus.watching = watch_inserter_candidate(
        item,
        entity.position,
        utility.aabb_expand(entity.bounding_box, utility.inserter_search_d),
        entity.surface
    ) or watch_bot_candidate(entity)
    return true
end

--- @param focus FocusInstance
local function item_in_crafting_machine(focus)
    local crafting_entity = focus.watching.handle
    if crafting_entity.get_recipe() == nil
        then return false end

    local first_taken_by = watch_inserter_candidate(
        nil,
        crafting_entity.position,
        utility.aabb_expand(crafting_entity.bounding_box, utility.inserter_search_d),
        crafting_entity.surface
    ) or watch_bot_candidate(crafting_entity)

    if first_taken_by ~= nil then
        -- Crafting machine put its first output here
        focus.watching = first_taken_by
        return true
    end

    -- if pin.place_output ~= nil then
    --     local best_guess, line_idx = utility.minimum_on_belt(pin.place_output, function (item, line)
    --         if item.stack.name ~= item
    --             then return end
    --         return utility.distance(last_position, line.get_line_item_position(item.position))
    --     end)
    -- end

    return true
end

--- @param focus FocusInstance
local function item_held_by_robot(focus)
    local robot_entity = focus.watching.handle

    if #robot_entity.robot_order_queue == 0
        then return false end

    local order = robot_entity.robot_order_queue[1]
    if not utility.all_suitable_robot_order[order.type]
        then return false end
    if utility.all_pickup_robot_order[order.type] then
        -- Pickup order doesn't get dequeued immediately
        order = robot_entity.robot_order_queue[2]
    end

    local dropping_to = order.target
    if dropping_to == nil or not dropping_to.valid
        then return false end

    --- @type PinItemHeldByRobot
    local pin = focus.watching.pin
    if pin.inventory.get_item_count(focus.watching.item) > 0
        then return true end

    return watch_next(focus, dropping_to)
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
