--- @module "const"
local const = require("const")

--- @class FocusControllablePlayerRemote
--- @field type "player-remote"
--- @field player LuaPlayer

local controllable_player_remote = {}
controllable_player_remote.type = "player-remote"

--- @param player LuaPlayer
function controllable_player_remote.create(player)
    --- @type FocusControllablePlayerRemote
    return {
        type = controllable_player_remote.type,
        player = player
    }
end

--- @param controllable FocusControllablePlayerRemote
function controllable_player_remote.valid(controllable)
    return controllable.player.valid
end

--- @param controllable FocusControllablePlayerRemote
--- @param focus FocusInstance
function controllable_player_remote.start(controllable, focus)
    controllable.player.set_controller({
        type = defines.controllers.remote,
        start_position = focus.position,
        surface = focus.surface
    })
end

--- @param controllable FocusControllablePlayerRemote
--- @param focus FocusInstance
function controllable_player_remote.update(controllable, focus)
    controllable.player.position = focus.smooth_position
    controllable.player.surface = focus.surface
end

--- @param controllable FocusControllablePlayerRemote
function controllable_player_remote.stop(controllable)
    controllable.player.exit_remote_view()
end

return controllable_player_remote
