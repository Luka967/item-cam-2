--- @module "const"
local const = require("__item-cam-2__.script.const")

--- @class (exact) FocusControllableGuiCamera
--- @field type "gui-camera"
--- @field elem LuaGuiElement

local controllable_gui_camera = {}
controllable_gui_camera.type = "gui-camera"

--- @param camera_elem LuaGuiElement
function controllable_gui_camera.create(camera_elem)
    --- @type FocusControllableGuiCamera
    return {
        type = controllable_gui_camera.type,
        elem = camera_elem
    }
end

--- @param controllable FocusControllableGuiCamera
function controllable_gui_camera.valid(controllable)
    return controllable.elem.valid
end

--- @param controllable FocusControllableGuiCamera
--- @param focus FocusInstance
function controllable_gui_camera.start(controllable, focus)
    controllable_gui_camera.update(controllable, focus)
    controllable.elem.zoom = const.zoom_initial
end

--- @param controllable FocusControllableGuiCamera
--- @param focus FocusInstance
function controllable_gui_camera.update(controllable, focus)
    controllable.elem.position = focus.smooth_position
    controllable.elem.surface_index = focus.surface.index
end

--- @param controllable FocusControllableGuiCamera
function controllable_gui_camera.stop(controllable)
    -- No-op
end

return controllable_gui_camera
