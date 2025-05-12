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


local state = {
    focuses = focuses,
    --- @type LuaEntity[]
    env_changed_next_tick = nil
}

function state.retrieve_from_storage()
    storage.focuses = storage.focuses or {}
    storage.env_changed_next_tick = storage.env_changed_next_tick or {}

    focuses.v = storage.focuses
    state.env_changed_next_tick = storage.env_changed_next_tick
end

return state
