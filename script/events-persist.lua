local state = require("state")

script.on_init(function ()
    state.retrieve_from_storage()
    for _, surface in pairs(game.surfaces) do
        state.landing_pads.retrieve_all(surface.index)
    end
end)

script.on_load(function ()
    state.retrieve_from_storage()
end)
