local state = require("__item-cam-2__.script.state")

state.retrieve_from_storage()
for _, surface in pairs(game.surfaces) do
    state.landing_pads.retrieve_all(surface.index)
end
