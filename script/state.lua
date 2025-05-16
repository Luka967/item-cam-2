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
    env_changed_next_tick = nil,
    gui_state = nil
}

function state.init_storage()
    storage.focuses = storage.focuses or {}
    storage.env_changed_next_tick = storage.env_changed_next_tick or {}
    storage.gui_state = storage.gui_state or {}
end

function state.retrieve_from_storage()
    focuses.v = storage.focuses
    state.env_changed_next_tick = storage.env_changed_next_tick
    state.gui_state = storage.gui_state
end

return state
