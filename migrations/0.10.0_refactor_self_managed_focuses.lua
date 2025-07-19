storage.focus_new_id = 1

--- @module "state"
local state = require("__item-cam-2__.script.state")
state.retrieve_from_storage()

--- @type table<integer, FocusInstance>
local remapped_focuses = {}
for player_idx, focus in pairs(state.focuses) do
    focus.id = storage.focus_new_id
    focus.running = focus.valid and focus.watching ~= nil
    focus.tags = {
        self_managed = true,
        player_idx = player_idx
    }
    storage.focus_new_id = storage.focus_new_id + 1

    for _, controllable in ipairs(focus.controlling) do
        if controllable.type == "player" then
            controllable.camera = controllable.camera_element
            controllable.camera_element = nil
        end
    end

    remapped_focuses[focus.id] = focus
end

storage.focuses = remapped_focuses
state.focus_new_id = storage.focus_new_id
state.focuses = remapped_focuses
