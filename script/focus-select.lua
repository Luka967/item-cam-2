local watchdog = require("focus-watchdog")
local utility  = require("utility")

--- @param selected LuaEntity
local function inserter_with_item_in_hand(selected)
    if not selected.held_stack.valid_for_read
        then return end
    return watchdog.create.item_in_inserter_hand(selected)
end

--- @param selected LuaEntity
local function belt_with_items_on_it(selected)
    local line_count = selected.get_max_transport_line_index()
    for line_idx = 1, line_count, 1 do
        local line = selected.get_transport_line(line_idx)
        if #line > 0 then
            return watchdog.create.item_on_belt(line.get_detailed_contents()[1], line_idx, selected)
        end
    end
end

--- @param selected LuaEntity
local function container_with_contents(selected)
    local inventory_type = utility.is_container[selected.type]
    if not inventory_type
        then return end
    local inventory = selected.get_inventory(inventory_type)
    for idx = 1, #inventory do
        local stack = inventory[idx]
        if stack.valid_for_read and stack.count > 0 then
            return watchdog.create.item_in_container(selected, inventory_type, {
                name = stack.name,
                quality = stack.quality
            })
        end
    end
end

--- @param selected LuaEntity
local function robot_holding_item(selected)
    local inventory = selected.get_inventory(defines.inventory.robot_cargo)
    if not inventory[1].valid_for_read
        then return end
    return watchdog.create.item_held_by_robot(selected)
end

--- @param selected LuaEntity
local function crafting_machine_with_recipe(selected)
    if selected.get_recipe() == nil
        then return end

    return watchdog.create.item_in_crafting_machine(selected)
end

local map = {
    ["inserter"] = inserter_with_item_in_hand
}
for prototype in pairs(utility.is_belt) do
    map[prototype] = belt_with_items_on_it
end
for prototype in pairs(utility.is_container) do
    map[prototype] = container_with_contents
end
for prototype in pairs(utility.is_crafting_machine) do
    map[prototype] = crafting_machine_with_recipe
end
for prototype in pairs(utility.is_robot) do
    map[prototype] = robot_holding_item
end

--- @param selected LuaEntity
return function (selected)
    local fn = map[selected.type]
    if fn == nil
        then return end
    game.print("i have seen "..selected.type)

    local watching, position, surface_idx = fn(selected)
    if watching ~= nil then
        game.print("i have acquired "..watching.type)
    end

    return watching, position, surface_idx
end
