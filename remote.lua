local remote_interface = "item-cam"

--- @class (exact) FocusInstanceRemote
--- @field id integer
local focus_instance = {}

--- @type metatable
local focus_instance_meta = {
    __index = focus_instance
}
script.register_metatable("ic2-focus_instance_meta", focus_instance_meta)

--- Check if this focus instance is still valid. This is always safe to call.
function focus_instance:valid()
    --- @type boolean
    return remote.call(remote_interface, "focus_is_valid", self.id)
end

--- Check if this focus instance is actively following something. This is always safe to call.
function focus_instance:running()
    --- @type boolean
    return remote.call(remote_interface, "focus_is_running", self.id)
end

--- Returns the tag table associated with this focus instance.
---
--- The returned table is a copy. Modifying its keys will not persist.
--- `:set_tags()` may be called with this same table.
function focus_instance:get_tags()
    --- @type table<string, AnyBasic>?
    return remote.call(remote_interface, "focus_get_tags", self.id)
end

--- Sets the tag table associated with this focus instance.
function focus_instance:set_tags(value)
    remote.call(remote_interface, "focus_set_tags", self.id, value)
    return self
end

--- Allow a LuaPlayer to be controlled by this focus instance.
--- This mode turns on player's remote view, with position and zoom managed by Item Cam 2.
---
--- Calling while focus instance is running will throw.
---
--- Only one of either a `add_controllable_player_remote` or `add_controllable_player`
--- calls should be made for the same player. Item Cam 2 will not verify correctness. If violated behavior is undefined.
--- @param player LuaPlayer
function focus_instance:add_controllable_player_remote(player)
    --- @type nil
    remote.call(remote_interface, "focus_add_controllable_player_remote", self.id, player)
    return self
end

--- Allow a LuaPlayer to be controlled by this focus instance. This mode creates a `LuaGuiElement` managed by Item Cam 2
--- which will overlap the player's entire screen.
---
--- Throws if focus instance is running.
---
--- Only one of either a `add_controllable_player_remote` or `add_controllable_player`
--- calls should be made for the same player. Item Cam 2 will not verify correctness. If violated behavior is undefined.
--- @param player LuaPlayer
function focus_instance:add_controllable_player(player)
    --- @type nil
    remote.call(remote_interface, "focus_add_controllable_player", self.id, player)
    return self
end

--- Allow a `LuaGuiElement` of type camera to be controlled by this focus instance.
---
--- Throws if focus instance is running.
---
--- Only one call to the same `LuaGuiElement` should be made.
--- Item Cam 2 will not verify correctness. If violated behavior is undefined.
--- @param camera_elem LuaGuiElement
function focus_instance:add_controllable_camera(camera_elem)
    --- @type nil
    remote.call(remote_interface, "focus_add_controllable_player", self.id, camera_elem)
    return self
end

--- Start this focus instance from specified point.
--- Returns `true` if started succesfully.
--- Returns `false` if focus tracker could not find anything to start from.
---
--- Throws if focus instance is running.
---
--- Starting with no controllables added will mark the focus instance invalid this or next tick.
--- @param surface SurfaceIdentification
--- @param position MapPosition
--- @return boolean
function focus_instance:start_from_point(surface, position)
    --- @type boolean
    return remote.call(remote_interface, "focus_start_from_point", self.id, surface, position)
end

--- Start this focus instance from specified entity.
--- Returns `true` if started succesfully.
--- Returns `false` if focus tracker is unable to start from this entity.
---
--- Throws if focus instance is running.
---
--- Starting with no controllables added will mark the focus instance invalid this or next tick.
function focus_instance:start_from_entity()
    --- @type boolean
    return remote.call(remote_interface, "focus_is_running", self.id)
end

--- Destroy this focus instance.
---
--- Throws if focus instance is already invalid.
function focus_instance:destroy()
    remote.call(remote_interface, "focus_is_running", self.id)
end

local library = {}

--- Create a new focus instance. The returned object holds an ID
--- through which remote access to Item Cam 2's internals is available.
---
--- This reference remains valid until:
--- 1. The focus instance running, loses focus
--- 2. All of the controllables assigned to a focus instance go invalid
--- 3. `:destroy()` is manually called
---
--- Methods `:valid()` and `:running()` can be safely used even when reference is invalid.
--- Any other method call will throw.
--- @param follow_rules? FollowRule[]
function library.create_focus(follow_rules)
    local ret = remote.call(remote_interface, "focus_create", follow_rules)
    --- @cast ret FocusInstance

    setmetatable(ret, focus_instance_meta)
    return ret
end

return library
