local gui_custom = require("gui-custom")

--- @class CustomGuiElementExtra
--- @field gid? string
--- @field is_window_root? boolean
--- @field postfix? fun(elem: LuaGuiElement, window?: LuaGuiElement)
--- @field children? CustomGuiElement[]

--- @alias CustomGuiElement LuaGuiElement.add_param|CustomGuiElementExtra

--- @class GeneratorGuiBaseState
--- @field window LuaGuiElement
--- @field player LuaPlayer

local gui_generator = {}

--- @param target LuaGuiElement
--- @param spec CustomGuiElement
--- @param window? LuaGuiElement
function gui_generator.generate_at(target, spec, window)
    local children = spec.children
    if children ~= nil
        then spec.children = nil end

    local gid = spec.gid
    if gid ~= nil then
        spec.tags = spec.tags or {}
        spec.tags.gid = gid
        spec.gid = nil
        gui_custom.create_state(target.player_index, gid)
    end

    local is_window_root = spec.is_window_root
    spec.is_window_root = nil

    local postfix = spec.postfix
    if postfix ~= nil then
        spec.postfix = nil
    end

    --- @cast spec LuaGuiElement.add_param
    local created_element = target.add(spec)
    if is_window_root and gid ~= nil then
        window = created_element
        local state = gui_custom.get_state(target.player_index, gid)
        state.window = created_element
    end

    if postfix ~= nil then
        postfix(created_element, window)
    end

    if children ~= nil then
        for _, child_spec in ipairs(children) do
            gui_generator.generate_at(created_element, child_spec, window)
        end
    end

    return created_element
end

--- @class CustomGuiElementEventHandlers: CustomGuiEventHandlerTable
--- @field name string

--- @param gid string
--- @param ... CustomGuiElementEventHandlers[]
function gui_generator.register_event_handlers(gid, ...)
    for _, entry in ipairs(...) do
        local name = entry.name
        entry.name = nil
        gui_custom.register_event_handlers_for(gid, name, entry)
    end
end

return gui_generator
