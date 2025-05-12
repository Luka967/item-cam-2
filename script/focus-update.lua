local const = require("const")
local utility = require("utility")
local watchdog = require("focus-watchdog")
local transfer_to = require("focus-transfer")

local handle_invalid_map = {}
local tick_map = {}
local environment_changed_map = {}

tick_map["item-on-ground"] = function ()
    return true
end
--- @param focus FocusInstance
handle_invalid_map["item-on-ground"] = function (focus)
    focus.watching = transfer_to.inserter_nearby(
        focus.surface,
        nil,
        utility.aabb_around(focus.position, const.inserter_search_d),
        focus.position,
        focus.watching.item_wl,
        {swinging_towards = true, source = nil}
    )
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
        elseif const.is_belt[lookup_entry.type] then
            it, next_line_idx = utility.first_on_belt(lookup_entry, seek_fn)
            next_belt = lookup_entry
        else
            -- Loader -> container
            focus.watching = transfer_to.next(lookup_entry, focus.watching.item_wl)
            return true
        end

        if it ~= nil then
            assert(next_belt, "advance didn't give next belt entity")
            assert(next_line_idx, "advance didn't give item line index")
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
        utility.aabb_around(focus.position, const.inserter_search_d),
        focus.position,
        focus.watching.item_wl,
        utility.__no_wl
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
        focus.watching =
            transfer_to.item_on_ground(
                handle.surface,
                handle.drop_position,
                focus.watching.item_wl
            ) or transfer_to.inserter_nearby(
                handle.surface,
                nil,
                utility.aabb_around(handle.drop_position, const.inserter_search_d),
                handle.drop_position,
                focus.watching.item_wl,
                {swinging_towards = true, source = nil}
            )
        return true
    end

    focus.watching = transfer_to.next(dropped_into, focus.watching.item_wl)
    return true
end

--- @param focus FocusInstance
--- @param handle LuaEntity
tick_map["item-in-container"] = function (focus, handle)
    if handle.train and handle.train.riding_state.acceleration ~= defines.riding.acceleration.nothing
        -- In moving train. Nothing to do
        then return true end

    -- Always query if item got taken.
    -- inventory.get_item_count is expensive for huge space platform cargo
    local first_taken_by = transfer_to.taken_out_of_building(handle, focus.watching.item_wl)
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

    local recipe = handle.get_recipe() or handle.previous_recipe
    if recipe == nil then
        utility.debug("watchdog lost: first_taken_by nil and handle no longer has recipe, no result to track")
        return false
    end

    local recipe_products = recipe.products or recipe.name.products
    local first_taken_by = transfer_to.taken_out_of_building(handle, {
        items = utility.products_filtered(recipe_products, {items = true})
    }, handle.prototype.vector_to_place_result ~= nil)
    if first_taken_by ~= nil then
        -- Crafting machine put its (first) output here
        focus.watching = first_taken_by
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
    ) and const.all_deliver_robot_order[order.type]
        then return true end

    utility.debug("watchdog changing: first robot order no longer deliver or target changed")

    if drop_target == nil or not drop_target.valid
        then return false end

    focus.watching = transfer_to.next(drop_target, focus.watching.item_wl)
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

    if game.tick < pin.tick_should_mine
        then return true end

    local first_output = transfer_to.drop_target(handle, focus.watching.item_wl)
    if first_output ~= nil then
        focus.watching = first_output
    end

    return true
end

--- @param focus FocusInstance
--- @param handle LuaEntity
tick_map["item-in-rocket-silo"] = function (focus, handle)
    if handle.rocket ~= nil and handle.rocket_silo_status >= defines.rocket_silo_status.launch_starting then
        utility.debug("watchdog changing: rocket_silo_status launch_started")
        focus.watching = watchdog.create.item_in_rocket(handle.rocket, focus.watching.item_wl.item)
        return true
    end

    return item_in_container(focus, handle)
end

--- @param focus FocusInstance
--- @param handle LuaEntity
tick_map["item-in-rocket"] = function (focus, handle)
    if handle.cargo_pod ~= nil and handle.cargo_pod.cargo_pod_state == "ascending" then
        utility.debug("watchdog changing: cargo_pod_state ascending")
        focus.watching = watchdog.create.item_in_cargo_pod(handle.cargo_pod, focus.watching.item_wl.item)
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

    if target.type == "cargo-bay" then
        pin.drop_target = target.cargo_bay_connection_owner
    else
        pin.drop_target = target
    end
    utility.debug("watchdog updated: drop_target selected")

    -- The actual watchdog switch happens when cargo pod entity is destroyed
    return true
end

--- @param focus FocusInstance
--- @param handle LuaEntity
--- @param pin PinItemInCargoPod
handle_invalid_map["item-in-cargo-pod"] = function (focus, handle, pin)
    utility.debug("watchdog changing: handle got destroyed")
    focus.watching = transfer_to.next(pin.drop_target, focus.watching.item_wl)
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

    local inventory = cause_entity.get_inventory(defines.inventory.cargo_unit)
    assert(inventory, "cause_entity has no targeted inventory")

    local first_item = utility.first_item_stack_filtered(inventory, focus.watching.item_wl)
    if first_item == nil
        then return true end

    focus.watching = watchdog.create.item_in_cargo_pod(cause_entity, utility.item_stack_proto(first_item))
    return true
end

--- @param focus FocusInstance
--- @param handle LuaEntity
tick_map["item-coming-from-asteroid-collector"] = function (focus, handle)
    -- It's basically a container
    return item_in_container(focus, handle)
end

tick_map["seed-in-agricultural-tower"] = function ()
    return true
end

--- If cause entity is new plant, check if tower we're watching owns it
--- @param focus FocusInstance
--- @param handle LuaEntity
--- @param pin nil
--- @param cause_entity LuaEntity
environment_changed_map["seed-in-agricultural-tower"] = function (focus, handle, pin, cause_entity)
    if cause_entity.type ~= "plant"
        then return true end
    if utility.contains(handle.owned_plants, cause_entity) then
        focus.watching = watchdog.create.plant_growing(cause_entity)
    end
    return true
end

--- @param focus FocusInstance
--- @param pin PinPlantGrowing
tick_map["plant-growing"] = function (focus, _, pin)
    -- Crane destination can immediately change on the tick our plant gets destroyed
    -- so we're going to remember their last known position
    for idx, tower_entity in ipairs(pin.last_tick_towers_nearby) do
        if not tower_entity.valid then
            table.remove(pin.last_tick_towers_nearby, idx)
            table.remove(pin.last_tick_crane_destinations, idx)
        else
            pin.last_tick_crane_destinations[idx] = tower_entity.crane_destination
        end
    end

    return true
end

--- @param focus FocusInstance
--- @param handle LuaEntity
--- @param pin PinPlantGrowing
--- @param cause_entity LuaEntity
environment_changed_map["plant-growing"] = function (focus, handle, pin, cause_entity)
    if cause_entity.type ~= "agricultural-tower"
        then return true end

    -- This new tower might include our plant. Recompute last tick
    pin.last_tick_towers_nearby = utility.search_agricultural_towers_owning_plant(handle)
    pin.last_tick_crane_destinations = utility.mapped(pin.last_tick_towers_nearby, function (entry)
        return entry.crane_destination
    end)

    return true
end

--- @param focus FocusInstance
--- @param pin PinPlantGrowing
handle_invalid_map["plant-growing"] = function (focus, _, pin)
    local best_guess, best_idx = utility.minimum_of(pin.last_tick_towers_nearby, function (_, idx)
        utility.debug_pos(focus.surface, pin.last_tick_crane_destinations[idx], const.__dc_min_pass)

        return utility.sq_distance(pin.last_tick_crane_destinations[idx], focus.position), idx
    end)

    if best_guess == nil
        then return end
    utility.debug_pos(focus.surface, pin.last_tick_crane_destinations[best_idx], const.__dc_min_pick)

    -- transfer_to.next assumes the agricultural tower received a seed.
    -- Replicate a simple inserter-took-same-tick check that entities considered container would have
    focus.watching =
        transfer_to.inserter_nearby(
            focus.surface,
            nil, -- Plants lose force
            utility.aabb_expand(best_guess.selection_box, const.inserter_search_d),
            best_guess.position,
            focus.watching.item_wl,
            {source = best_guess, swinging_towards = true}
        ) or watchdog.create.item_coming_from_agricultural_tower(best_guess)
    return true
end

--- @param focus FocusInstance
--- @param handle LuaEntity
tick_map["item-coming-from-agricultural-tower"] = function (focus, handle)
    -- It's basically a container
    return item_in_container(focus, handle)
end

tick_map["end-lab"] = function ()
    return true
end

--- @class SmoothingDefinition
--- @field speed? number
--- @field min_speed? number
--- @field mul? number
--- @field ticks integer

--- @type SmoothingDefinition
local smooth_type_linear = {speed = 0.25, ticks = 60}
--- @type SmoothingDefinition
local smooth_type_jump = {min_speed = 0.1, mul = 0.1, ticks = 120}

--- @type table<string, SmoothingDefinition>
local map_smooth_speed_in = {
    -- container -> inserter
    ["item-in-inserter-hand"] = smooth_type_linear,
    -- container -> loader, vector_to_place_result -> belt
    ["item-on-belt"] = smooth_type_linear,
    -- tower -> plant
    ["plant-growing"] = smooth_type_linear,

    -- cargo pod -> container
    ["item-in-container-with-cargo-hatches"] = smooth_type_jump,
    -- container -> cargo pod
    ["item-in-cargo-pod"] = smooth_type_jump
}
--- @type table<string, SmoothingDefinition>
local map_smooth_speed_out = {
    -- inserter -> container
    ["item-in-inserter-hand"] = smooth_type_linear,
    -- mining drill -> container
    ["item-coming-from-mining-drill"] = smooth_type_linear,
    -- loader -> container
    ["item-on-belt"] = smooth_type_linear,
    -- plant -> tower
    ["plant-growing"] = smooth_type_linear
}

--- @type FocusSmoothingState
local __no_smoothing = {
    final_tick = 0,
    speed = 0,
    min_speed = nil,
    mul = nil
}
--- @param a number
--- @param b number
--- @param nil_larger boolean
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
    if new_smoothing == nil
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
        return not required end
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
    if not focus.watching.handle.valid then
        if not apply_fn(handle_invalid_map, focus, true) then
            return false
        end
    end

    return apply_fn(tick_map, focus, true)
end

--- @param focus FocusInstance
--- @param cause_entity LuaEntity
function focus_update.environment_changed(focus, cause_entity)
    return apply_fn(environment_changed_map, focus, false, cause_entity)
end

return focus_update
