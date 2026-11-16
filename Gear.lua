local _, Guide = ...
local Gear = {}
Guide.Gear = Gear

local Data = Guide.Data
local itemInfo = C_Item and C_Item.GetItemInfo or GetItemInfo
local itemInstant = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
local pending, queue, cursor = {}, {}, 1
local statsByLink = {}
local quickStats = {
    { "ITEM_MOD_DAMAGE_PER_SECOND_SHORT", "DPS" }, { "RESISTANCE0_NAME", "Armor" },
    { "ITEM_MOD_ARMOR_SHORT", "Armor" }, { "ITEM_MOD_BLOCK_VALUE_SHORT", "Block" },
    { "ITEM_MOD_STRENGTH_SHORT", "Str" }, { "ITEM_MOD_AGILITY_SHORT", "Agi" },
    { "ITEM_MOD_STAMINA_SHORT", "Sta" }, { "ITEM_MOD_INTELLECT_SHORT", "Int" },
    { "ITEM_MOD_SPIRIT_SHORT", "Spi" }, { "ITEM_MOD_ATTACK_POWER_SHORT", "AP" },
    { "ITEM_MOD_SPELL_POWER_SHORT", "SP" }, { "ITEM_MOD_HEALING_DONE_SHORT", "Healing" },
    { "ITEM_MOD_CRIT_RATING_SHORT", "Crit" }, { "ITEM_MOD_HIT_RATING_SHORT", "Hit" },
    { "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT", "Defense" },
}

function Gear.Stats(link)
    if not link then return end
    if statsByLink[link] ~= nil then return statsByLink[link] end
    local api = C_Item and C_Item.GetItemStats or GetItemStats
    local stats = api and api(link)
    if type(stats) ~= "table" then return end
    local parts, seen = {}, {}
    for _, stat in ipairs(quickStats) do
        local key, fallback = stat[1], stat[2]
        local value = stats[key]
        if type(value) == "number" and value ~= 0 and not seen[fallback] then
            seen[fallback] = true
            parts[#parts + 1] = ("%+g %s"):format(value, _G[key] or fallback)
        end
    end
    local summary = table.concat(parts, " · ", 1, math.min(5, #parts))
    statsByLink[link] = summary
    return summary
end

local function instant(id)
    if not itemInstant then return end
    local _, _, _, slot, icon, class, subclass = itemInstant(id)
    if (class == 2 or class == 4) and slot and slot ~= "" and slot ~= "INVTYPE_NON_EQUIP" then
        return class, subclass, slot, icon
    end
end

local function requestBatch()
    for i = cursor, math.min(cursor + 15, #queue) do
        local id = queue[i]
        C_Item.RequestLoadItemDataByID(id)
        -- Some unavailable IDs don't produce a result.
        C_Timer.After(12, function() Gear.Loaded(id) end)
        cursor = i + 1
    end
    if cursor <= #queue then
        C_Timer.After(.12, requestBatch)
    else
        queue, cursor = {}, 1
    end
end

function Gear.Loaded(id)
    if pending[id] ~= true then return false end
    pending[id] = false
    if Gear.OnChanged then Gear.OnChanged() end
end

local function request(id)
    if pending[id] ~= nil or not (C_Item and C_Item.RequestLoadItemDataByID) then return end
    pending[id] = true
    queue[#queue + 1] = id
    if #queue == 1 then C_Timer.After(0, requestBatch) end
end

function Gear.Info(id, player, load)
    local class, subclass, slot, icon = instant(id)
    if not class then return end
    if class == 4 and subclass and subclass >= 1 and subclass <= 4 and subclass > player.armor then
        return
    end
    local name, link, quality, itemLevel, requiredLevel, _, subtype = itemInfo(id)
    if not name then
        if load then request(id) end
        return
    end
    if (requiredLevel or 0) > player.level then return end
    local tint = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality or 1]
    local slotName = _G[slot] or subtype
    local typeName = slotName or ""
    if subtype and subtype ~= "" and subtype ~= slotName then
        typeName = typeName ~= "" and typeName .. " · " .. subtype or subtype
    end
    return {
        id = id, name = name, link = link, typeName = typeName, icon = icon,
        itemLevel = itemLevel or 0, level = requiredLevel or 0, tint = tint,
    }
end



-- Keep each reward with its own quest, including when two quests grant the same item.
function Gear.Zone(player, quests)
    local result, waiting = {}, false
    for _, row in ipairs(quests) do
        for _, reward in ipairs(Data.Rewards(row.quest.id)) do
            local item = Gear.Info(reward.id, player, true)
            if item then
                item.quest, item.reward = row.quest, reward
                result[#result + 1] = item
            elseif pending[reward.id] then
                waiting = true
            end
        end
    end
    return result, waiting
end
