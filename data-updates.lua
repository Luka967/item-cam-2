local const = require("script.const")

--- @param name string
--- @param accessor fun(): data.EntityPrototype
local function add_script_effect(name, accessor)
    local effects_set = accessor().created_effect
    if effects_set ~= nil and effects_set[1] == nil then
        effects_set = {effects_set}
    elseif effects_set == nil then
        effects_set = {}
    end
    effects_set[#effects_set+1] = {
        type = "direct",
        action_delivery = {{
            type = "instant",
            target_effects = {{
                type = "script",
                effect_id = name
            }}
        }}
    }
    accessor().created_effect = effects_set
end

for proto_name in pairs(data.raw["cargo-landing-pad"]) do
    add_script_effect(const.name_trigger_remember_landing_pad, function ()
        return data.raw["cargo-landing-pad"][proto_name]
    end)
end

for proto_name in pairs(data.raw["cargo-pod"]) do
    add_script_effect(const.name_trigger_check_cargo_pod_follow, function ()
        return data.raw["cargo-pod"][proto_name]
    end)
end
