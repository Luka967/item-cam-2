--- @enum ic2_events
local ic2_events = {
    on_focus_switch = #{} --[[@as ic2_events.on_focus_switch]],
    on_focus_destroyed = #{} --[[@as ic2_events.on_focus_destroyed]]
}
if prototypes then
    for key in pairs(ic2_events) do
        --- @diagnostic disable-next-line: assign-type-mismatch
        ic2_events[key] = prototypes.custom_event[key].event_id
    end
end

return ic2_events
