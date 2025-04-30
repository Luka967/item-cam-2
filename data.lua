local const = require("script.const")

data:extend({{
    name = const.name_selection_item,
    localised_description = "shortcut.item-cam",
    type = "selection-tool",
    icon = "__item-cam-2__/graphics/icons/item-cam.png",
    flags = {"not-stackable", "only-in-cursor"},
    stack_size = 1,
    auto_recycle = false,
    select = {
        border_color = {255, 255, 0, 255},
        cursor_box_type = "entity",
        mode = "any-entity"
    },
    alt_select = {
        border_color = {255, 255, 0, 255},
        cursor_box_type = "entity",
        mode = "any-entity"
    }
}})

data:extend({{
    name = const.name_shortcut,
    type = "shortcut",
    localised_description = "shortcut.item-cam",
    icon = "__item-cam-2__/graphics/icons/item-cam.png",
    small_icon = "__item-cam-2__/graphics/icons/item-cam.png",
    action = "lua",
    toggleable = true
}})

data:extend({{
    name = const.name_keybind,
    type = "custom-input",
    key_sequence = "ALT + C",
    action = "lua"
}})
