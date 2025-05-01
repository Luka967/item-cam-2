local state = require("state")
local utility = require("utility")
local watchdog = require("focus-watchdog")

local transfer_to = {}

--- @class WatchInserterCandidateRestrictions
--- @field source? LuaEntity
--- @field target? LuaEntity
--- @field item? ItemIDAndQualityIDPair
--- @field swinging_towards? boolean

--- @param surface LuaSurface
--- @param force ForceID
--- @param search_area BoundingBox
--- @param ref_pos MapPosition
--- @param restrictions WatchInserterCandidateRestrictions
function transfer_to.inserter_nearby(surface, force, search_area, ref_pos, restrictions)
    local best_guess = utility.minimum_of(surface.find_entities_filtered({
        area = search_area,
        type = "inserter",
        force = force
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

        if not restrictions.swinging_towards then
            return utility.distance(ref_pos, candidate.held_stack_position)
        end

        local d_hand_to_pickup = utility.distance(candidate.held_stack_position, candidate.pickup_position)
        if d_hand_to_pickup > utility.inserter_search_d_picking_up_feather
            then return end

        return d_hand_to_pickup
    end)

    if best_guess ~= nil then
        return watchdog.create.item_in_inserter_hand(best_guess)
    end
end

--- @class WatchRobotCandidateRestrictions
--- @field item? ItemIDAndQualityIDPair

--- @param surface LuaSurface
--- @param force ForceID
--- @param search_area BoundingBox
--- @param ref_pos MapPosition
--- @param restrictions WatchRobotCandidateRestrictions
function transfer_to.robot_nearby(surface, force, search_area, ref_pos, restrictions)
    local best_guess = utility.minimum_of(surface.find_entities_filtered({
        area = search_area,
        type = utility.all_bot,
        force = force
    }), function (candidate)
        -- It would have been nicer to check for a pickup order.
        -- But because they actually update only every 20 ticks, we'd need a giant surface area scanned every tick
        -- just so that we catch the bot before it updates when order target (ref_pos) is reached.
        -- And here we do these checks *after* they update, so the pickup order is gone
        local inventory = candidate.get_inventory(defines.inventory.robot_cargo)
        assert(inventory ~= nil, "transfer_to.robot_nearby doesn't have targeted inventory")

        local first_stack = utility.first_readable_item_stack(inventory)
        if not first_stack
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
function transfer_to.newest_item_on_belt(target_belt_entity, restrictions)
    local best_guess, line_idx = utility.minimum_on_belt(target_belt_entity, function (candidate)
        if restrictions.item ~= nil and (
            candidate.stack.name ~= restrictions.item.name
            or candidate.stack.quality ~= restrictions.item.quality
        ) then return end

        return -candidate.unique_id -- Pick newest
    end)

    if best_guess and line_idx then
        return watchdog.create.item_on_belt(best_guess, line_idx, target_belt_entity)
    end
end

--- @param entity LuaEntity
--- @param item? ItemIDAndQualityIDPair
function transfer_to.next(entity, item)
    local entity_type = entity.type
    if utility.is_belt[entity_type] then
        return transfer_to.newest_item_on_belt(
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
        assert(item ~= nil, "transfer_to.next to container expected item in focus")
        --- Transfer to pickup inserter can happen in same tick.
        --- If it did we'd see 0 count in inventory
        local inventory = entity.get_inventory(utility.is_container[entity_type])
        assert(inventory ~= nil, "transfer_to.next to container doesn't have targeted inventory")

        if inventory.get_item_count(item) > 0 then
            return watchdog.create.item_in_container(entity, item)
        end

        utility.debug("transfer_to.next: item from container was already taken by inserter")
        return transfer_to.inserter_nearby(
            entity.surface,
            entity.force,
            utility.aabb_expand(entity.bounding_box, utility.inserter_search_d),
            entity.position,
            {item = item, source = entity}
        )
    end
end

--- @param entity LuaEntity
--- @param item? ItemIDAndQualityIDPair
function transfer_to.drop_target(entity, item)
    if entity.prototype.vector_to_place_result == nil
        then return end

    if entity.drop_target ~= nil then
        return transfer_to.next(entity.drop_target, item)
    end

    local dropped_item_entity = entity.surface.find_entities_filtered({
        position = entity.drop_position,
        type = {"item-entity"},
        force = entity.force
    })
    if dropped_item_entity == nil
        then return end
    return transfer_to.next(dropped_item_entity, item)
end

--- @param entity LuaEntity
--- @param item? ItemIDAndQualityIDPair
--- @param also_drop_target? boolean
function transfer_to.taken_out_of_building(entity, item, also_drop_target)
    return
        (also_drop_target and transfer_to.drop_target(entity, item))
        or transfer_to.inserter_nearby(
            entity.surface,
            entity.force,
            utility.aabb_expand(entity.bounding_box, utility.inserter_search_d),
            entity.position,
            {source = entity, item = item, swinging_towards = true}
        ) or transfer_to.robot_nearby(
            entity.surface,
            entity.force,
            utility.aabb_expand(entity.bounding_box, utility.robot_search_d),
            entity.position,
            {item = item}
        )
end

--- @param target LuaEntity
function transfer_to.bay_associate_owner(target)
    if target.type ~= "cargo-bay" then
        return target
    end

    if target.surface.platform ~= nil then
        return target.surface.platform.hub
    end

    local landing_pads_here = state.landing_pads.all_on(target.surface_index)
    assert(landing_pads_here ~= nil, "transfer_to.bay_associate_owner retrieved no landing pads for a surface that apparently has one")

    for _, candidate in pairs(landing_pads_here) do
        if utility.contains(candidate.get_cargo_bays(), target) then
            return candidate
        end
    end
    assert(false, "transfer_to.bay_associate_owner couldn't backwards match cargo bay to its landing pad because it's not remembered")
end

return transfer_to
