--- @class FollowRuleItemOutOfContainer
--- @field type "item-out-of-container"
--- @field entity? PrototypeWithQuality
--- @field target? PrototypeWithQuality

--- @class FollowRuleItemOutOfCrafter
--- @field type "item-out-of-crafter"
--- @field entity? PrototypeWithQuality
--- @field recipe? PrototypeWithQuality
--- @field target? PrototypeWithQuality

--- @class FollowRuleItemFromResource
--- @field type "item-from-resource"
--- @field entity? PrototypeWithQuality
--- @field resource? string
--- @field target? PrototypeWithQuality

--- @class FollowRuleItemFromPlant
--- @field type "item-from-plant"
--- @field entity? string
--- @field target? PrototypeWithQuality

-- Functionally equivalent but differentiated in GUI for convenience
--- @class FollowRuleItemOutOfPlatform: FollowRuleItemOutOfContainer
--- @field type "item-out-of-platform"
--- @class FollowRuleItemFromAsteroidCollector: FollowRuleItemOutOfContainer
--- @field type "item-from-asteroid-collector"

--- @alias FollowRule FollowRuleItemOutOfContainer|FollowRuleItemOutOfCrafter|FollowRuleItemFromResource|FollowRuleItemFromPlant|FollowRuleItemOutOfPlatform|FollowRuleItemFromAsteroidCollector

local focus_follow_rules = {}

--- @param a PrototypeWithQuality
--- @param b PrototypeWithQuality
local function is_proto_with_quality_matching(a, b)
    return a.name == b.name and a.quality == b.quality
end

--- @param a FollowRule
--- @param b FollowRule
function focus_follow_rules.is_prerequisite_matching(a, b)
    if a.type ~= b.type
        then return end
    -- Double checked for luals type restriction sake
    if a.type == "item-out-of-crafter" and b.type == "item-out-of-crafter" then
        return is_proto_with_quality_matching(a.entity, b.entity)
            and is_proto_with_quality_matching(a.recipe, b.recipe)
    end
    if a.type == "item-out-of-container" and b.type == "item-out-of-container" then
        return is_proto_with_quality_matching(a.entity, b.entity)
    end
    if a.type == "item-from-resource" and b.type == "item-from-resource" then
        return is_proto_with_quality_matching(a.entity, b.entity)
            and a.resource == b.resource
    end
    if a.type == "item-from-plant" and b.type == "item-from-plant" then
        return a.entity == b.entity
    end
    if a.type == "item-from-asteroid-collector" and b.type == "item-asteroid-collector" then
        return a.entity == b.entity
    end
end

--- @param focus FocusInstance
--- @param matching FollowRule
function focus_follow_rules.seek_matching_item_wl(focus, matching)
    local rules = focus.follow_rules
    if rules == nil
        then return end
    local cnt = focus.follow_rules_cnt
    local idx_start = focus.follow_rules_start_idx
    --- @cast cnt number
    --- @cast idx_start number

    for idx = idx_start, cnt do
        if focus_follow_rules.is_prerequisite_matching(rules[idx], matching) then
            --- @type FocusItemWhitelist
            local ret = {
                item = {
                    name = prototypes.item[rules[idx].target.name],
                    quality = rules[idx].target.quality
                }
            }
            focus.follow_rules_start_idx = idx + 1
            return ret
        end
    end
end

return focus_follow_rules
