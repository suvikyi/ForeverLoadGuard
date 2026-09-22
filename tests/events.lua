-- Run from the repository root: lua5.1 tests/events.lua
-- Simulates Lua event/state behavior; does not emulate the game renderer or disk writes.
local SAFE = { graphicsLightMode = "0", raidGraphicsLightMode = "0", giQuality = "1", RAIDgiQuality = "1" }
local GOOD = { graphicsLightMode = "1", raidGraphicsLightMode = "1", giQuality = "2", RAIDgiQuality = "2" }
local HIGH = { graphicsLightMode = "2", raidGraphicsLightMode = "2", giQuality = "3", RAIDgiQuality = "3" }

local function copy(values)
    local result = {}
    for name, value in pairs(values) do result[name] = value end
    return result
end

function string:trim() return self:match("^%s*(.-)%s*$") end

local function setup(prefs, absent, startingValues, debugEnabled)
    local live, timers, frame, combat = copy(startingValues or SAFE), {}, nil, false
    local messages = {}
    if absent then live[absent] = nil end
    local env = setmetatable({
        SlashCmdList = {},
        ForeverLoadGuardDB = (prefs or debugEnabled ~= nil) and {
            prefs = prefs and copy(prefs) or nil,
            debug = debugEnabled,
        } or nil,
        print = function(message) messages[#messages + 1] = message end,
        GetCVar = function(name) return live[name] end,
        SetCVar = function(name, value)
            if name == absent then return nil end
            live[name] = value
            return true
        end,
        InCombatLockdown = function() return combat end,
        CreateFrame = function()
            frame = {
                RegisterEvent = function() end,
                SetScript = function(self, _, handler) self.handler = handler end,
            }
            return frame
        end,
        C_Timer = { NewTimer = function(delay, callback)
            assert(delay == 5, "restore delay must remain five seconds")
            local timer = { callback = callback, Cancel = function(self) self.cancelled = true end }
            timers[#timers + 1] = timer
            return timer
        end },
    }, { __index = _G })
    setfenv(assert(loadfile("ForeverLoadGuard.lua")), env)()
    local function event(name, arg) frame:handler(name, arg) end
    event("ADDON_LOADED", "ForeverLoadGuard")
    return {
        env = env, event = event, command = env.SlashCmdList.FLG,
        logs = function() return table.concat(messages, "\n") end,
        combat = function(value) combat = value end,
        set = function(values) for name, value in pairs(values) do live[name] = value end end,
        tick = function()
            local pending = timers
            timers = {}
            for _, timer in ipairs(pending) do
                if not timer.cancelled then timer.callback() end
            end
        end,
        live = function(expected)
            for name, value in pairs(expected) do
                if name ~= absent then assert(live[name] == value, "unexpected live " .. name) end
            end
        end,
        stored = function(expected)
            for name, value in pairs(expected) do
                assert(env.ForeverLoadGuardDB.prefs[name] == value, "unexpected stored " .. name)
            end
        end,
    }
end

local function login(s)
    s.event("PLAYER_LOGIN")
    s.event("PLAYER_ENTERING_WORLD")
end

local cases = {
    { "first login on Fair restores Good without manual setup", function()
        local s = setup()
        login(s); s.live(SAFE); s.stored(GOOD)
        s.tick(); s.live(GOOD)
        s.event("PLAYER_LOGOUT"); s.live(SAFE); s.stored(GOOD)
    end },
    { "early reload preserves the first-login Good default", function()
        local s = setup()
        login(s); s.event("PLAYER_LOGOUT"); s.stored(GOOD)
        local reloaded = setup(s.env.ForeverLoadGuardDB.prefs)
        login(reloaded); reloaded.live(SAFE); reloaded.tick(); reloaded.live(GOOD)
    end },
    { "explicitly saved Fair is never replaced by default Good", function()
        local s = setup(SAFE)
        login(s); s.tick(); s.live(SAFE); s.stored(SAFE)
    end },
    { "empty preferences from an earlier install use Good", function()
        local s = setup({})
        login(s); s.tick(); s.live(GOOD); s.stored(GOOD)
    end },
    { "normal login, zone and logout", function()
        local s = setup(HIGH)
        login(s); s.live(SAFE); s.tick(); s.live(HIGH)
        s.event("PLAYER_LEAVING_WORLD"); s.live(SAFE); s.stored(HIGH)
        s.event("PLAYER_ENTERING_WORLD"); s.tick(); s.live(HIGH)
        s.event("PLAYER_LOGOUT"); s.live(SAFE); s.stored(HIGH)
    end },
    { "rapid zones and early logout preserve preferences", function()
        local s = setup(HIGH)
        login(s); s.event("PLAYER_LEAVING_WORLD"); s.tick(); s.live(SAFE)
        s.event("PLAYER_ENTERING_WORLD"); s.event("PLAYER_LOGOUT"); s.tick()
        s.live(SAFE); s.stored(HIGH)
    end },
    { "combat defers restoration", function()
        local s = setup(HIGH)
        s.combat(true); login(s); s.tick(); s.live(SAFE)
        s.combat(false); s.event("PLAYER_REGEN_ENABLED"); s.tick(); s.live(HIGH)
    end },
    { "explicit safe cancels combat deferral", function()
        local s = setup(HIGH)
        s.combat(true); login(s); s.tick(); s.command("safe")
        s.combat(false); s.event("PLAYER_REGEN_ENABLED"); s.tick(); s.live(SAFE)
        s.event("PLAYER_LEAVING_WORLD"); s.event("PLAYER_LOGOUT"); s.stored(HIGH)
    end },
    { "explicit safe cancels a pending timer", function()
        local s = setup(HIGH)
        login(s); s.command("safe"); s.tick(); s.live(SAFE); s.stored(HIGH)
        s.command("restore"); s.live(HIGH)
    end },
    { "deliberate Fair preference survives zoning and logout", function()
        local s = setup(HIGH)
        login(s); s.tick(); s.set(SAFE)
        s.event("PLAYER_LEAVING_WORLD"); s.event("PLAYER_LOGOUT"); s.stored(SAFE)
        login(s); s.tick(); s.live(SAFE)
    end },
    { "deliberate Fair preference survives direct logout", function()
        local s = setup(HIGH)
        login(s); s.tick(); s.set(SAFE); s.event("PLAYER_LOGOUT"); s.stored(SAFE)
    end },
    { "normal Options changes replace Good and survive a fresh reload", function()
        local s = setup()
        login(s); s.tick(); s.set(HIGH); s.event("PLAYER_LOGOUT"); s.stored(HIGH)
        local reloaded = setup(s.env.ForeverLoadGuardDB.prefs)
        login(reloaded); reloaded.live(SAFE); reloaded.tick(); reloaded.live(HIGH)
    end },
    { "manual snapshot can remember Fair", function()
        local s = setup(HIGH)
        login(s); s.command("forget"); s.tick(); s.live(SAFE); s.stored(SAFE)
    end },
    { "unsupported CVar does not abort login", function()
        local s = setup(HIGH, "RAIDgiQuality")
        login(s); s.live(SAFE); s.tick(); s.live(HIGH)
    end },
    { "automatic diagnostics are off by default", function()
        local s = setup(GOOD)
        login(s); s.tick(); s.event("PLAYER_LEAVING_WORLD"); s.event("PLAYER_LOGOUT")
        assert(s.logs() == "", "automatic flow printed with debug off")
    end },
    { "debug toggle persists through reload and disables diagnostics again", function()
        local s = setup(GOOD)
        s.command("debug toggle"); assert(s.env.ForeverLoadGuardDB.debug == true)
        login(s); s.tick(); s.event("PLAYER_LOGOUT")
        local reloaded = setup(s.env.ForeverLoadGuardDB.prefs, nil, SAFE, s.env.ForeverLoadGuardDB.debug)
        login(reloaded); reloaded.tick()
        assert(reloaded.logs():find("restore scheduled in 5s", 1, true))
        assert(reloaded.logs():find("restored settings (enter-world)", 1, true))
        reloaded.command("debug toggle"); assert(reloaded.env.ForeverLoadGuardDB.debug == false)
        local before = reloaded.logs()
        reloaded.event("PLAYER_LEAVING_WORLD"); reloaded.event("PLAYER_ENTERING_WORLD"); reloaded.tick()
        assert(reloaded.logs() == before, "debug output continued after disabling")
    end },
}

local failures = 0
for _, case in ipairs(cases) do
    local ok, err = pcall(case[2])
    print((ok and "PASS: " or "FAIL: ") .. case[1] .. (ok and "" or ": " .. tostring(err)))
    if not ok then failures = failures + 1 end
end
assert(failures == 0, tostring(failures) .. " tests failed")
