local utility = {}

function utility.debug(...)
    if not settings.global["debug-tracker"].value
        then return end
    print(game.tick, ...)
end

utility.__d_ttl = 30
utility.__dc_bounding = {255, 0, 0}
utility.__dc_bounding_real = {0, 0, 255}
utility.__dc_inserter_seek = {255, 255, 0}
utility.__dc_loader_seek = {0, 255, 0}
utility.__dc_robot_seek = {0, 255, 255}
utility.__dc_item_entity_seek = {0, 255, 255}

utility.__dc_robot_pos = {255, 0, 0}
utility.__dc_min_cand = {255, 0, 0}
utility.__dc_min_pass = {255, 255, 0}
utility.__dc_min_pick = {0, 255, 0}

--- @param surface LuaSurface
--- @param position MapPosition
--- @param color Color.0
function utility.debug_pos(surface, position, color)
    if not settings.global["debug-tracker"].value
        then return end
    rendering.draw_circle({
        surface = surface,
        color = color,
        width = 1,
        target = position,
        radius = 0.25,
        time_to_live = utility.__d_ttl
    })
end
--- @param item_on_line DetailedItemOnLine
--- @param line_idx integer
--- @param entity LuaEntity
--- @param color Color.0
function utility.debug_item_on_line(item_on_line, line_idx, entity, color)
    if not settings.global["debug-tracker"].value
        then return end
    rendering.draw_circle({
        surface = entity.surface,
        color = color,
        width = 1,
        target = entity.get_line_item_position(line_idx, item_on_line.position),
        radius = 0.25,
        time_to_live = utility.__d_ttl
    })
end
--- @param surface LuaSurface
--- @param area BoundingBox
--- @param color Color.0
function utility.debug_area(surface, area, color)
    if not settings.global["debug-tracker"].value
        then return end
    rendering.draw_rectangle({
        surface = surface,
        color = color,
        width = 1,
        left_top = area.left_top,
        right_bottom = area.right_bottom,
        time_to_live = utility.__d_ttl
    })
end

--- @param a Vector
--- @param b Vector
function utility.sq_distance(a, b)
    return (a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)
end

--- @param src MapPosition
--- @param dst MapPosition
function utility.vec_angle(src, dst)
    local angle = math.atan2(dst.x - src.x, dst.y - src.y)
    --- @type Vector
    return {
        x = math.sin(angle),
        y = math.cos(angle)
    }
end

--- @param p MapPosition
--- @param c MapPosition
--- @param rad number
function utility.vec_rotate_around_cw(p, c, rad)
    local dx = p.x - c.x
    local dy = p.y - c.y
    --- @type MapPosition
    return {
        x = c.x + dx * math.cos(rad) - dy * math.sin(rad),
        y = c.y + dx * math.sin(rad) + dy * math.cos(rad)
    }
end

--- @param aabb BoundingBox
function utility.aabb_center(aabb)
    --- @type Vector
    return {
        x = (aabb.right_bottom.x + aabb.left_top.x) / 2,
        y = (aabb.right_bottom.y + aabb.left_top.y) / 2
    }
end

--- @param position MapPosition
--- @param w number
--- @param h? number
function utility.aabb_around(position, w, h)
    h = h or w
    --- @type BoundingBox
    return {
        left_top = {x = position.x - w, y = position.y - h},
        right_bottom = {x = position.x + w, y = position.y + h}
    }
end

--- @param aabb BoundingBox
--- @param w number
--- @param h? number
function utility.aabb_expand(aabb, w, h)
    h = h or w
    --- @type BoundingBox
    return {
        left_top = {x = aabb.left_top.x - w, y = aabb.left_top.y - h},
        right_bottom = {x = aabb.right_bottom.x + w, y = aabb.right_bottom.y + h}
    }
end

local has_non_adjusted_selection_box = {
    ["car"] = true,
    ["cargo-wagon"] = true,
    ["fluid-wagon"] = true
}
--- @param entity LuaEntity
function utility.adjusted_selection_box(entity)
    if not has_non_adjusted_selection_box[entity.type] then
        return entity.selection_box
    end

    local selection_box = entity.selection_box
    local center = utility.aabb_center(selection_box)
    local hw = selection_box.left_top.x - center.x
    local hh = selection_box.left_top.y - center.y
    local angle_rad = (selection_box.orientation or 0) * 2 * math.pi

    local tl_rot = utility.vec_rotate_around_cw({x = center.x - hw, y = center.y - hh}, center, angle_rad)
    local tr_rot = utility.vec_rotate_around_cw({x = center.x + hw, y = center.y - hh}, center, angle_rad)
    local bl_rot = utility.vec_rotate_around_cw({x = center.x - hw, y = center.y + hh}, center, angle_rad)
    local br_rot = utility.vec_rotate_around_cw({x = center.x + hw, y = center.y + hh}, center, angle_rad)

    local tl_x = math.min(tl_rot.x, tr_rot.x, bl_rot.x, br_rot.x)
    local tl_y = math.min(tl_rot.y, tr_rot.y, bl_rot.y, br_rot.y)
    local br_x = math.max(tl_rot.x, tr_rot.x, bl_rot.x, br_rot.x)
    local br_y = math.max(tl_rot.y, tr_rot.y, bl_rot.y, br_rot.y)

    --- @type BoundingBox
    return {
        left_top = {x = tl_x, y = tl_y},
        right_bottom = {x = br_x, y = br_y}
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
--- @param m_fn fun(entry: T): U[]?
--- @return U[]
function utility.mapped_flattened(arr, m_fn)
    local ret = {}
    for _, entry in ipairs(arr) do
        local ret_entry = m_fn(entry)
        if ret_entry ~= nil then
            for _, x in ipairs(ret_entry) do
                table.insert(ret, x)
            end
        end
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

--- @generic T, U
--- @param arr T[]
--- @param d_fn fun(entry: T): number?, U?
--- @return T?, U?
function utility.minimum_of(arr, d_fn)
    if arr == nil
        then return end
    local local_minimum
    local local_d
    local tag

    local cnt = 0
    for _, entry in ipairs(arr) do
        local d, new_tag = d_fn(entry)
        if d ~= nil then cnt = cnt + 1 end
        if d ~= nil and (local_d == nil or d < local_d) then
            local_minimum = entry
            local_d = d
            tag = new_tag
        end
    end
    -- utility.debug("minimum_of candidates "..cnt.."/"..#arr)

    return local_minimum, tag
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
    -- utility.debug("minimum_on_belt candidates "..cnt.."/"..total)

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

--- @class FocusItemWhitelist
--- @field item? ItemIDAndQualityIDPair
--- @field items? string[]
--- @field qualities? string[]

utility.__no_wl = {}

--- @param item ItemWithQualityID
--- @param wl FocusItemWhitelist
function utility.is_item_filtered(item, wl)
    if wl.item ~= nil and (
        item.name ~= wl.item.name
        or item.quality ~= wl.item.quality
    ) then return false end

    if wl.items ~= nil and not utility.contains(wl.items, item.name)
        then return false end
    if wl.qualities ~= nil and not utility.contains(wl.qualities, item.quality.name)
        then return false end

    return true
end

--- @param inventory LuaInventory
--- @param item_wl FocusItemWhitelist
--- @return LuaItemStack?
function utility.first_item_stack_filtered(inventory, item_wl)
    if inventory == nil
        then return end
    for idx = 1, #inventory do
        local stack = inventory[idx]
        if
            stack.valid_for_read
            and stack.count > 0
            and utility.is_item_filtered(stack, item_wl)
        then
            return inventory[idx]
        end
    end
end

--- @param item ItemWithQualityID
function utility.item_stack_proto(item)
    --- @type ItemIDAndQualityIDPair
    return {
        name = item.name,
        quality = item.quality
    }
end

--- @class UtilityProductsOptions
--- @field items? boolean
--- @field fluids? boolean

--- @param products (ItemProduct|FluidProduct|ResearchProgressProduct)[]
--- @param wl UtilityProductsOptions
--- @return string[]?
function utility.products_filtered(products, wl)
    local results = {}
    for _, entry in ipairs(products) do
        if
            (wl.items and entry.type == "item")
            or (wl.fluids and entry.type == "fluid")
        then
            table.insert(results, entry.name)
        end
    end
    if #results == 0
        then return end
    return results
end

utility.inserter_search_d = 2.2
utility.inserter_search_d_picking_up_feather = 0.08
utility.loader_search_d = 1.5
utility.robot_search_d = 0
utility.agricultural_tower_search_tiles = 3
utility.agricultural_tower_search_d = 12
utility.smooth_end_feather = 0.05

-- Building direction -> belt piece direction -> target line_idx
utility.drop_belt_line_idx = {
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
    ["lane-splitter"] = true,
    ["underground-belt"] = true,
    ["linked-belt"] = true,
    ["loader"] = true
}
utility.all_belt = {"transport-belt", "splitter", "lane-splitter", "underground-belt", "linked-belt", "loader"}

utility.missing_inventory_defines = {
    agricultural_tower_input = 2,
    agricultural_tower_output = 3
}

utility.container_inventory_idx = {
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
