local const = require("script.const")

for proto_name in pairs(data.raw["cargo-landing-pad"]) do
    local effects_set = data.raw["cargo-landing-pad"][proto_name].created_effect
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
                effect_id = const.name_trigger_remember_landing_pad
            }}
        }}
    }
    data.raw["cargo-landing-pad"][proto_name].created_effect = effects_set
end
