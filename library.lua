local library = {}

library.create_focus = require("library.focus-remote")

--- @class (exact) EventDataStub.on_focus_switch
--- @field focus_id integer ID of this focus instance
--- @field previous_target LuaEntity The previous entity it was following
--- @field new_target LuaEntity The new entity it is following
--- @field surface LuaSurface The surface it's following at
--- @field position MapPosition The exact position it's at right now
--- @field smooth_position MapPosition The smooth (percieved by controllables) position it's at right now
--- @field cause_entity? LuaEntity The entity that caused this focus switch, if applicable

--- @class (exact) EventDataStub.on_focus_destroyed
--- @field focus_id integer ID of this focus instance
--- @field cause_mod_name? string If `:destroy()` was called on focus instance, name of the mod that called it. `nil` means it lost focus
--- @field was_running boolean Whether this focus instance was following something when it was destroyed
--- @field previous_target? LuaEntity If `was_running`, the last entity it was following until it got destroyed
--- @field surface? LuaSurface If `was_running`, last surface it was following at until it got destroyed
--- @field position? MapPosition If `was_running`, last exact position until it got destroyed
--- @field smooth_position? MapPosition If `was_running`, last smooth (perceived by controllables) position until it got destroyed

--- @alias EventData.on_focus_switch EventDataStub.on_focus_switch|EventData
--- @alias EventData.on_focus_destroyed EventDataStub.on_focus_destroyed|EventData

local ic2_events = require("library.event-ids")

library.events = ic2_events

--- Alias for `script.on_event` with proper typing for Item Cam 2 events
--- @overload fun(event: ic2_events.on_focus_switch, handler: fun(event: EventData.on_focus_switch))
--- @overload fun(event: ic2_events.on_focus_destroyed, handler: fun(event: EventData.on_focus_destroyed))
function library.on_event(event, handler)
    --- @diagnostic disable-next-line: param-type-mismatch
    script.on_event(event, handler)
end

return library
