local watchdog = require("focus-watchdog")
local transfer_to = require("focus-transfer")
local utility = require("utility")

local update_map = {}
local destroy_map = {}

--- @param focus FocusInstance
update_map["item-entity"] = function (focus)
    return true
end

--- @param focus FocusInstance
--- @param handle LuaEntity
--- @param pin PinItemOnBelt
update_map["item-on-belt"] = function (focus, handle, pin)
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
        focus.watching = transfer_to.inserter_nearby(
            handle.surface,
            handle.force,
            utility.aabb_around(focus.position, utility.inserter_search_d),
            focus.position,
            {item = focus.watching.item}
        )
        return true
    end

    if it == nil or next_line_idx == nil or next_belt == nil
        then return false end
    focus.watching.handle = next_belt
    pin.it = it
    pin.line_idx = next_line_idx
    return true
end

--- @param focus FocusInstance
--- @param handle LuaEntity
update_map["item-in-inserter-hand"] = function (focus, handle)
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
update_map["item-in-container"] = function (focus, handle)
    -- Always query if item got taken.
    -- inventory.get_item_count is expensive for huge space platform cargo
    local first_taken_by = transfer_to.taken_out_of_building(handle, focus.watching.item)
    if first_taken_by ~= nil then
        focus.watching = first_taken_by
    end
    return true
end
local item_in_container = update_map["item-in-container"]

--- @param focus FocusInstance
--- @param handle LuaEntity
--- @param pin PinItemInCraftingMachine
update_map["item-in-crafting-machine"] = function (focus, handle, pin)
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
update_map["item-held-by-robot"] = function (focus, handle, pin)
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
update_map["item-coming-from-mining-drill"] = function (focus, handle, pin)
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

    -- Belts have special handling because it can only drop in predetermined locations
    -- TODO: transfer_to.drop_target should be doing this
    if not utility.is_belt[drop_target.type] then
        focus.watching = transfer_to.next(drop_target)
        return true
    end

    local drop_line_idx = utility.mining_drill_drop_belt_line_idx[handle.direction][drop_target.direction]

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
    return true
end

--- @param focus FocusInstance
--- @param handle LuaEntity
update_map["item-in-rocket-silo"] = function (focus, handle)
    if handle.rocket ~= nil and handle.rocket_silo_status >= defines.rocket_silo_status.launch_starting then
        utility.debug("watchdog changing: rocket_silo_status launch_started")
        focus.watching = watchdog.create.item_in_rocket(handle.rocket, focus.watching.item)
        return true
    end

    return item_in_container(focus, handle)
end

--- @param focus FocusInstance
--- @param handle LuaEntity
update_map["item-in-rocket"] = function (focus, handle)
    if handle.cargo_pod ~= nil and handle.cargo_pod.cargo_pod_state == "ascending" then
        utility.debug("watchdog changing: cargo_pod_state ascending")
        focus.watching = watchdog.create.item_in_cargo_pod(handle.cargo_pod, focus.watching.item)
    end

    return true
end

--- @param focus FocusInstance
--- @param handle LuaEntity
--- @param pin PinItemInCargoPod
update_map["item-in-cargo-pod"] = function (focus, handle, pin)
    if pin.drop_target == nil and handle.cargo_pod_state == "parking" then
        utility.debug("watchdog updated: drop_target selected")
        pin.drop_target = transfer_to.pod_drop_target_normalized(handle.cargo_pod_destination)
        return true
    end

    -- The actual watchdog switch happens after destroy
    return true
end

--- @param focus FocusInstance
--- @param handle LuaEntity
update_map["item-in-container-with-cargo-hatches"] = function (focus, handle)
    local item = focus.watching.item

    local first_taken_by =
        transfer_to.outgoing_cargo_pod(handle, item) -- Hub / landing pad itself
        or utility.first(handle.get_cargo_bays(), function (bay) -- Its cargo bays
            return bay.valid and transfer_to.outgoing_cargo_pod(bay, item) or nil
        end)

    if first_taken_by ~= nil then
        focus.watching = first_taken_by
        return true
    end

    return item_in_container(focus, handle)
end

--- @param focus FocusInstance
--- @param pin PinItemInCargoPod
destroy_map["item-in-cargo-pod"] = function (focus, pin)
    utility.debug("watchdog changing: handle got destroyed")
    focus.watching = transfer_to.next(pin.drop_target, focus.watching.item)
    return true
end

--- @class SmoothingDefinition
--- @field speed? number
--- @field min_speed? number
--- @field mul? number
--- @field ticks integer

--- @type table<string, SmoothingDefinition>
local map_smooth_speed_in = {
    ["item-in-inserter-hand"] = {speed = 0.25, ticks = 60},
    ["item-in-container-with-cargo-hatches"] = {min_speed = 0.1, mul = 0.1, ticks = 120}
}
--- @type table<string, SmoothingDefinition>
local map_smooth_speed_out = {
    ["item-in-inserter-hand"] = {speed = 0.25, ticks = 60},
    ["item-in-container-with-cargo-hatches"] = {min_speed = 0.1, mul = 0.1, ticks = 120}
}

--- @param focus FocusInstance
--- @param kind table<string, SmoothingDefinition>
--- @param type string
local function extend_smooth(focus, kind, type)
    local new_smoothing = kind[type]
    if not new_smoothing
        then return end

    local previous_final_tick = focus.smoothing and focus.smoothing.final_tick or game.tick
    local using_speed -- Maximum of current and new
    if focus.smoothing and focus.smoothing.speed == nil then
        using_speed = nil
    elseif focus.smoothing then
        using_speed = math.max(new_smoothing.speed, focus.smoothing.speed)
    else
        using_speed = new_smoothing.speed
    end
    focus.smoothing = {
        final_tick = math.max(previous_final_tick, game.tick + new_smoothing.ticks),
        speed = using_speed,
        min_speed = new_smoothing.min_speed,
        mul = new_smoothing.mul
    }

    local extended_by = focus.smoothing.final_tick - previous_final_tick
    utility.debug("smoothing extended "..extended_by.." ticks: "..serpent.line(focus.smoothing))
end

--- @param focus FocusInstance
return function (focus)
    local watching = focus.watching
    local last_watching_type = watching.type

    if not watching.handle.valid then
        local fnd = destroy_map[watching.type]
        if
            not fnd
            or not fnd(focus, watching.pin)
            or focus.watching == nil -- After calling fnd
        then
            focus.valid = false
            return false
        end

        watching = focus.watching
        if watching.type ~= last_watching_type then
            utility.debug("invalid handle change focus from "..last_watching_type.." to "..watching.type)
            extend_smooth(focus, map_smooth_speed_out, last_watching_type)
            extend_smooth(focus, map_smooth_speed_in, watching.type)
            last_watching_type = watching.type
        end
    end

    local fn = update_map[watching.type]

    if
        not fn
        or not fn(focus, watching.handle, watching.pin)
        or focus.watching == nil -- After calling fn
    then
        focus.valid = false
        return false
    end

    watching = focus.watching
    if watching.type ~= last_watching_type then
        utility.debug("change focus from "..last_watching_type.." to "..watching.type)
        extend_smooth(focus, map_smooth_speed_out, last_watching_type)
        extend_smooth(focus, map_smooth_speed_in, watching.type)
    end

    return true
end
