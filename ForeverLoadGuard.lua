-- ForeverLoadGuard 1.0.1 — Forever Beta cold-load guard.
--
-- The Forever Beta (1.60.1.69913) can hang the GPU while constructing the
-- first world frame when Secondary Lighting is above Fair, wedging the
-- graphics queue (WaitForFence / GPU Hung / Xid 109) until WoW's watchdog
-- reports ERROR #109. Same class of failure occurs on some zone transitions.
--
-- Design: your real prefs live in ForeverLoadGuardDB (disk, per account).
-- They are captured from whatever is live at zone-out/logout (i.e. what you
-- actually play with), never at first install — most people install this
-- while already on Fair just to get in, and snapshotting that would
-- memorize the workaround as the preference.
-- The on-disk Config.wtf is always left at Fair so the next cold load is
-- safe; your prefs are restored live a few seconds after each world load.
-- Fair == graphicsLightMode 0 / giQuality 1. Never giQuality 0: that asserts
-- ("GI cascade scale ratio must be an even integer", WorldGlobalIllumination.cpp).

local CVARS = {
    "graphicsLightMode",
    "raidGraphicsLightMode",
    "giQuality",
    "RAIDgiQuality",
}

-- Safe (Fair) values, per community A/B on builds 69893/69913.
local SAFE = {
    graphicsLightMode = "0",
    raidGraphicsLightMode = "0",
    giQuality = "1",
    RAIDgiQuality = "1",
}

local RESTORE_DELAY = 5            -- s after entering world before restoring prefs
local LOWER_ON_ZONE_CHANGE = true  -- also drop to Fair on every loading screen

local PREFIX = "|cffffff00[LoadGuard]|r "

local function GetLive()
    local t = {}
    for _, name in ipairs(CVARS) do
        t[name] = GetCVar(name) -- nil if the CVar doesn't exist; skipped on apply
    end
    return t
end

local function IsSafe(values)
    for _, name in ipairs(CVARS) do
        if values[name] ~= nil and values[name] ~= SAFE[name] then
            return false
        end
    end
    return true
end

local function SameAsLive(values)
    for _, name in ipairs(CVARS) do
        if values[name] ~= nil and GetCVar(name) ~= values[name] then
            return false
        end
    end
    return true
end

local function Apply(values)
    for _, name in ipairs(CVARS) do
        if values[name] ~= nil then
            SetCVar(name, values[name])
        end
    end
end

local function Describe(values)
    local parts = {}
    for _, name in ipairs(CVARS) do
        parts[#parts + 1] = name .. "=" .. tostring(values[name])
    end
    return table.concat(parts, " ")
end

local f = CreateFrame("Frame")
f.restoreTimer = nil
f.deferredRestore = false
f.safeApplied = false

function f:CancelPendingRestore()
    self.deferredRestore = false
    if self.restoreTimer then
        self.restoreTimer:Cancel()
        self.restoreTimer = nil
    end
end

function f:CapturePrefs()
    local live = GetLive()
    -- Only ignore Fair when we applied it temporarily. Fair chosen after
    -- restoring the user's settings is a real preference too.
    if not self.safeApplied or not IsSafe(live) then
        ForeverLoadGuardDB.prefs = live
    end
end

function f:ApplySafe()
    self:CancelPendingRestore()
    self.safeApplied = true
    Apply(SAFE)
end

function f:RestorePrefs(reason)
    self.deferredRestore = false
    local prefs = ForeverLoadGuardDB and ForeverLoadGuardDB.prefs
    if not prefs then return end
    if SameAsLive(prefs) then
        self.safeApplied = false
        return -- already there (or user runs Fair); no churn
    end
    if InCombatLockdown() then
        self.deferredRestore = true
        print(PREFIX .. "in combat, restore deferred (" .. tostring(reason) .. ")")
        return
    end
    Apply(prefs)
    self.safeApplied = false
    if reason ~= "enter-world" then
        print(PREFIX .. "restored your settings (" .. tostring(reason) .. "): " .. Describe(prefs))
    end
end

function f:ScheduleRestore(reason)
    self:CancelPendingRestore()
    self.restoreTimer = C_Timer.NewTimer(RESTORE_DELAY, function()
        self.restoreTimer = nil
        self:RestorePrefs(reason)
    end)
end

f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_LEAVING_WORLD")
f:RegisterEvent("PLAYER_LOGOUT")
f:RegisterEvent("PLAYER_REGEN_ENABLED")

f:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "ForeverLoadGuard" then
        ForeverLoadGuardDB = ForeverLoadGuardDB or {}
        if not ForeverLoadGuardDB.prefs then
            -- No snapshot here on purpose: most people install this while
            -- already on Fair (the only way to get in at all), so the live
            -- values are the workaround, not the preference. Real prefs are
            -- captured at zone-out/logout below, once live != Fair.
            print(PREFIX .. "no stored settings yet. Set your desired lighting in Options while in-world; I will remember it when you zone out or log out.")
        end
    elseif event == "PLAYER_LOGIN" then
        self:ApplySafe()
    elseif event == "PLAYER_ENTERING_WORLD" then
        self:ScheduleRestore("enter-world")
    elseif event == "PLAYER_LEAVING_WORLD" then
        self:CapturePrefs()
        if LOWER_ON_ZONE_CHANGE then
            self:ApplySafe()
        end
    elseif event == "PLAYER_LOGOUT" then
        -- Preserve user changes without capturing our temporary Fair values,
        -- then leave the on-disk config safe for the next cold load.
        self:CapturePrefs()
        self:ApplySafe()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if self.deferredRestore then
            self:ScheduleRestore("left-combat")
        end
    end
end)

SLASH_FLG1 = "/flg"
SLASH_FLG2 = "/slfix"
SlashCmdList.FLG = function(msg)
    msg = (msg or ""):lower():trim()
    if msg == "status" then
        local prefs = ForeverLoadGuardDB and ForeverLoadGuardDB.prefs
        print(PREFIX .. "live:   " .. Describe(GetLive()))
        print(PREFIX .. "stored: " .. (prefs and Describe(prefs) or "<none>"))
    elseif msg == "restore" then
        f:CancelPendingRestore()
        f:RestorePrefs("manual")
    elseif msg == "safe" then
        f:ApplySafe()
        print(PREFIX .. "forced safe (Fair).")
    elseif msg == "forget" then
        ForeverLoadGuardDB.prefs = GetLive()
        f.safeApplied = false
        print(PREFIX .. "re-stored current settings: " .. Describe(ForeverLoadGuardDB.prefs))
    else
        print(PREFIX .. "usage: /flg status|restore|safe|forget")
    end
end
