local const = require("script.const")

data:extend({{
    name = "on_focus_switch",
    type = "custom-event"
}, {
    name = "on_focus_destroyed",
    type = "custom-event"
}})

data:extend({{
    name = const.name_selection_item,
    localised_description = {"shortcut-description.item-cam"},
    type = "selection-tool",
    icon = "__item-cam-2__/graphics/icons/item-cam.png",
    flags = {"not-stackable", "only-in-cursor", "spawnable"},
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
    localised_description = {"shortcut-description.item-cam"},
    icon = "__item-cam-2__/graphics/icons/item-cam.png",
    small_icon = "__item-cam-2__/graphics/icons/item-cam.png",
    action = "lua",
    toggleable = true
}})

data:extend({{
    name = const.name_options_shortcut,
    type = "shortcut",
    icon = "__item-cam-2__/graphics/icons/item-cam-options.png",
    small_icon = "__item-cam-2__/graphics/icons/item-cam-options.png",
    action = "lua",
    toggleable = true
}})

data:extend({{
    name = const.name_keybind,
    type = "custom-input",
    key_sequence = "ALT + C",
    action = "lua"
}})

data.raw["gui-style"].default.ic2gui_followrules_action_draggable_space = {
    type = "empty_widget_style",
    parent = "draggable_space",
    minimal_width = 20,
    height = 32,
    horizontally_stretchable = "on",
    right_margin = 4
}

data.raw["gui-style"].default.ic2gui_followrules_entry_list_scroll = {
    type = "scroll_pane_style",
    width = 480,
    height = 600
}

data.raw["gui-style"].default.ic2gui_followrules_entry_add_button = {
    type = "dropdown_style",
    horizontally_stretchable = "on",
    height = 40,
    horizontal_align = "left"
}

data.raw["gui-style"].default.ic2gui_followrules_entry_frame = {
    type = "frame_style",
    parent = "shallow_frame",
    top_padding = 0,
    bottom_padding = 0,
    left_padding = 0,
    horizontally_stretchable = "on",
    height = 48, -- 4 px top/bottom padding no matter what
    vertical_align = "center"
}

data.raw["gui-style"].default.ic2gui_followrules_entry_empty_space = {
    type = "empty_widget_style",
    horizontally_stretchable = "on",
    vertically_stretchable = "on"
}

data.raw["gui-style"].default.ic2gui_followrules_entry_delete_button = {
    type = "button_style",
    parent = "dark_button",
    width = 16,
    padding = 0,
    invert_colors_of_picture_when_hovered_or_toggled = true,
    left_click_sound = "__core__/sound/gui-tool-button.ogg",
    hovered_graphical_set = {
        base = data.raw["gui-style"].default.button.hovered_graphical_set.base,
        shadow = {position = {395, 86}, corner_size = 8, draw_type = "outer"},
        glow = data.raw["gui-style"].default.button.hovered_graphical_set.glow
    },
    clicked_graphical_set = {
        base = data.raw["gui-style"].default.button.clicked_graphical_set.base,
        shadow = {position = {395, 86}, corner_size = 8, draw_type = "outer"}
    }
}

data.raw["gui-style"].default.ic2gui_followrules_detail_label = {
    type = "label_style",
    single_line = false,
    ignored_by_search = true,
    bottom_margin = -4,
    maximal_width = 480
}

data.raw["gui-style"].default.ic2gui_followrules_detail_label_last = {
    type = "label_style",
    parent = "ic2gui_followrules_detail_label",
    bottom_margin = 4
}

data.raw["gui-style"].default.ic2gui_followrules_detail_label_semibold = {
    type = "label_style",
    parent = "semibold_caption_label",
    single_line = false,
    bottom_margin = -4,
    maximal_width = 400
}

data.raw["gui-style"].default.ic2gui_followrules_order_label = {
    type = "label_style",
    parent = "semibold_caption_label",
    left_margin = 8,
    right_margin = 8,
}
data.raw["gui-style"].default.ic2gui_followrules_order_buttons = {
    type = "vertical_flow_style",
    right_margin = 8
}
local function entry_move_graphics(direction)
    --- @type data.ButtonStyleSpecification
    return {
        type = "button_style",
        size = {8, 8},
        tooltip = "gui-follow-rules.rule-move-"..direction.."-tooltip",
        default_graphical_set = {
            filename = "__core__/graphics/arrows/table-header-sort-arrow-"..direction.."-active.png",
            size = {16, 16},
            scale = 0.5
        },
        hovered_graphical_set = {
            filename = "__core__/graphics/arrows/table-header-sort-arrow-"..direction.."-hover.png",
            size = {16, 16},
            scale = 0.5
        },
        clicked_graphical_set = {
            filename = "__core__/graphics/arrows/table-header-sort-arrow-"..direction.."-active.png",
            size = {16, 16},
            scale = 0.5
        },
        disabled_graphical_set = {
            filename = "__core__/graphics/arrows/table-header-sort-arrow-"..direction.."-white.png",
            size = {16, 16},
            scale = 0.5
        }
    }
end
data.raw["gui-style"].default.ic2gui_followrules_entry_move_up_button = entry_move_graphics("up")
data.raw["gui-style"].default.ic2gui_followrules_entry_move_down_button = entry_move_graphics("down")
