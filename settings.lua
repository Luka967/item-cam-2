data:extend({{
    type = "bool-setting",
    name = "debug-tracker",
    setting_type = "runtime-global", -- Placeholder. This really should be per player
    default_value = false,
    order = "a"
}})

data:extend({{
    type = "bool-setting",
    name = "camera-stopping-opens-remote",
    setting_type = "runtime-per-user",
    default_value = true,
    order = "a"
}})
