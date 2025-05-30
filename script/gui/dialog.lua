--- @module "gui-custom"
local gui_custom = require("__item-cam-2__.script.gui-custom")
--- @module "gui-generator"
local gui_generator = require("__item-cam-2__.script.gui-generator")

local gui_dialog = {}
gui_dialog.gid = "dialog"

--- @class CustomGuiDialogRemoteCall
--- @field gid string
--- @field name string

--- @class CustomGuiDialogButtonStyle
--- @field caption LocalisedString
--- @field style string

--- @class CustomGuiDialogInput
--- @field window LuaGuiElement
--- @field clicked_button? boolean
--- @field back CustomGuiDialogRemoteCall
--- @field confirm? CustomGuiDialogRemoteCall

--- @class CustomGuiDialogOptions
--- @field player LuaPlayer
--- @field title LocalisedString
--- @field caption LocalisedString
--- @field back? boolean
--- @field confirm? CustomGuiDialogButtonStyle
--- @field remote CustomGuiDialogInput

--- @alias CustomGuiDialogState GeneratorGuiBaseState&CustomGuiDialogInput

--- @param options CustomGuiDialogOptions
function gui_dialog.open_for(options)
    local player = options.player

    --- @type CustomGuiElement[]
    local action_buttons = {}

    if options.back then
        --- @type CustomGuiElement
        local adding = {
            name = "back",
            type = "button",
            style = "back_button",
            caption = {"controls.back"}
        }
        table.insert(action_buttons, adding)
    end

    table.insert(action_buttons, {
        type = "empty-widget",
        style = "draggable_space",
        postfix = function (elem, window)
            elem.drag_target = window
        end
    })

    if options.confirm ~= nil then
        --- @type CustomGuiElement
        local adding = {
            name = "confirm",
            type = "button",
            style = options.confirm.style,
            caption = options.confirm.caption
        }
        table.insert(action_buttons, adding)
    end

    player.opened = gui_generator.generate_at(player.gui.screen, {
        name = gui_dialog.gid,
        gid = gui_dialog.gid,
        is_window_root = true,
        type = "frame",
        caption = options.title,
        direction = "vertical",
        postfix = function (elem)
            elem.auto_center = true
        end,
        children = {{
            type = "label",
            caption = options.caption
        }, {
            type = "flow",
            direction = "horizontal",
            style = "dialog_buttons_horizontal_flow",
            children = action_buttons
        }}
    })

    local gui_state = gui_custom.get_state(player.index, gui_dialog.gid)
    assert(gui_state ~= nil, "gui_custom state is nil for newly opened dialog")
    gui_state.window = options.remote.window
    gui_state.back = options.remote.back
    gui_state.confirm = options.remote.confirm
end

-- In any of these events the dialog button will close itself
-- before remote calling an event.
-- This allows the parent window to create another dialog
-- without it automatically getting closed on itself.

function gui_dialog.register_event_handlers()
    gui_generator.register_event_handlers(gui_dialog.gid, {{
        name = gui_dialog.gid,
        --- @param gui_state CustomGuiDialogInput
        closed = function (event, gui_state)
            if gui_state.clicked_button
                then return end -- Don't trigger when button press closes GUI

            gui_dialog.close_for(event.player_index)

            local calling = gui_state.back or gui_state.confirm
            if calling == nil
                then return end

            gui_custom.remote_call_event(calling.gid, calling.name, event)
        end
    }, {
        name = "confirm",
        --- @param gui_state CustomGuiDialogInput
        click = function (event, gui_state)
            gui_state.clicked_button = true

            local calling = gui_state.confirm
            assert(calling ~= nil, "pressed confirm for nil confirm_remote")

            gui_dialog.close_for(event.player_index)
            gui_custom.remote_call_event(calling.gid, calling.name, event)
        end
    }, {
        name = "back",
        --- @param gui_state CustomGuiDialogInput
        click = function (event, gui_state)
            gui_state.clicked_button = true

            local calling = gui_state.back
            assert(calling ~= nil, "pressed back for nil back_remote")

            gui_dialog.close_for(event.player_index)
            gui_custom.remote_call_event(calling.gid, calling.name, event)
        end
    }})
end

--- @param player_index number
function gui_dialog.close_for(player_index)
    local player = game.get_player(player_index)
    if player == nil
        then return end
    player.gui.screen[gui_dialog.gid].destroy()
    gui_custom.destroy_state(player_index, gui_dialog.gid)
end

return gui_dialog
