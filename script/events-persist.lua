local state = require("state")

script.on_init(function ()
    state.retrieve_from_storage()
end)

script.on_load(function ()
    state.retrieve_from_storage()
end)
