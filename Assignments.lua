-- BuffForge Assignments.lua
-- Stage 4: Class-based paladin blessing assignments
-- WoW 3.3.5a / Lua 5.1

local BF = BuffForge

BF.blessingClasses = {
    "WARRIOR", "PALADIN", "HUNTER", "ROGUE",
    "PRIEST", "DEATHKNIGHT", "SHAMAN",
    "MAGE", "WARLOCK", "DRUID"
}

BF.blessingNames = {
    "None", "Kings", "Might", "Wisdom", "Sanctuary"
}

BF.blessingSpells = {
    Kings = "Blessing of Kings",
    Might = "Blessing of Might",
    Wisdom = "Blessing of Wisdom",
    Sanctuary = "Blessing of Sanctuary"
}

BF.blessingAuras = {
    Kings = {
        "Blessing of Kings",
        "Greater Blessing of Kings"
    },
    Might = {
        "Blessing of Might",
        "Greater Blessing of Might"
    },
    Wisdom = {
        "Blessing of Wisdom",
        "Greater Blessing of Wisdom"
    },
    Sanctuary = {
        "Blessing of Sanctuary",
        "Greater Blessing of Sanctuary"
    }
}

local defaults = {
    WARRIOR = "Might",
    PALADIN = "Kings",
    HUNTER = "Might",
    ROGUE = "Might",
    PRIEST = "Wisdom",
    DEATHKNIGHT = "Might",
    SHAMAN = "Wisdom",
    MAGE = "Wisdom",
    WARLOCK = "Wisdom",
    DRUID = "Kings"
}

function BF:InitializeAssignments()
    if not self.db then return end

    if type(self.db.blessingAssignments) ~= "table" then
        self.db.blessingAssignments = {}
    end

    for class, blessing in pairs(defaults) do
        if self.db.blessingAssignments[class] == nil then
            self.db.blessingAssignments[class] = blessing
        end
    end
end

function BF:GetAssignedBlessing(class)
    if not self.db then return "None" end

    self:InitializeAssignments()

    return self.db.blessingAssignments[class] or "None"
end

function BF:SetAssignedBlessing(class, blessing)
    if not self.db then return end

    self:InitializeAssignments()

    local validClass = false
    local validBlessing = false

    for _, name in ipairs(self.blessingClasses) do
        if name == class then
            validClass = true
            break
        end
    end

    for _, name in ipairs(self.blessingNames) do
        if name == blessing then
            validBlessing = true
            break
        end
    end

    if not validClass or not validBlessing then
        return
    end

    self.db.blessingAssignments[class] = blessing

    if self.Refresh then
        self:Refresh()
    end
end

local function HasAssignedAura(unit, blessing)
    local names = BF.blessingAuras[blessing]

    if not names then return false end

    for i = 1, 40 do
        local name = UnitBuff(unit, i)

        if not name then break end

        for _, expected in ipairs(names) do
            if name == expected then
                return true
            end
        end
    end

    return false
end

local function IsEligible(unit)
    return UnitExists(unit)
        and UnitIsConnected(unit)
        and not UnitIsDeadOrGhost(unit)
        and UnitIsFriend("player", unit)
end

local function GetGroupUnits()
    local units = {}

    if GetNumRaidMembers() > 0 then
        for i = 1, GetNumRaidMembers() do
            table.insert(units, "raid" .. i)
        end
    elseif GetNumPartyMembers() > 0 then
        table.insert(units, "player")

        for i = 1, GetNumPartyMembers() do
            table.insert(units, "party" .. i)
        end
    end

    return units
end

-- Returns missing count, group count, next target,
-- and the spell assigned to that target.
--
-- Only a learned single-target blessing is returned.
-- The secure button will be configured outside combat.
function BF:GetBlessingTarget(known)
    if self.class ~= "PALADIN" then
        return 0, 0, nil, nil
    end

    self:InitializeAssignments()

    local missing = 0
    local total = 0
    local target = nil
    local targetSpell = nil

    for _, unit in ipairs(GetGroupUnits()) do
        if IsEligible(unit) then
            local _, class = UnitClass(unit)
            local blessing = self:GetAssignedBlessing(class)

            if blessing ~= "None" then
                local spell = self.blessingSpells[blessing]

                if spell and known[spell] then
                    total = total + 1

                    if not HasAssignedAura(unit, blessing) then
                        missing = missing + 1

                        if not target
                            and not UnitIsUnit(unit, "player") then
                            target = unit
                            targetSpell = spell
                        end
                    end
                end
            end
        end
    end

    return missing, total, target, targetSpell
end
