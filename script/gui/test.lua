--- @module "gui-custom"
local gui_custom = require("__item-cam-2__.script.gui-custom")

--- @module "gui-generator"
local gui_generator = require("__item-cam-2__.script.gui-generator")

local gui_test = {}
gui_test.gid = "test-gid"

function gui_test.register_event_handlers()
    gui_generator.register_event_handlers(gui_test.gid, {{
        name = "test-frame",
        closed = function (event, custom_state)
            game.print("i am now closed, but i was open at tick "..custom_state.tick_opened)
            gui_custom.destroy_state(event.player_index, gui_test.gid)
            event.element.destroy()
        end
    }, {
        name = "test-button",
        click = function (event)
            game.print("foobarbaz")
        end
    }})
end

--- @param player LuaPlayer
--- @param target_entity LuaEntity
function gui_test.create(player, target_entity)
    gui_custom.create_state(player.index, gui_test.gid, {
        tick_opened = game.tick
    })

    player.opened = gui_generator.generate_at(player.gui.screen, {
        gid = gui_test.gid,
        type = "frame",
        name = "test-frame",
        caption = "gui.test.title",
        postfix = function (elem)
            elem.auto_center = true
            elem.style.size = {300, 150}
        end,
        children = {{
            type = "button",
            name = "test-button",
            caption = "gui.test.button-caption"
        }}
    })
end

return gui_test
