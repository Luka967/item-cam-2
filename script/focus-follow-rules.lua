--- @module "utility"
local utility = require("__item-cam-2__.script.utility")

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
end

--- @param watching FocusWatchdog
local function generate_matcher_from_current_watchdog(watching)
    if
        watching.type == "item-in-container"
        or watching.type == "item-in-container-with-cargo-hatches"
        or watching.type == "item-in-rocket-silo"
    then
        --- @type FollowRuleItemOutOfContainer
        return {
            type = "item-out-of-container",
            entity = utility.entity_proto(watching.handle)
        }
    end
    if watching.type == "item-in-crafting-machine" then
        --- @type FollowRuleItemOutOfCrafter
        return {
            type = "item-out-of-crafter",
            entity = utility.entity_proto(watching.handle),
            recipe = utility.crafter_recipe_proto(watching.handle)
        }
    end
    if watching.type == "plant-growing" then
        --- @type FollowRuleItemFromPlant
        return {
            type = "item-from-plant",
            entity = watching.handle.name
        }
    end
    if watching.type == "item-coming-from-asteroid-collector" then
        --- @type FollowRuleItemFromAsteroidCollector
        return {
            type = "item-from-asteroid-collector",
            entity = utility.entity_proto(watching.handle)
        }
    end
    if watching.type == "item-coming-from-mining-drill" then
        --- @type FollowRuleItemFromResource
        return {
            type = "item-from-resource",
            entity = utility.entity_proto(watching.handle),
            resource = watching.handle.mining_target.name
        }
    end
end

--- @param focus FocusInstance
function focus_follow_rules.apply_matching(focus)
    local rules = focus.follow_rules
    if rules == nil
        then return end
    local cnt = focus.follow_rules_cnt
    local idx_start = focus.follow_rules_start_idx
    assert(cnt ~= nil, "follow_rules_cnt nil yet follow_rules defined")
    assert(idx_start ~= nil, "follow_rules_start_idx nil yet follow_rules defined")

    local matcher = generate_matcher_from_current_watchdog(focus.watching)
    if matcher == nil
        then return end
    utility.debug("follow rules matcher "..matcher.type.." running at #"..idx_start.." / "..cnt)

    for idx = idx_start, cnt do
        if focus_follow_rules.is_prerequisite_matching(rules[idx], matcher) then
            utility.debug("follow rules picked #"..idx)
            focus.watching.item_wl = {
                item = {
                    name = rules[idx].target.name,
                    quality = rules[idx].target.quality
                }
            }
            focus.follow_rules_start_idx = idx + 1
            return
        end
    end
end

return focus_follow_rules
