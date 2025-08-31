local library = {}

library.create_focus = require("library.focus-remote")

--- @class (exact) EventDataStub.on_focus_switch
--- @field focus_id integer
--- @field previous_target LuaEntity
--- @field new_target LuaEntity
--- @field surface LuaSurface
--- @field position MapPosition
--- @field smooth_position MapPosition
--- @field cause_entity? LuaEntity

--- @class (exact) EventDataStub.on_focus_destroyed
--- @field focus_id integer
--- @field was_running boolean
--- @field previous_target? LuaEntity
--- @field surface? LuaSurface
--- @field position? MapPosition
--- @field smooth_position? MapPosition

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
