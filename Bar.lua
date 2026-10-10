-- BuffForge Bar.lua
-- Stage 5: Individual Blessings + Greater Blessings
-- World of Warcraft 3.3.5a / Lua 5.1
--
-- Left-click: regular blessing on yourself
-- Right-click: regular blessing on assigned player
-- Shift + Right-click: Greater Blessing on assigned class
--
-- Protected attributes are only modified outside combat.

local BF = BuffForge

local bar
local header
local buttons = {}
local elapsedTime = 0
local pendingRefresh = false

local SYMBOL_OF_KINGS = 17033

local PALADIN_BLESSINGS = {
    {
        label = "Kings",
        spell = "Blessing of Kings",
        greater = "Greater Blessing of Kings",
        iconID = 20217
    },
    {
        label = "Might",
        spell = "Blessing of Might",
        greater = "Greater Blessing of Might",
        iconID = 19740
    },
    {
        label = "Wisdom",
        spell = "Blessing of Wisdom",
        greater = "Greater Blessing of Wisdom",
        iconID = 19742
    },
    {
        label = "Sanctuary",
        spell = "Blessing of Sanctuary",
        greater = "Greater Blessing of Sanctuary",
        iconID = 20911
    }
}

local DEFINITIONS = {
    PALADIN = {
        {
            label = "Aura",
            spells = {
                "Devotion Aura",
                "Retribution Aura",
                "Concentration Aura",
                "Fire Resistance Aura",
                "Frost Resistance Aura",
                "Shadow Resistance Aura",
                "Crusader Aura"
            }
        },
        {
            label = "Seal",
            spells = {
                "Seal of Wisdom",
                "Seal of Light",
                "Seal of Righteousness",
                "Seal of Command",
                "Seal of Vengeance",
                "Seal of Corruption",
                "Seal of Justice"
            }
        },
        {
            label = "Righteous Fury",
            spells = { "Righteous Fury" },
            optional = true
        }
    },

    PRIEST = {
        {
            label = "Fortitude",
            spells = {
                "Power Word: Fortitude",
                "Prayer of Fortitude"
            },
            group = true
        },
        {
            label = "Spirit",
            spells = {
                "Divine Spirit",
                "Prayer of Spirit"
            },
            group = true
        },
        {
            label = "Shadow",
            spells = {
                "Shadow Protection",
                "Prayer of Shadow Protection"
            },
            group = true
        },
        {
            label = "Inner Fire",
            spells = { "Inner Fire" }
        }
    },

    MAGE = {
        {
            label = "Intellect",
            spells = {
                "Arcane Intellect",
                "Arcane Brilliance"
            },
            group = true
        },
        {
            label = "Armor",
            spells = {
                "Mage Armor",
                "Molten Armor",
                "Ice Armor",
                "Frost Armor"
            }
        }
    },

    DRUID = {
        {
            label = "Wild",
            spells = {
                "Mark of the Wild",
                "Gift of the Wild"
            },
            group = true
        },
        {
            label = "Thorns",
            spells = { "Thorns" },
            group = true,
            optional = true
        }
    },

    SHAMAN = {
        {
            label = "Shield",
            spells = {
                "Lightning Shield",
                "Water Shield",
                "Earth Shield"
            }
        }
    },

    WARRIOR = {
        {
            label = "Shout",
            spells = {
                "Battle Shout",
                "Commanding Shout"
            }
        }
    },

    DEATHKNIGHT = {
        {
            label = "Horn",
            spells = { "Horn of Winter" }
        },
        {
            label = "Presence",
            spells = {
                "Blood Presence",
                "Frost Presence",
                "Unholy Presence"
            }
        },
        {
            label = "Bone Shield",
            spells = { "Bone Shield" },
            optional = true
        }
    },

    WARLOCK = {
        {
            label = "Armor",
            spells = {
                "Demon Armor",
                "Fel Armor",
                "Demon Skin"
            }
        },
        {
            label = "Soul Link",
            spells = { "Soul Link" },
            optional = true
        }
    },

    HUNTER = {
        {
            label = "Aspect",
            spells = {
                "Aspect of the Hawk",
                "Aspect of the Dragonhawk",
                "Aspect of the Viper",
                "Aspect of the Monkey",
                "Aspect of the Cheetah",
                "Aspect of the Pack",
                "Aspect of the Beast",
                "Aspect of the Wild"
            }
        }
    },

    ROGUE = {}
}

local DEFAULT_ASSIGNMENTS = {
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

local SINGLE_TARGET = {
    ["Prayer of Fortitude"] = "Power Word: Fortitude",
    ["Prayer of Spirit"] = "Divine Spirit",
    ["Prayer of Shadow Protection"] = "Shadow Protection",
    ["Arcane Brilliance"] = "Arcane Intellect",
    ["Gift of the Wild"] = "Mark of the Wild"
}

local function ClassColor()
    local c = RAID_CLASS_COLORS[BF.class]

    if c then
        return c.r, c.g, c.b
    end

    return 0.5, 0.7, 1
end

local function GetKnownSpells()
    local known = {}

    for tab = 1, GetNumSpellTabs() do
        local _, _, offset, count = GetSpellTabInfo(tab)

        for i = offset + 1, offset + count do
            local name = GetSpellName(i, BOOKTYPE_SPELL)

            if name then
                known[name] = true
            end
        end
    end

    return known
end

local function KnowsSpell(name, known)
    if not name then
        return false
    end

    if known[name] then
        return true
    end

    local resolved = GetSpellInfo(name)

    return resolved ~= nil and known[resolved] == true
end

local function HasAura(unit, names)
    for i = 1, 40 do
        local name, _, _, _, _, duration, expiration =
            UnitBuff(unit, i)

        if not name then
            break
        end

        for _, wanted in ipairs(names) do
            if name == wanted then
                return true, duration or 0, expiration or 0
            end
        end
    end

    return false, 0, 0
end

local function GetUnits()
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
    else
        table.insert(units, "player")
    end

    return units
end

local function ValidUnit(unit)
    return UnitExists(unit)
        and UnitIsConnected(unit)
        and not UnitIsDeadOrGhost(unit)
        and UnitIsFriend("player", unit)
end

local function GetAssignment(class)
    if BF.GetAssignedBlessing then
        return BF:GetAssignedBlessing(class)
    end

    if BF.db
        and type(BF.db.blessingAssignments) == "table"
        and BF.db.blessingAssignments[class] then
        return BF.db.blessingAssignments[class]
    end

    return DEFAULT_ASSIGNMENTS[class] or "None"
end

local function BuildEntries()
    local entries = {}
    local known = GetKnownSpells()
    local preferences = BF.db.preferences or {}

    if BF.class == "PALADIN" then
        for _, blessing in ipairs(PALADIN_BLESSINGS) do
            local regularKnown =
                KnowsSpell(blessing.spell, known)

            local greaterKnown =
                KnowsSpell(blessing.greater, known)

            if regularKnown or greaterKnown then
                table.insert(entries, {
                    label = blessing.label,
                    spell = regularKnown
                        and blessing.spell
                        or blessing.greater,
                    regular = blessing.spell,
                    greater = blessing.greater,
                    regularKnown = regularKnown,
                    greaterKnown = greaterKnown,
                    choices = {
                        blessing.spell,
                        blessing.greater
                    },
                    blessing = blessing.label,
                    group = true,
                    iconID = blessing.iconID
                })
            end
        end
    end

    for _, def in ipairs(DEFINITIONS[BF.class] or {}) do
        if not def.optional or BF.db.showOptional then
            local selected = nil

            for _, spell in ipairs(def.spells) do
                if KnowsSpell(spell, known) then
                    selected = spell
                    break
                end
            end

            local preferred = preferences[def.label]

            if preferred and KnowsSpell(preferred, known) then
                for _, spell in ipairs(def.spells) do
                    if spell == preferred then
                        selected = preferred
                        break
                    end
                end
            end

            if selected then
                table.insert(entries, {
                    label = def.label,
                    spell = selected,
                    choices = def.spells,
                    group = def.group or false
                })
            end
        end
    end

    return entries
end

local function GetGroupStatus(entry)
    local missing = 0
    local total = 0
    local target = nil
    local names = {}
    local classes = {}

    for _, unit in ipairs(GetUnits()) do
        if ValidUnit(unit) then
            local _, class = UnitClass(unit)
            local eligible = true

            if entry.blessing then
                eligible =
                    GetAssignment(class) == entry.blessing
            end

            if eligible then
                total = total + 1

                local active =
                    HasAura(unit, entry.choices)

                if not active then
                    missing = missing + 1

                    table.insert(
                        names,
                        UnitName(unit) or unit
                    )

                    if not target
                        and not UnitIsUnit(unit, "player") then
                        target = unit
                    end

                    if entry.blessing and class then
                        if not classes[class] then
                            classes[class] = {
                                count = 0,
                                unit = nil
                            }
                        end

                        classes[class].count =
                            classes[class].count + 1

                        if not classes[class].unit then
                            classes[class].unit = unit
                        end
                    end
                end
            end
        end
    end

    return missing, total, target, names, classes
end

local function GetGreaterTarget(classes)
    local bestUnit = nil
    local bestClass = nil
    local bestCount = 0

    for class, info in pairs(classes) do
        if info.count > bestCount then
            bestCount = info.count
            bestClass = class
            bestUnit = info.unit
        end
    end

    return bestUnit, bestClass, bestCount
end

local function GetGroupCastSpell(entry, known)
    if entry.blessing then
        if entry.regularKnown then
            return entry.regular
        end

        return nil
    end

    local single = SINGLE_TARGET[entry.spell]

    if single then
        if KnowsSpell(single, known) then
            return single
        end

        return nil
    end

    return entry.spell
end

local function GetSymbolCount()
    return GetItemCount(SYMBOL_OF_KINGS) or 0
end

local function ClearPreparedActions(button)
    button.groupUnit = nil
    button.groupName = nil
    button.groupSpell = nil

    button.greaterUnit = nil
    button.greaterName = nil
    button.greaterClass = nil
    button.greaterCount = 0

    button:SetAttribute("type2", nil)
    button:SetAttribute("spell2", nil)
    button:SetAttribute("unit2", nil)

    -- Explicitly suppress shift-right casting when
    -- no valid Greater Blessing is prepared.
    button:SetAttribute("shift-type2", "macro")
    button:SetAttribute("shift-macrotext2", "/stopmacro")
    button:SetAttribute("shift-spell2", nil)
    button:SetAttribute("shift-unit2", nil)
end

local function PrepareTarget(button, known)
    if InCombatLockdown() then
        pendingRefresh = true
        return
    end

    local entry = button.entry

    ClearPreparedActions(button)

    if not entry
        or not entry.group
        or not BF.db.scanGroup then
        return
    end

    local missing, total, target, _, classes =
        GetGroupStatus(entry)

    button.groupMissing = missing
    button.groupTotal = total

    -- Existing right-click: regular single-target buff.
    if target then
        local spell = GetGroupCastSpell(entry, known)

        if spell then
            button.groupUnit = target
            button.groupName = UnitName(target)
            button.groupSpell = spell

            button:SetAttribute("type2", "spell")
            button:SetAttribute("spell2", spell)
            button:SetAttribute("unit2", target)
        end
    end

    -- New shift-right-click: Greater Blessing.
    if entry.blessing
        and entry.greaterKnown
        and GetSymbolCount() > 0 then
        local greaterUnit, greaterClass, count =
            GetGreaterTarget(classes)

        if greaterUnit then
            button.greaterUnit = greaterUnit
            button.greaterName = UnitName(greaterUnit)
            button.greaterClass = greaterClass
            button.greaterCount = count

            button:SetAttribute(
                "shift-type2", "spell"
            )
            button:SetAttribute(
                "shift-spell2", entry.greater
            )
            button:SetAttribute(
                "shift-unit2", greaterUnit
            )
        end
    end
end

local function PrepareAllTargets()
    if InCombatLockdown() then
        pendingRefresh = true
        return
    end

    local known = GetKnownSpells()

    for _, button in ipairs(buttons) do
        if button.entry then
            PrepareTarget(button, known)
        end
    end
end

local function MakeButton(index)
    local button = CreateFrame(
        "Button",
        "BuffForgeBuff" .. index,
        bar,
        "SecureActionButtonTemplate"
    )

    button:RegisterForClicks(
        "LeftButtonUp",
        "RightButtonUp"
    )

    button:SetAttribute("type1", "spell")
    button:SetAttribute("unit1", "player")

    button.bg = button:CreateTexture(
        nil, "BACKGROUND"
    )
    button.bg:SetAllPoints(button)
    button.bg:SetTexture(0.10, 0.12, 0.16, 1)

    button.icon = button:CreateTexture(
        nil, "ARTWORK"
    )
    button.icon:SetPoint(
        "TOPLEFT", button, "TOPLEFT", 3, -3
    )
    button.icon:SetPoint(
        "BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3
    )

    button.status = button:CreateTexture(
        nil, "OVERLAY"
    )
    button.status:SetHeight(3)
    button.status:SetPoint(
        "BOTTOMLEFT", button, "BOTTOMLEFT", 2, 2
    )
    button.status:SetPoint(
        "BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2
    )

    button.time = button:CreateFontString(
        nil, "OVERLAY", "GameFontHighlightSmall"
    )
    button.time:SetPoint(
        "BOTTOM", button, "BOTTOM", 0, 5
    )

    button.label = button:CreateFontString(
        nil, "OVERLAY", "GameFontHighlightSmall"
    )
    button.label:SetPoint(
        "TOP", button, "BOTTOM", 0, -3
    )
    button.label:SetWidth(90)
    button.label:SetJustifyH("CENTER")

    button.greaterMark = button:CreateFontString(
        nil, "OVERLAY", "GameFontNormalSmall"
    )
    button.greaterMark:SetPoint(
        "TOPRIGHT", button, "TOPRIGHT", -3, -2
    )
    button.greaterMark:SetText("G")
    button.greaterMark:SetTextColor(1, 0.85, 0.25)
    button.greaterMark:Hide()

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

        local entry = self.entry

        if not entry then
            GameTooltip:SetText("BuffForge")
            GameTooltip:Show()
            return
        end

        GameTooltip:SetText(entry.label)

        GameTooltip:AddLine(
            "Left-click: " .. entry.spell
            .. " on yourself",
            0.75, 0.85, 1
        )

        if entry.group and BF.db.scanGroup then
            local missing, total, _, names =
                GetGroupStatus(entry)

            GameTooltip:AddLine(" ")

            GameTooltip:AddLine(
                missing .. " of " .. total .. " missing",
                1, 0.72, 0.25
            )

            for i = 1, math.min(#names, 10) do
                GameTooltip:AddLine(
                    names[i], 1, 0.55, 0.55
                )
            end

            if self.groupUnit then
                GameTooltip:AddLine(" ")

                GameTooltip:AddLine(
                    "Right-click: "
                    .. self.groupSpell
                    .. " on "
                    .. (self.groupName or "player"),
                    0.35, 1, 0.6
                )
            else
                GameTooltip:AddLine(
                    "No regular group target prepared",
                    0.65, 0.65, 0.7
                )
            end
        end

        if entry.blessing then
            GameTooltip:AddLine(" ")

            if not entry.greaterKnown then
                GameTooltip:AddLine(
                    "Greater Blessing not learned",
                    0.65, 0.65, 0.7
                )
            else
                local symbols = GetSymbolCount()

                GameTooltip:AddLine(
                    "Symbol of Kings: " .. symbols,
                    1, 0.85, 0.3
                )

                if self.greaterUnit then
                    local className =
                        LOCALIZED_CLASS_NAMES_MALE
                        and LOCALIZED_CLASS_NAMES_MALE[
                        self.greaterClass
                        ]

                    GameTooltip:AddLine(
                        "Shift + Right-click: "
                        .. entry.greater,
                        0.4, 0.9, 1
                    )

                    GameTooltip:AddLine(
                        "Target: "
                        .. (self.greaterName or "player")
                        .. " ("
                        .. (className
                            or self.greaterClass
                            or "Unknown")
                        .. ")",
                        0.75, 0.85, 1
                    )

                    GameTooltip:AddLine(
                        "Missing in class: "
                        .. (self.greaterCount or 0),
                        1, 0.72, 0.25
                    )
                else
                    GameTooltip:AddLine(
                        "No Greater Blessing target prepared",
                        0.65, 0.65, 0.7
                    )
                end
            end
        end

        if InCombatLockdown() then
            GameTooltip:AddLine(" ")

            GameTooltip:AddLine(
                "Prepared targets locked during combat",
                1, 0.45, 0.35
            )
        end

        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return button
end

local function SetPosition()
    bar:ClearAllPoints()

    bar:SetPoint(
        "CENTER",
        UIParent,
        "CENTER",
        BF.db.x or 0,
        BF.db.y or -180
    )
end

local function SavePosition()
    local cx, cy = bar:GetCenter()
    local ux, uy = UIParent:GetCenter()

    if cx and ux then
        local scale =
            bar:GetEffectiveScale()
            / UIParent:GetEffectiveScale()

        BF.db.x = (cx - ux) * scale
        BF.db.y = (cy - uy) * scale
    end
end

function BF:CreateBar()
    if bar then
        return
    end

    bar = CreateFrame(
        "Frame", "BuffForgeBar", UIParent
    )

    bar:SetFrameStrata("MEDIUM")
    bar:SetMovable(true)
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetClampedToScreen(true)

    bar:SetScript("OnDragStart", function(self)
        if not BF.db.locked
            and not InCombatLockdown() then
            self:StartMoving()
        end
    end)

    bar:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition()
    end)

    local background =
        bar:CreateTexture(nil, "BACKGROUND")

    background:SetAllPoints(bar)
    background:SetTexture(
        0.045, 0.055, 0.075, 0.93
    )

    local accent =
        bar:CreateTexture(nil, "BORDER")

    accent:SetHeight(2)
    accent:SetPoint(
        "TOPLEFT", bar, "TOPLEFT", 0, 0
    )
    accent:SetPoint(
        "TOPRIGHT", bar, "TOPRIGHT", 0, 0
    )

    local r, g, b = ClassColor()
    accent:SetTexture(r, g, b, 1)

    header = bar:CreateFontString(
        nil, "OVERLAY", "GameFontNormalSmall"
    )

    header:SetText("BUFFFORGE  |  " .. BF.class)
    header:SetTextColor(r, g, b)
    header:SetPoint(
        "TOPLEFT", bar, "TOPLEFT", 8, -7
    )

    SetPosition()

    local events = CreateFrame("Frame")

    local eventNames = {
        "UNIT_AURA",
        "SPELLS_CHANGED",
        "PLAYER_ENTERING_WORLD",
        "PLAYER_REGEN_ENABLED",
        "PARTY_MEMBERS_CHANGED",
        "RAID_ROSTER_UPDATE",
        "UNIT_CONNECTION",
        "UNIT_FLAGS",
        "BAG_UPDATE"
    }

    for _, event in ipairs(eventNames) do
        events:RegisterEvent(event)
    end

    events:SetScript("OnEvent", function(
        self, event, unit
    )
        if event == "UNIT_AURA" then
            if unit == "player"
                or (
                    unit
                    and (
                        string.sub(unit, 1, 5) == "party"
                        or string.sub(unit, 1, 4) == "raid"
                    )
                ) then
                BF:UpdateIndicators()

                if not InCombatLockdown() then
                    PrepareAllTargets()
                else
                    pendingRefresh = true
                end
            end

            return
        end

        if InCombatLockdown() then
            pendingRefresh = true
            BF:UpdateIndicators()
            return
        end

        if event == "BAG_UPDATE" then
            PrepareAllTargets()
            return
        end

        pendingRefresh = false
        BF:UpdateBar()
    end)

    bar:SetScript("OnUpdate", function(self, elapsed)
        elapsedTime = elapsedTime + elapsed

        if elapsedTime >= 1 then
            elapsedTime = 0

            BF:UpdateIndicators()

            if pendingRefresh
                and not InCombatLockdown() then
                pendingRefresh = false
                PrepareAllTargets()
            end
        end
    end)
end

function BF:UpdateIndicators()
    if not bar or not self.db then
        return
    end

    local now = GetTime()

    for _, button in ipairs(buttons) do
        local entry = button.entry

        if entry and button:IsShown() then
            local active, duration, expiration =
                HasAura("player", entry.choices)

            local remaining = expiration - now

            if entry.blessing then
                local missing, total =
                    GetGroupStatus(entry)

                button.groupMissing = missing
                button.groupTotal = total
                button.time:SetText(tostring(missing))

                if total == 0 then
                    button.status:SetTexture(
                        0.4, 0.45, 0.55, 1
                    )
                    button.icon:SetDesaturated(false)
                elseif missing == 0 then
                    button.status:SetTexture(
                        0.2, 0.9, 0.55, 1
                    )
                    button.icon:SetDesaturated(false)
                elseif missing < total then
                    button.status:SetTexture(
                        1, 0.65, 0.15, 1
                    )
                    button.icon:SetDesaturated(false)
                else
                    button.status:SetTexture(
                        1, 0.25, 0.3, 1
                    )
                    button.icon:SetDesaturated(true)
                end

                button:SetAlpha(1)

                if button.greaterUnit then
                    button.greaterMark:Show()
                else
                    button.greaterMark:Hide()
                end
            else
                button.greaterMark:Hide()

                if active then
                    if expiration > 0
                        and remaining <=
                        (self.db.warnSeconds or 120) then
                        button.status:SetTexture(
                            1, 0.65, 0.15, 1
                        )
                    else
                        button.status:SetTexture(
                            0.2, 0.9, 0.55, 1
                        )
                    end

                    button.icon:SetDesaturated(false)

                    if self.db.showTimer
                        and expiration > 0 then
                        if remaining >= 60 then
                            button.time:SetText(
                                math.ceil(remaining / 60)
                                .. "m"
                            )
                        else
                            button.time:SetText(
                                math.max(
                                    0, math.ceil(remaining)
                                ) .. "s"
                            )
                        end
                    else
                        button.time:SetText("")
                    end
                else
                    button.status:SetTexture(
                        1, 0.25, 0.3, 1
                    )
                    button.icon:SetDesaturated(true)
                    button.time:SetText("!")
                end

                if self.db.showOnlyMissing and active then
                    button:SetAlpha(0.25)
                else
                    button:SetAlpha(1)
                end
            end
        end
    end
end

function BF:UpdateBar()
    if not bar or not self.db then
        return
    end

    if InCombatLockdown() then
        pendingRefresh = true
        self:UpdateIndicators()
        return
    end

    bar:SetScale(self.db.scale or 1)
    SetPosition()

    local entries = BuildEntries()

    local count = math.max(1, #entries)
    local size = self.db.iconSize or 38
    local spacing = self.db.spacing or 5

    local headerHeight =
        self.db.showHeader and 25 or 8

    local labelsHeight =
        self.db.showLabels and 19 or 0

    local horizontal = self.db.horizontal

    local width
    local height

    if horizontal then
        width =
            count * size
            + (count - 1) * spacing
            + 14

        height =
            size + headerHeight
            + labelsHeight + 8
    else
        width = size + 14

        height =
            count * size
            + (count - 1) * spacing
            + headerHeight
            + labelsHeight + 8
    end

    bar:SetSize(width, height)

    if self.db.enabled then
        bar:Show()
    else
        bar:Hide()
    end

    if self.db.showHeader then
        header:Show()
    else
        header:Hide()
    end

    for i = 1, math.max(#entries, #buttons) do
        local button = buttons[i]

        if not button and i <= #entries then
            button = MakeButton(i)
            buttons[i] = button
        end

        if button then
            local entry = entries[i]
            button.entry = entry

            if entry then
                button:SetAttribute("type1", "spell")
                button:SetAttribute("spell1", entry.spell)
                button:SetAttribute("unit1", "player")

                local icon

                if entry.iconID then
                    icon = select(
                        3, GetSpellInfo(entry.iconID)
                    )
                end

                if not icon then
                    icon = select(
                        3, GetSpellInfo(entry.spell)
                    )
                end

                button.icon:SetTexture(
                    icon
                    or "Interface\\Icons\\INV_Misc_QuestionMark"
                )

                button.label:SetText(entry.label)

                if self.db.showLabels then
                    button.label:Show()
                else
                    button.label:Hide()
                end

                button:SetSize(size, size)
                button:ClearAllPoints()

                local x
                local y

                if horizontal then
                    x = 7 + (i - 1) * (size + spacing)
                    y = -headerHeight
                else
                    x = 7
                    y = -headerHeight
                        - (i - 1) * (size + spacing)
                end

                button:SetPoint(
                    "TOPLEFT", bar, "TOPLEFT", x, y
                )

                button:Show()
            else
                button:Hide()
                button.greaterMark:Hide()

                button:SetAttribute("type1", nil)
                button:SetAttribute("spell1", nil)
                ClearPreparedActions(button)
            end
        end
    end

    PrepareAllTargets()
    self:UpdateIndicators()
end
