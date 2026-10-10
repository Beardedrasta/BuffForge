-- BuffForge Config.lua | compact class-colored configuration panel
local BF = BuffForge
local panel, controls
local function ClassColor()
    local c = RAID_CLASS_COLORS[BF.class]
    if c then return c.r, c.g, c.b end
    return 0.4, 0.75, 1
end
local function Fill(parent, r, g, b, a)
    local t = parent:CreateTexture(nil, "BACKGROUND")
    t:SetAllPoints(parent)
    t:SetTexture(r, g, b, a or 1)
    return t
end
local function Text(parent, label, size, x, y, r, g, b)
    local t = parent:CreateFontString(nil, "OVERLAY")
    t:SetFont("Fonts\\FRIZQT__.TTF", size, "")
    t:SetText(label)
    t:SetTextColor(r or 0.9, g or 0.9, b or 0.95)
    t:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    return t
end
local function Button(parent, label, x, y, w, callback)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w, 30)
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    local r, g, bl = ClassColor()
    local bg = Fill(b, 0.10, 0.12, 0.16, 1)
    local t = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t:SetAllPoints(b)
    t:SetText(label)
    t:SetTextColor(r, g, bl)
    b:SetScript("OnEnter", function() bg:SetTexture(0.17, 0.19, 0.25, 1) end)
    b:SetScript("OnLeave", function() bg:SetTexture(0.10, 0.12, 0.16, 1) end)
    b:SetScript("OnClick", callback)
    return b, t
end
local function Toggle(parent, title, key, x, y)
    Text(parent, title, 12, x, y - 7)
    local b, label = Button(parent, "", x + 280, y, 90, function()
        BF.db[key] = not BF.db[key]
        BF:Refresh()
    end)
    table.insert(controls, function()
        label:SetText(BF.db[key] and "ON" or "OFF")
    end)
end
local function Slider(parent, title, key, lo, hi, step, x, y)
    Text(parent, title, 12, x, y - 4)
    local bar = CreateFrame("Slider", nil, parent)
    bar:SetOrientation("HORIZONTAL")
    bar:SetSize(175, 16)
    bar:SetPoint("TOPLEFT", parent, "TOPLEFT", x + 188, y - 2)
    bar:SetMinMaxValues(lo, hi)
    bar:SetValueStep(step)
    bar:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(bar)
    bg:SetTexture(0.12, 0.14, 0.2, 1)
    local value = Text(parent, "", 11, x + 370, y - 4)
    bar:SetScript("OnValueChanged", function(self, raw)
        if self.silent then return end
        local rounded = math.floor(raw / step + 0.5) * step
        rounded = math.max(lo, math.min(hi, rounded))
        BF.db[key] = rounded
        BF:Refresh()
    end)
    table.insert(controls, function()
        bar.silent = true
        bar:SetValue(BF.db[key])
        bar.silent = false
        value:SetText(step < 1 and string.format("%.1f", BF.db[key]) or tostring(BF.db[key]))
    end)
end
function BF:CreateConfig()
    if panel then return end
    local r, g, b = ClassColor()
    panel = CreateFrame("Frame", "BuffForgeConfig", UIParent)
    panel:SetSize(600, 600)
    panel:SetPoint("CENTER")
    panel:SetFrameStrata("DIALOG")
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function(self) self:StartMoving() end)
    panel:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    Fill(panel, 0.035, 0.045, 0.065, 0.98)
    local sidebar = CreateFrame("Frame", nil, panel)
    sidebar:SetSize(150, 600)
    sidebar:SetPoint("TOPLEFT")
    Fill(sidebar, 0.065, 0.075, 0.105, 1)
    Text(sidebar, "BUFFFORGE", 19, 16, -20, r, g, b)
    Text(sidebar, "CLASS BUFF ENGINE", 9, 16, -49, 0.6, 0.65, 0.7)
    Text(sidebar, "v0.2.0 | WOTLK", 10, 16, -568, 0.6, 0.65, 0.7)
    Button(sidebar, "Buff Bar", 10, -105, 130, function() end)
    Button(sidebar, "Reset Position", 10, -151, 130, function()
        if InCombatLockdown() then
            BF:Print("Reset after combat."); return
        end
        BF.db.x, BF.db.y = 0, -180
        BF:Refresh()
    end)
    Button(sidebar, "Close", 10, -197, 130, function() panel:Hide() end)
    Text(panel, "BUFF BAR SETTINGS", 16, 175, -20, r, g, b)
    Text(panel, "Automatically uses your class color.", 11, 175, -48, 0.65, 0.68, 0.75)
    controls = {}
    Toggle(panel, "Enable Buff Bar", "enabled", 175, -95)
    Toggle(panel, "Lock Bar Position", "locked", 175, -138)
    Toggle(panel, "Horizontal Layout", "horizontal", 175, -181)
    Toggle(panel, "Show Header", "showHeader", 175, -224)
    Toggle(panel, "Show Labels", "showLabels", 175, -267)
    Toggle(panel, "Show Time Remaining", "showTimer", 175, -310)
    Toggle(panel, "Dim Active Buffs", "showOnlyMissing", 175, -353)
    Slider(panel, "Scale", "scale", 0.6, 2, 0.1, 175, -400)
    Slider(panel, "Icon Size", "iconSize", 24, 60, 1, 175, -437)
    Toggle(panel, "Scan Party / Raid", "scanGroup", 175, -480)
    Toggle(panel, "Show Situational Buffs", "showOptional", 175, -523)

    -- Stage 4: Paladin blessing assignment page
    if BF.class == "PALADIN" then
        BF:InitializeAssignments()

        local page = CreateFrame("Frame", nil, panel)
        page:SetPoint("TOPLEFT", panel, "TOPLEFT", 160, -8)
        page:SetSize(430, 580)
        page:SetFrameLevel(panel:GetFrameLevel() + 5)

        Fill(page, 0.035, 0.045, 0.065, 1)

        Text(
            page, "BLESSING ASSIGNMENTS",
            16, 15, -12, r, g, b
        )

        Text(
            page,
            "Choose the blessing for each class.",
            11, 15, -42, 0.65, 0.68, 0.75
        )

        local rows = {}

        local function RefreshRows()
            for _, row in ipairs(rows) do
                local blessing =
                    BF:GetAssignedBlessing(row.class)

                row.value:SetText(blessing)
            end
        end

        for i, class in ipairs(BF.blessingClasses) do
            local y = -78 - (i - 1) * 43

            local color =
                RAID_CLASS_COLORS[class]

            local cr = color and color.r or 1
            local cg = color and color.g or 1
            local cb = color and color.b or 1

            local displayName =
                LOCALIZED_CLASS_NAMES_MALE[class]
                or class

            Text(
                page, displayName,
                12, 15, y - 7, cr, cg, cb
            )

            local row = { class = class }

            local _, value = Button(
                page, "", 210, y, 175,
                function()
                    local current =
                        BF:GetAssignedBlessing(class)

                    local nextIndex = 1

                    for j, name in ipairs(
                        BF.blessingNames
                    ) do
                        if name == current then
                            nextIndex =
                                j % #BF.blessingNames + 1
                            break
                        end
                    end

                    BF:SetAssignedBlessing(
                        class,
                        BF.blessingNames[nextIndex]
                    )

                    RefreshRows()
                end
            )

            row.value = value
            table.insert(rows, row)
        end

        Text(
            page,
            "Click a blessing to cycle through options.",
            10, 15, -525, 0.65, 0.68, 0.75
        )

        page:Hide()

        Button(
            sidebar, "Assignments",
            10, -243, 130,
            function()
                RefreshRows()
                page:Show()
            end
        )

        Button(
            page, "Back to Buff Bar",
            15, -548, 180,
            function()
                page:Hide()
            end
        )
    end

    panel:Hide()
end

function BF:UpdateConfig()
    if not controls then return end
    for _, refresh in ipairs(controls) do refresh() end
end

function BF:ToggleConfig()
    if not panel then return end
    if panel:IsShown() then
        panel:Hide()
    else
        self:UpdateConfig(); panel:Show()
    end
end
