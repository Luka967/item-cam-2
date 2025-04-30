local focuses = {
    --- Player idx -> FocusInstance
    --- @type table<integer, FocusInstance>
    v = nil
}

--- @param player_idx number
function focuses.get(player_idx)
    return focuses.v[player_idx]
end
--- @param player_idx number
--- @param to? FocusInstance
function focuses.set(player_idx, to)
    focuses.v[player_idx] = to
end

--- @class DestroyIdentifier
--- @field surface_idx integer
--- @field unit_number integer

local landing_pads = {
    --- surface idx -> unit_number -> LuaEntity
    --- @type table<integer, table<integer, LuaEntity>>
    v = nil,
    --- surface idx -> count of remembered entities
    --- @type table<integer, integer>
    v_cnt = nil,
    --- register_on_object_destroyed registration numbers
    --- registration_number -> DestroyIdentifier
    --- @type table<integer, DestroyIdentifier>
    v_dreg = nil
}

--- @param surface_idx number
function landing_pads.all_on(surface_idx)
    local table = landing_pads.v[surface_idx]
    if table == nil
        then return end
    return table
end

--- @param surface_idx integer
function landing_pads.retrieve_all(surface_idx)
    landing_pads.v[surface_idx] = nil
    if game.surfaces[surface_idx] == nil
        then return end
    local all_found = game.surfaces[surface_idx].find_entities_filtered({
        type = {"cargo-landing-pad"}
    })
    for _, entity in ipairs(all_found) do
        landing_pads.remember(entity)
    end
end

--- @param entity LuaEntity
function landing_pads.remember(entity)
    local surface_idx = entity.surface_index
    if landing_pads.v[surface_idx] == nil then
        landing_pads.v[surface_idx] = {}
        landing_pads.v_cnt[surface_idx] = 0
    end
    landing_pads.v[surface_idx][entity.unit_number] = entity
    landing_pads.v_cnt[surface_idx] = landing_pads.v_cnt[surface_idx] + 1

    local destroy_regnumber = script.register_on_object_destroyed(entity)
    landing_pads.v_dreg[destroy_regnumber] = {
        surface_idx = surface_idx,
        unit_number = entity.unit_number
    }
end

--- @param destroy_regnumber integer
function landing_pads.forget(destroy_regnumber)
    local identifier = landing_pads.v_dreg[destroy_regnumber]
    landing_pads.v_dreg[destroy_regnumber] = nil

    local surface_idx = identifier.surface_idx
    if identifier == nil
        then return end

    landing_pads.v[surface_idx][identifier.unit_number] = nil

    local next_cnt = landing_pads.v_cnt[surface_idx] - 1
    landing_pads.v_cnt[surface_idx] = next_cnt
    if next_cnt == 0 then
        landing_pads.v[surface_idx] = nil
        landing_pads.v_cnt[surface_idx] = nil
    end
end

local state = {
    focuses = focuses,
    landing_pads = landing_pads
}

function state.retrieve_from_storage()
    storage.focuses = storage.focuses or {}
    focuses.v = storage.focuses

    storage.landing_pads = storage.landing_pads or {}
    landing_pads.v = storage.landing_pads

    storage.landing_pads_cnt = storage.landing_pads_cnt or {}
    landing_pads.v_cnt = storage.landing_pads_cnt

    storage.landing_pads_dreg = storage.landing_pads_dreg or {}
    landing_pads.v_dreg = storage.landing_pads_dreg
end

return state
