local gui_custom = require("gui-custom")

--- @class CustomGuiElementExtra
--- @field gid? string
--- @field postfix? fun(elem: LuaGuiElement)
--- @field children? CustomGuiElement[]

--- @alias CustomGuiElement LuaGuiElement.add_param|CustomGuiElementExtra

local gui_generator = {}

--- @param target LuaGuiElement
--- @param spec CustomGuiElement
function gui_generator.generate_at(target, spec)
    local children = spec.children
    if children ~= nil
        then spec.children = nil end

    local gid = spec.gid
    if gid ~= nil then
        spec.tags = {gid = gid}
        spec.gid = nil
    end

    local postfix = spec.postfix
    if postfix ~= nil
        then spec.postfix = nil end

    --- @cast spec LuaGuiElement.add_param
    local created_element = target.add(spec)
    if children == nil
        then return end

    if postfix ~= nil then
        postfix(created_element)
    end

    for _, child_spec in ipairs(children) do
        gui_generator.generate_at(created_element, child_spec)
    end

    return created_element
end

--- @class CustomGuiElementEvents: CustomGuiEventHandlerTable
--- @field name string

--- @param gid string
--- @param ... CustomGuiElementEvents[]
function gui_generator.register_event_handlers(gid, ...)
    for _, entry in ipairs(...) do
        local name = entry.name
        entry.name = nil
        gui_custom.register_event_handlers_for(gid, name, entry)
    end
end

return gui_generator
