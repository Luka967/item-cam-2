local utility = {}

function utility.debug(...)
    if not settings.global["debug-tracker"].value
        then return end
    print(game.tick, ...)
end

--- @param src Vector
--- @param dst Vector
--- @param p number
--- @return Vector
function utility.lerp(src, dst, p)
    return {
        x = src.x + (dst.x - src.x) * p,
        y = src.y + (dst.y - src.y) * p,
    }
end

--- @param a Vector
--- @param b Vector
--- @return Vector
function utility.vec_add(a, b)
    return {
        x = a.x + b.x,
        y = a.y + b.y
    }
end

--- @param a Vector
--- @param b Vector
--- @return Vector
function utility.vec_sub(a, b)
    return {
        x = a.x - b.x,
        y = a.y - b.y
    }
end

--- @param src MapPosition
--- @param dst MapPosition
--- @return Vector
function utility.vec_angle(src, dst)
    local angle = math.atan2(dst.x - src.x, dst.y - src.y)
    return {
        x = math.sin(angle),
        y = math.cos(angle)
    }
end

--- @param aabb BoundingBox
function utility.aabb_center(aabb)
    return {
        x = (aabb.right_bottom.x + aabb.left_top.x) / 2,
        y = (aabb.right_bottom.y + aabb.left_top.y) / 2
    }
end

--- @param position MapPosition
--- @param w number
--- @param h? number
--- @return BoundingBox
function utility.aabb_around(position, w, h)
    h = h or w
    return {
        right_top = {x = position.x - w, y = position.y - h},
        left_bottom = {x = position.x + w, y = position.y + h}
    }
end

--- @param aabb BoundingBox
--- @param w number
--- @param h? number
--- @return BoundingBox
function utility.aabb_expand(aabb, w, h)
    h = h or w
    return {
        right_top = {x = aabb.left_top.x - w, y = aabb.left_top.y - h},
        left_bottom = {x = aabb.right_bottom.x + w, y = aabb.right_bottom.y + h}
    }
end

--- @generic T
--- @param arr T[]
--- @param f_fn fun(entry: T): boolean?
--- @return T[]
function utility.filtered(arr, f_fn)
    local ret = {}
    for _, entry in ipairs(arr) do
        if f_fn(entry) then
            table.insert(ret, entry)
        end
    end
    return ret
end

--- @generic T, U
--- @param arr T[]
--- @param m_fn fun(entry: T): U
--- @return U[]
function utility.mapped(arr, m_fn)
    local ret = {}
    for _, entry in ipairs(arr) do
        table.insert(ret, m_fn(entry))
    end
    return ret
end

--- @generic T, U
--- @param arr T[]
--- @param f_fn fun(entry: T, idx: integer): U?
--- @return U?
function utility.first(arr, f_fn)
    for idx, entry in ipairs(arr) do
        local r_fn = f_fn(entry, idx)
        if r_fn
            then return r_fn end
    end
end

--- @generic T
--- @param arr T[]
--- @param target T
--- @return boolean, integer?
function utility.contains(arr, target)
    for idx, entry in ipairs(arr) do
        if entry == target then
            return true, idx
        end
    end
    return false
end

--- @generic T
--- @param arr T[]
--- @param d_fn fun(entry: T): number?
--- @return T?, number?
function utility.minimum_of(arr, d_fn)
    if arr == nil
        then return end
    local local_minimum
    local local_d

    local cnt = 0
    for _, entry in ipairs(arr) do
        local d = d_fn(entry)
        if d ~= nil then cnt = cnt + 1 end
        if d ~= nil and (local_d == nil or d < local_d) then
            local_minimum = entry
            local_d = d
        end
    end
    -- Spammy
    -- utility.debug("minimum_of candidates "..cnt.."/"..#arr)

    return local_minimum, local_d
end

--- @param belt_entity LuaEntity
--- @param d_fn fun(item: DetailedItemOnLine, line_idx: integer): number?
--- @return DetailedItemOnLine?, integer?
function utility.minimum_on_belt(belt_entity, d_fn)
    local local_minimum
    local local_line_idx
    local local_d

    local line_count = belt_entity.get_max_transport_line_index()
    local cnt = 0
    local total = 0
    for line_idx = 1, line_count do
        local line = belt_entity.get_transport_line(line_idx)
        for _, item in ipairs(line.get_detailed_contents()) do
            total = total + 1
            local d = d_fn(item, line_idx)
            if d ~= nil then cnt = cnt + 1 end
            if d ~= nil and (local_d == nil or d < local_d) then
                local_minimum = item
                local_line_idx = line_idx
                local_d = d
            end
        end
    end
    utility.debug("minimum_on_belt candidates "..cnt.."/"..total)

    return local_minimum, local_line_idx
end

--- @param line LuaTransportLine
--- @param fn fun(item: DetailedItemOnLine): boolean?
--- @return DetailedItemOnLine?
function utility.first_on_line(line, fn)
    for _, item in ipairs(line.get_detailed_contents()) do
        if fn(item) then return item end
    end
end

--- @param belt_entity LuaEntity
--- @param fn fun(item: DetailedItemOnLine): boolean?
--- @return DetailedItemOnLine?, integer?
function utility.first_on_belt(belt_entity, fn)
    local line_count = belt_entity.get_max_transport_line_index()
    for line_idx = 1, line_count do
        local item = utility.first_on_line(belt_entity.get_transport_line(line_idx), fn)
        if item then
            return item, line_idx
        end
    end
end

--- @param arr LuaEntity[]
--- @param fn fun(item: DetailedItemOnLine): boolean?
--- @return DetailedItemOnLine?, integer?, LuaEntity?
function utility.first_on_belts(arr, fn)
    for _, belt_entity in ipairs(arr) do
        local item, line_idx = utility.first_on_belt(belt_entity, fn)
        if item then
            return item, line_idx, belt_entity
        end
    end
end

--- @param inventory LuaInventory
--- @return LuaItemStack?
function utility.first_readable_item_stack(inventory)
    if inventory == nil
        then return end
    for idx = 1, #inventory do
        local stack = inventory[idx]
        if stack.valid_for_read and stack.count > 0 then
            return inventory[idx]
        end
    end
end

--- @param a Vector
--- @param b Vector
function utility.distance(a, b)
    return (a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)
end

--- @class UtilityMinableProductsArgs
--- @field source LuaEntity
--- @field items? boolean
--- @field fluids? boolean

--- @param arg UtilityMinableProductsArgs
--- @return string[]?
function utility.mining_products(arg)
    if not arg.source.minable
        then return end

    local prototype = arg.source.prototype
    if prototype.type ~= "resource"
        then return end
    if #prototype.mineable_properties.products == 0
        then return end

    local results = {}
    for _, entry in ipairs(prototype.mineable_properties.products) do
        if
            (arg.items and entry.type == "item")
            or (arg.fluids and entry.type == "fluid")
        then
            table.insert(results, entry.name)
        end
    end
    if #results == 0
        then return end
    return results
end

utility.inserter_search_d = 2
utility.inserter_search_d_picking_up_feather = 0.08
utility.robot_search_d = 0.5
-- Mining drill direction -> belt piece direction -> target line_idx
utility.mining_drill_drop_belt_line_idx = {
    [defines.direction.east] = {
        [defines.direction.north] = 1,
        [defines.direction.south] = 2,
        [defines.direction.west] = 2,
        [defines.direction.east] = 2,
    },
    [defines.direction.west] = {
        [defines.direction.north] = 2,
        [defines.direction.south] = 1,
        [defines.direction.west] = 2,
        [defines.direction.east] = 2,
    },
    [defines.direction.north] = {
        [defines.direction.east] = 2,
        [defines.direction.west] = 1,
        [defines.direction.north] = 2,
        [defines.direction.south] = 2,
    },
    [defines.direction.south] = {
        [defines.direction.east] = 1,
        [defines.direction.west] = 2,
        [defines.direction.north] = 2,
        [defines.direction.south] = 2
    },
}

utility.is_belt = {
    ["transport-belt"] = true,
    ["splitter"] = true,
    ["underground-belt"] = true
}
utility.all_belt = {"transport-belt", "splitter", "underground-belt"}

utility.is_container = {
    ["container"] = defines.inventory.chest,
    ["logistic-container"] = defines.inventory.chest,
    ["infinity-container"] = defines.inventory.chest,
    ["temporary-container"] = defines.inventory.chest,
    ["cargo-wagon"] = defines.inventory.cargo_wagon,
    ["cargo-landing-pad"] = defines.inventory.cargo_landing_pad_main,
    ["space-platform-hub"] = defines.inventory.hub_main,
    ["rocket-silo"] = defines.inventory.rocket_silo_rocket
}

utility.is_robot = {
    ["construction-robot"] = true,
    ["logistic-robot"] = true
}
utility.all_bot = {"construction-robot", "logistic-robot"}

utility.is_crafting_machine = {
    ["furnace"] = true,
    ["assembling-machine"] = true
}

utility.all_suitable_robot_order = {
    [defines.robot_order_type.deliver] = true,
    [defines.robot_order_type.deliver_items] = true,
    [defines.robot_order_type.repair] = true,
    [defines.robot_order_type.pickup] = true,
    [defines.robot_order_type.pickup_items] = true
}
utility.all_pickup_robot_order = {
    [defines.robot_order_type.pickup] = true,
    [defines.robot_order_type.pickup_items] = true
}
utility.all_deliver_robot_order = {
    [defines.robot_order_type.deliver] = true,
    [defines.robot_order_type.deliver_items] = true
}

return utility
