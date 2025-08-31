local state = {
    --- @type integer
    focus_new_id = nil,
    --- @type table<integer, FocusInstance>
    focuses = nil,
    --- @type integer[]
    focuses_to_destroy = nil,
    --- @type table<integer, FollowRule[]|nil>
    follow_rules = nil,
    --- @type LuaEntity[]
    env_changed_next_tick = nil,
    gui_state = nil,
}

function state.init_storage()
    storage.focus_new_id = storage.focus_new_id or 1
    storage.focuses = storage.focuses or {}
    storage.focuses_to_destroy = storage.focuses_to_destroy or {}
    storage.follow_rules = storage.follow_rules or {}
    storage.env_changed_next_tick = storage.env_changed_next_tick or {}
    storage.gui_state = storage.gui_state or {}
end

function state.retrieve_from_storage()
    state.focus_new_id = storage.focus_new_id
    state.focuses = storage.focuses
    state.focuses_to_destroy = storage.focuses_to_destroy or {}
    state.follow_rules = storage.follow_rules
    state.env_changed_next_tick = storage.env_changed_next_tick
    state.gui_state = storage.gui_state
end

function state.get_next_focus_id()
    local id = state.focus_new_id
    state.focus_new_id = state.focus_new_id + 1
    storage.focus_new_id = state.focus_new_id
    return id
end

return state
