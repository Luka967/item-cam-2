--- @alias AnyGuiEventDefine defines.events.on_gui_checked_state_changed|defines.events.on_gui_click|defines.events.on_gui_closed|defines.events.on_gui_confirmed|defines.events.on_gui_elem_changed|defines.events.on_gui_hover|defines.events.on_gui_leave|defines.events.on_gui_location_changed|defines.events.on_gui_opened|defines.events.on_gui_selected_tab_changed|defines.events.on_gui_selection_state_changed|defines.events.on_gui_switch_state_changed|defines.events.on_gui_text_changed|defines.events.on_gui_value_changed
--- @alias AnyGuiEvent EventData.on_gui_checked_state_changed|EventData.on_gui_click|EventData.on_gui_closed|EventData.on_gui_confirmed|EventData.on_gui_elem_changed|EventData.on_gui_hover|EventData.on_gui_leave|EventData.on_gui_location_changed|EventData.on_gui_opened|EventData.on_gui_selected_tab_changed|EventData.on_gui_selection_state_changed|EventData.on_gui_switch_state_changed|EventData.on_gui_text_changed|EventData.on_gui_value_changed

--- @alias CustomGuiEventHandler<T> fun(event: T, gui_state: table, gid: string)

--- @class CustomGuiEventHandlerTable
--- @field checked_state_changed?    CustomGuiEventHandler<EventData.on_gui_checked_state_changed>
--- @field click?                    CustomGuiEventHandler<EventData.on_gui_click>
--- @field closed?                   CustomGuiEventHandler<EventData.on_gui_closed>
--- @field confirmed?                CustomGuiEventHandler<EventData.on_gui_confirmed>
--- @field elem_changed?             CustomGuiEventHandler<EventData.on_gui_elem_changed>
--- @field hover?                    CustomGuiEventHandler<EventData.on_gui_hover>
--- @field leave?                    CustomGuiEventHandler<EventData.on_gui_leave>
-- --- @field location_changed?         CustomGuiEventHandler<EventData.on_gui_location_changed>
--- @field opened?                   CustomGuiEventHandler<EventData.on_gui_opened>
--- @field selected_tab_changed?     CustomGuiEventHandler<EventData.on_gui_selected_tab_changed>
--- @field selection_state_changed?  CustomGuiEventHandler<EventData.on_gui_selection_state_changed>
--- @field switch_state_changed?     CustomGuiEventHandler<EventData.on_gui_switch_state_changed>
--- @field text_changed?             CustomGuiEventHandler<EventData.on_gui_text_changed>
--- @field value_changed?            CustomGuiEventHandler<EventData.on_gui_value_changed>

local gui_event_map = {
    [defines.events.on_gui_checked_state_changed] = "checked_state_changed",
    [defines.events.on_gui_click] = "click",
    [defines.events.on_gui_closed] = "closed",
    [defines.events.on_gui_confirmed] = "confirmed",
    [defines.events.on_gui_elem_changed] = "elem_changed",
    [defines.events.on_gui_hover] = "hover",
    [defines.events.on_gui_leave] = "leave",
    -- [defines.events.on_gui_location_changed] = "location_changed",
    [defines.events.on_gui_opened] = "opened",
    [defines.events.on_gui_selected_tab_changed] = "selected_tab_changed",
    [defines.events.on_gui_selection_state_changed] = "selection_state_changed",
    [defines.events.on_gui_switch_state_changed] = "switch_state_changed",
    [defines.events.on_gui_text_changed] = "text_changed",
    [defines.events.on_gui_value_changed] = "value_changed"
}

--- gid -> LuaGuiElement::name -> event handlers
--- @type table<string, table<string, CustomGuiEventHandlerTable>>
local custom_gui_events = {}

--- player_index -> gid -> custom state object
--- @type table<number, table<string, any>>
local custom_gui_state = {}

local custom_gui = {}

--- @param obj any
function custom_gui.init_state(obj)
    custom_gui_state = obj
end

--- @param player_idx number
--- @param gid string
function custom_gui.create_state(player_idx, gid)
    custom_gui_state[player_idx] = custom_gui_state[player_idx] or {}
    custom_gui_state[player_idx][gid] = {
        player = game.get_player(player_idx)
    }
end

--- @param player_idx number
--- @param gid string
--- @return table?
function custom_gui.get_state(player_idx, gid)
    if not custom_gui_state[player_idx]
        then return end
    return custom_gui_state[player_idx][gid]
end

--- @param player_idx number
--- @param gid string
function custom_gui.destroy_state(player_idx, gid)
    custom_gui_state[player_idx][gid] = nil
    if table_size(custom_gui_state[player_idx]) == 0 then
        custom_gui_state[player_idx] = nil
    end
end

--- @generic T: AnyGuiEventDefine
--- @param gid string
--- @param define T
--- @param handler CustomGuiEventHandler<T>
function custom_gui.register_event_handler_for(gid, elem_name, define, handler)
    custom_gui_events[gid] = custom_gui_events[gid] or {}
    custom_gui_events[gid][elem_name] = custom_gui_events[gid][elem_name] or {}
    custom_gui_events[gid][elem_name][gui_event_map[define]] = handler
end

--- @param gid string
--- @param elem_name string
--- @param handlers CustomGuiEventHandlerTable
function custom_gui.register_event_handlers_for(gid, elem_name, handlers)
    custom_gui_events[gid] = custom_gui_events[gid] or {}
    custom_gui_events[gid][elem_name] = handlers
end

--- @param gid string
--- @param name string
--- @param event AnyGuiEvent
function custom_gui.remote_call_event(gid, name, event)
    assert(custom_gui_events[gid] ~= nil, "this gid has no events defined")
    assert(custom_gui_events[gid][name] ~= nil, "this name under this gid has no events defined")

    local handlers = custom_gui_events[gid][name]
    local event_name = gui_event_map[event.name]
    local known_state = custom_gui_state[event.player_index] and custom_gui_state[event.player_index][gid]

    handlers[event_name](event, known_state, gid)
end

--- Pick the first GID found beginning from innermost element
--- @param player_idx number
--- @param element LuaGuiElement
local function knock_for_gid(player_idx, element)
    if element.tags ~= nil and element.tags.gid ~= nil then
        --- @type string
        return element.tags.gid
    end
    if element.parent ~= nil then
        return knock_for_gid(player_idx, element.parent)
    end
end

--- Walk the element's parents until specific event handler is found
--- @param gid string
--- @param element LuaGuiElement
--- @param event_name string
local function bubble_the_event(gid, element, event_name)
    local handlers
    while element ~= nil do
        handlers = custom_gui_events[gid][element.name]
        if handlers ~= nil and handlers[event_name] ~= nil then
            return handlers
        end
        element = element.parent
    end
    return nil
end

--- @param event AnyGuiEvent
local function gui_event_handler(event)
    local element = event.element
    if element == nil or not element.valid
        then return end

    local gid = knock_for_gid(event.player_index, element)
    if gid == nil or custom_gui_events[gid] == nil
        then return end

    local event_name = gui_event_map[event.name]
    local handlers = bubble_the_event(gid, element, event_name)
    if handlers == nil or not handlers[event_name]
        then return end

    custom_gui.remote_call_event(gid, element.name, event)
end

function custom_gui.register_main_event_handlers()
    for event_define in pairs(gui_event_map) do
        script.on_event(event_define, gui_event_handler)
    end
end

return custom_gui
