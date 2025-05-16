local state = require("state")
local gui_custom = require("gui-custom")

script.on_init(function ()
    state.init_storage()
    state.retrieve_from_storage()
    gui_custom.init_state(state.gui_state)
end)

script.on_configuration_changed(function (p1)
    state.init_storage()
    state.retrieve_from_storage()
    gui_custom.init_state(state.gui_state)
end)

script.on_load(function ()
    state.retrieve_from_storage()
    gui_custom.init_state(state.gui_state)
end)
