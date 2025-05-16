local const = require("const")
local watchdog = require("focus-watchdog")
local utility = require("utility")

--- @param selected LuaEntity
local function item_on_ground(selected)
    return {watchdog.create.item_on_ground(selected)}
end

--- @param selected LuaEntity
local function inserter_with_item_in_hand(selected)
    if not selected.held_stack.valid_for_read
        then return end
    return {watchdog.create.item_in_inserter_hand(selected)}
end

--- @param selected LuaEntity
local function belt_with_items_on_it(selected)
    local candidates = {}

    local line_count = selected.get_max_transport_line_index()
    for line_idx = 1, line_count do
        local line_contents = selected.get_transport_line(line_idx).get_detailed_contents()
        for _, candidate in ipairs(line_contents) do
            table.insert(candidates, watchdog.create.item_on_belt(candidate, line_idx, selected))
        end
    end

    return candidates
end

--- @param selected LuaEntity
local function container_with_contents(selected)
    local inventory_type = const.container_inventory_idx[selected.type]
    if not inventory_type
        then return end

    local inventory = selected.get_inventory(inventory_type)
    assert(inventory, "container doesn't have targeted inventory")
    local item_stack = utility.first_item_stack_filtered(inventory, utility.__no_wl)
    if item_stack == nil
        then return end

    local item = {
        name = item_stack.name,
        quality = item_stack.quality
    }

    return {watchdog.create.item_in_container(selected, item)}
end

--- @param selected LuaEntity
local function cargo_bay_proxy_to_main_container(selected)
    return container_with_contents(selected.cargo_bay_connection_owner)
end

--- @param selected LuaEntity
local function robot_holding_item(selected)
    local inventory = selected.get_inventory(defines.inventory.robot_cargo)
    assert(inventory, "robot doesn't have targeted inventory")
    local item_stack = utility.first_item_stack_filtered(inventory, utility.__no_wl)
    if item_stack == nil
        then return end

    return {watchdog.create.item_held_by_robot(selected, utility.item_stack_proto(item_stack))}
end

--- @param selected LuaEntity
local function crafting_machine_with_recipe(selected)
    if selected.get_recipe() == nil
        then return end

    return {watchdog.create.item_in_crafting_machine(selected)}
end

--- @param selected LuaEntity
local function mining_drill_with_resource(selected)
    if selected.mining_target == nil
        then return end
    if not utility.products_filtered(selected.mining_target.prototype.mineable_properties.products, {items = true})
        then return end

    return {watchdog.create.item_coming_from_mining_drill(selected)}
end

--- @param selected LuaEntity
local function asteroid_collector(selected)
    return {watchdog.create.item_coming_from_asteroid_collector(selected)}
end

--- @param selected LuaEntity
local function agricultural_tower(selected)
    return {watchdog.create.item_coming_from_agricultural_tower(selected)}
end

--- @param selected LuaEntity
local function minable_plant(selected)
    if not selected.minable
        then return end

    return {watchdog.create.plant_growing(selected)}
end

--- @param selected LuaEntity
local function lab(selected)
    return {watchdog.create.end_lab(selected)}
end

local map = {
    ["item-entity"] = item_on_ground,
    ["inserter"] = inserter_with_item_in_hand,
    ["mining-drill"] = mining_drill_with_resource,
    ["cargo-bay"] = cargo_bay_proxy_to_main_container,
    ["asteroid-collector"] = asteroid_collector,
    ["agricultural-tower"] = agricultural_tower,
    ["plant"] = minable_plant,
    ["lab"] = lab
}
for prototype in pairs(const.is_belt) do
    map[prototype] = belt_with_items_on_it
end
for prototype in pairs(const.container_inventory_idx) do
    map[prototype] = container_with_contents
end
for prototype in pairs(const.is_crafting_machine) do
    map[prototype] = crafting_machine_with_recipe
end
for prototype in pairs(const.is_robot) do
    map[prototype] = robot_holding_item
end

--- @param all_selected LuaEntity[]
--- @param center MapPosition
return function (all_selected, center)
    local all_candidates = utility.mapped_flattened(all_selected, function (entry)
        local fn = map[entry.type]
        if fn ~= nil then
            return fn(entry)
        end
    end)
    local closest_candidate = utility.minimum_of(all_candidates, function (entry)
        return utility.sq_distance(watchdog.get_position[entry.type](entry), center)
    end)

    if closest_candidate == nil
        then return end

    utility.debug("focus acquired "..closest_candidate.type.." out of "..#all_candidates.." candidates")

    return closest_candidate
end
