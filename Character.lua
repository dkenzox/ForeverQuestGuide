local _, Guide = ...
local Character = {}
Guide.Character = Character

function Character.Settings()
    ForeverQuestGuideCharacter = ForeverQuestGuideCharacter or {}
    return ForeverQuestGuideCharacter
end

function Character.Skill(id)
    if C_SkillInfo and C_SkillInfo.GetSkillLineInfoByID then
        local info = C_SkillInfo.GetSkillLineInfoByID(id)
        if info then return info.rank or 0, info.modifier or 0 end
    end
    return 0, 0
end

function Character.Reputation(id)
    if C_Reputation and C_Reputation.GetFactionDataByID then
        local info = C_Reputation.GetFactionDataByID(id)
        return info and info.currentStanding
    end
    if GetFactionInfoByID then
        local _, _, _, _, _, value = GetFactionInfoByID(id)
        return value
    end
end

function Character.HasSpell(id)
    return (IsPlayerSpell and IsPlayerSpell(id))
        or (IsSpellKnown and IsSpellKnown(id))
        or (C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(id))
end
