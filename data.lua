data:extend({{
    name = "item-cam",
    type = "selection-tool",
    icon = "__base__/graphics/icons/iron-plate.png",
    flags = {"not-stackable", "only-in-cursor"},
    stack_size = 1,
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
    name = "item-cam",
    type = "shortcut",
    icon = "__base__/graphics/icons/iron-plate.png",
    small_icon = "__base__/graphics/icons/iron-plate.png",
    action = "lua",
    toggleable = true
}})
