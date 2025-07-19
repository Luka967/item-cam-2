storage.focus_new_id = {1}

--- @module "state"
local state = require("__item-cam-2__.script.state")
state.retrieve_from_storage()

--- @type table<integer, FocusInstance>
local remapped_focuses = {}
for player_idx, focus in pairs(state.focuses) do
    focus.id = state.focus_new_id[1]
    focus.tags = {
        self_managed = true,
        player_idx = player_idx
    }
    state.focus_new_id[1] = state.focus_new_id[1] + 1

    remapped_focuses[focus.id] = focus
end

storage.focuses = remapped_focuses
state.focuses = remapped_focuses
