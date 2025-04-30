local state = require("state")
local const = require("const")

script.on_init(function ()
    state.retrieve_from_storage()
    for _, surface in pairs(game.surfaces) do
        state.landing_pads.retrieve_all(surface.index)
    end
end)

script.on_load(function ()
    state.retrieve_from_storage()
end)

script.on_event(defines.events.on_script_trigger_effect, function (event)
    if event.effect_id ~= const.name_trigger_remember_landing_pad
        then return end
    if event.cause_entity == nil
        then return end
    state.landing_pads.remember(event.cause_entity)
end)

script.on_event(defines.events.on_object_destroyed, function (event)
    state.landing_pads.forget(event.registration_number)
end)
