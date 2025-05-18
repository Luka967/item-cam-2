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
    name = const.name_options_shortcut,
    type = "shortcut",
    icon = "__base__/graphics/icons/iron-plate.png",
    small_icon = "__base__/graphics/icons/iron-plate.png",
    action = "lua",
    toggleable = true
}})

data:extend({{
    name = const.name_keybind,
    type = "custom-input",
    key_sequence = "ALT + C",
    action = "lua"
}})

data.raw["gui-style"]["default"].ic2gui_followrules_action_draggable_space = {
    type = "empty_widget_style",
    parent = "draggable_space",
    minimal_width = 20,
    height = 32,
    horizontally_stretchable = "on"
}

data.raw["gui-style"]["default"].ic2gui_followrules_entry_list_scroll = {
    type = "scroll_pane_style",
    width = 500,
    minimal_height = 300,
    maximal_height = 600
}

data.raw["gui-style"]["default"].ic2gui_followrules_entry_frame = {
    type = "frame_style",
    parent = "shallow_frame",
    top_padding = 0,
    bottom_padding = 0,
    left_padding = 0,
    horizontally_stretchable = "on",
    vertical_align = "center"
}

data.raw["gui-style"]["default"].ic2gui_followrules_draggable_space = {
    type = "empty_widget_style",
    parent = "draggable_space",
    width = 24,
    height = 40,
    right_margin = 8
}

data.raw["gui-style"]["default"].ic2gui_followrules_detail_label = {
    type = "label_style",
    single_line = false,
    ignored_by_search = true,
    bottom_margin = -4,
    maximal_width = 400
}

data.raw["gui-style"]["default"].ic2gui_followrules_detail_label_last = {
    type = "label_style",
    parent = "ic2gui_followrules_detail_label",
    bottom_margin = 4
}

data.raw["gui-style"]["default"].ic2gui_followrules_detail_label_semibold = {
    type = "label_style",
    parent = "semibold_caption_label",
    single_line = false,
    bottom_margin = -4,
    maximal_width = 400
}

data.raw["gui-style"]["default"].ic2gui_followrules_order_label = {
    type = "label_style",
    parent = "semibold_caption_label",
    single_line = true,
    right_margin = 8
}
