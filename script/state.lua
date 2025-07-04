local state = {
    --- @type table<integer, FocusInstance>
    focuses = nil,
    --- @type table<integer, FollowRule[]|nil>
    follow_rules = nil,
    --- @type LuaEntity[]
    env_changed_next_tick = nil,
    gui_state = nil,
}

function state.init_storage()
    storage.focuses = storage.focuses or {}
    storage.follow_rules = storage.follow_rules or {}
    storage.env_changed_next_tick = storage.env_changed_next_tick or {}
    storage.gui_state = storage.gui_state or {}
end

function state.retrieve_from_storage()
    state.focuses = storage.focuses
    state.follow_rules = storage.follow_rules
    state.env_changed_next_tick = storage.env_changed_next_tick
    state.gui_state = storage.gui_state
end

return state
