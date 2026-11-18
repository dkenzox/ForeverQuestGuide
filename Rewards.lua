local _, Guide = ...
local L, Data = Guide.Locale, Guide.Data
local Rewards = {}
Guide.Rewards = Rewards

local requests, queued = {}, {}
local running
local function pump()
    for _ = 1, math.min(8, #queued) do
        C_QuestLog.RequestLoadQuestByID(table.remove(queued, 1))
    end
    running = #queued > 0
    if running then C_Timer.After(.15, pump) end
end

function Rewards.Loaded(id, success)
    if not requests[id] then return false end
    if requests[id] ~= "pending" then return false end
    requests[id] = success and "loaded" or "failed"
    return true
end

local function request(id)
    if requests[id] or not C_QuestLog.RequestLoadQuestByID then return end
    requests[id] = "pending"
    queued[#queued + 1] = id
    if not running then
        running = true
        C_Timer.After(0, pump)
    end
end

local function numberFrom(api, id)
    if not api then return end
    local ok, value = pcall(api, id)
    if ok and not (issecretvalue and issecretvalue(value)) and type(value) == "number" and value >= 0 then
        return value
    end
end

local function estimate(quest)
    local provider = LibQuestieDB and LibQuestieDB.Support
    local support = provider and provider.Get("QuestXP")
    local pair = support and support.db and support.db[quest.id]
    if not pair or pair[1] <= 0 then return end
    local xp = pair[2] * math.max(1, math.min(10, 2 * (pair[1] - UnitLevel("player")) + 20)) / 10
    local step = xp <= 100 and 5 or (xp <= 500 and 10 or (xp <= 1000 and 25 or 50))
    return step * math.floor(xp / step + .5)
end

local function moneyText(copper)
    if not copper or copper <= 0 then return end
    local gold = math.floor(copper / 10000)
    local silver = math.floor(copper / 100) % 100
    local remainder = copper % 100
    local parts = {}
    local function coin(amount, metal)
        parts[#parts + 1] = ("%d|TInterface\\MoneyFrame\\UI-%sIcon:10:10|t"):format(amount, metal)
    end
    if gold > 0 then coin(gold, "Gold") end
    if silver > 0 then coin(silver, "Silver") end
    if remainder > 0 then coin(remainder, "Copper") end
    return table.concat(parts, " ")
end

local function rewardReady(id)
    return (HaveQuestRewardData and HaveQuestRewardData(id)) or requests[id] == "loaded" or Data.OnQuest(id)
end

local function questXP(quest, load)
    local maxLevel = GetMaxPlayerLevel and GetMaxPlayerLevel()
    if maxLevel and UnitLevel("player") >= maxLevel then return 0, false end
    local id = quest.id
    local xp = numberFrom(GetQuestLogRewardXP, id)
    if xp == 0 and not rewardReady(id) then xp = nil end
    if xp ~= nil then return xp, false end
    if load then request(id) end
    return estimate(quest), true
end

function Rewards.TotalXP(quests, load)
    local total, estimates, known, missing, seen = 0, 0, 0, 0, {}
    for _, result in ipairs(quests) do
        local quest = result.quest
        if not seen[quest.id] then
            seen[quest.id] = true
            local xp, estimated = questXP(quest, load)
            if xp ~= nil then
                total, known = total + xp, known + 1
                if estimated then estimates = estimates + 1 end
            else
                missing = missing + 1
            end
        end
    end
    if known == 0 and missing > 0 then return "—", known, missing, estimates end
    local formatted = BreakUpLargeNumbers and BreakUpLargeNumbers(total) or tostring(total)
    return (estimates > 0 and "~" or "") .. formatted .. (missing > 0 and "+" or ""), known, missing, estimates
end

function Rewards.Summary(quest)
    local id = quest.id
    local ready = rewardReady(id)
    if not (HaveQuestRewardData and HaveQuestRewardData(id)) then request(id) end
    local xp, approximate = questXP(quest)
    local money = numberFrom(GetQuestLogRewardMoney, id)
    if money == 0 and not ready then money = nil end
    local xpMax = UnitXPMax and UnitXPMax("player")
    local xpText
    if xp and xp > 0 then
        local value = (approximate and "~" or "") .. (BreakUpLargeNumbers and BreakUpLargeNumbers(xp) or xp)
        xpText = xpMax and xpMax > 0 and L.XP_PERCENT:format(value, 100 * xp / xpMax) or L.XP_AMOUNT:format(value)
    end
    local moneyDisplay = moneyText(money)
    local items = Data.Rewards(id)
    local itemText = {}
    for i = 1, math.min(#items, 3) do
        local item = items[i]
        local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(item.id)
        itemText[#itemText + 1] = icon and ("|T%s:11:11|t"):format(icon) or item.name
    end
    if #items > 3 then itemText[#itemText + 1] = "+" .. (#items - 3) end
    local parts = {}
    if xpText then parts[#parts + 1] = xpText end
    if moneyDisplay then parts[#parts + 1] = moneyDisplay end
    if #itemText > 0 then parts[#parts + 1] = table.concat(itemText, " ") end
    return table.concat(parts, "  ·  "), xpText, moneyDisplay, items
end
