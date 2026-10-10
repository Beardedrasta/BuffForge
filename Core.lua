-- BuffForge Core.lua | WotLK 3.3.5a | Lua 5.1
BuffForge = BuffForge or {}
local BF = BuffForge
BF.version = "0.4.0"
BF.class = select(2, UnitClass("player")) or "PALADIN"
local defaults = {
    enabled = true,
    locked = false,
    horizontal = true,
    scale = 1,
    iconSize = 38,
    spacing = 5,
    showHeader = true,
    showLabels = false,
    showTimer = true,
    warnSeconds = 120,
    showOnlyMissing = false,
    scanGroup = true,
    showOptional = false,
    x = 0,
    y = -180,
}
local function CopyDefaults(dst, src)
    for key, value in pairs(src) do
        if dst[key] == nil then dst[key] = value end
    end
end
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self, event, arg)
    if event == "ADDON_LOADED" and arg == "BuffForge" then
        if type(BuffForgeDB) ~= "table" then BuffForgeDB = {} end
        CopyDefaults(BuffForgeDB, defaults)
        BF.db = BuffForgeDB
    elseif event == "PLAYER_LOGIN" then
        if not BF.db then
            if type(BuffForgeDB) ~= "table" then BuffForgeDB = {} end
            CopyDefaults(BuffForgeDB, defaults)
            BF.db = BuffForgeDB
        end
        BF:CreateBar()
        BF:CreateConfig()
        BF:Refresh()
    end
end)
function BF:Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff71c9ffBuffForge|r: " .. tostring(message))
end

function BF:Refresh()
    if self.UpdateBar then self:UpdateBar() end
    if self.UpdateConfig then self:UpdateConfig() end
end

SLASH_BUFFFORGE1 = "/bf"
SLASH_BUFFFORGE2 = "/buffforge"
SlashCmdList.BUFFFORGE = function(message)
    message = string.lower(message or "")
    if message == "lock" then
        BF.db.locked = not BF.db.locked
        BF:Refresh()
        BF:Print(BF.db.locked and "Bar locked." or "Bar unlocked.")
    elseif message == "reset" then
        if InCombatLockdown() then
            BF:Print("Reset after combat."); return
        end
        BF.db.x, BF.db.y = 0, -180
        BF:Refresh()
        BF:Print("Bar position reset.")
    else
        if BF.ToggleConfig then BF:ToggleConfig() end
    end
end
