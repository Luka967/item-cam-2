--- @module "const"
local const = require("__item-cam-2__.script.const")

--- @class (exact) FocusControllablePlayer
--- @field type "player"
--- @field player LuaPlayer
--- @field camera? LuaGuiElement

local controllable_player = {}
controllable_player.type = "player"

--- @param player LuaPlayer
function controllable_player.create(player)
    --- @type FocusControllablePlayer
    return {
        type = controllable_player.type,
        player = player
    }
end

--- @param controllable FocusControllablePlayer
function controllable_player.valid(controllable)
    return controllable.camera.valid
end

--- @param camera LuaGuiElement
--- @param player LuaPlayer
local function update_camera_size(camera, player)
    camera.position.x = 0
    camera.position.y = 0
    local res = player.display_resolution
    camera.style.width = res.width / player.display_scale / player.display_density_scale
    camera.style.height = res.height / player.display_scale / player.display_density_scale
end

--- @param controllable FocusControllablePlayer
--- @param focus FocusInstance
function controllable_player.start(controllable, focus)
    local player = controllable.player

    local camera = player.gui.screen.add({
        type = "camera",
        name = "item-cam-2-camera",
        position = focus.position,
        surface_index = focus.surface.index,
        zoom = const.zoom_initial
    })
    controllable.camera = camera

    update_camera_size(camera, player)
end

--- @param controllable FocusControllablePlayer
--- @param focus FocusInstance
function controllable_player.update(controllable, focus)
    update_camera_size(controllable.camera, controllable.player)
    controllable.camera.position = focus.smooth_position
    controllable.camera.surface_index = focus.surface.index
end

--- @param controllable FocusControllablePlayer
function controllable_player.stop(controllable)
    controllable.camera.destroy()
    controllable.camera = nil
end

return controllable_player
