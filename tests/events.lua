-- Run from the repository root: lua5.1 tests/events.lua
-- Simulates Lua event/state behavior; does not emulate the game renderer or disk writes.
local SAFE = { graphicsLightMode = "0", raidGraphicsLightMode = "0", giQuality = "1", RAIDgiQuality = "1" }
local HIGH = { graphicsLightMode = "2", raidGraphicsLightMode = "2", giQuality = "3", RAIDgiQuality = "3" }

local function copy(values)
    local result = {}
    for name, value in pairs(values) do result[name] = value end
    return result
end

function string:trim() return self:match("^%s*(.-)%s*$") end

local function setup(prefs, absent, startingValues)
    local live, timers, frame, combat = copy(startingValues or SAFE), {}, nil, false
    local messages = {}
    if absent then live[absent] = nil end
    local env = setmetatable({
        SlashCmdList = {},
        ForeverLoadGuardDB = prefs and { prefs = copy(prefs) } or nil,
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
    { "first install remembers existing higher lighting before forcing Fair", function()
        local s = setup(nil, nil, HIGH)
        s.stored(HIGH)
        login(s); s.live(SAFE); s.stored(HIGH)
        s.tick(); s.live(HIGH)
        assert(s.logs():find("restored settings %(enter%-world%)"), "missing restore confirmation")
        s.event("PLAYER_LOGOUT"); s.live(SAFE); s.stored(HIGH)
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
    { "first install waits for user preferences", function()
        local s = setup()
        login(s); s.tick(); s.event("PLAYER_LEAVING_WORLD"); s.event("PLAYER_LOGOUT")
        assert(s.env.ForeverLoadGuardDB.prefs == nil)
        assert(s.logs():find("restore skipped %(enter%-world%): no stored settings yet"), "missing no-prefs diagnostic")
        login(s); s.tick(); s.set(HIGH); s.event("PLAYER_LEAVING_WORLD"); s.stored(HIGH)
        s.event("PLAYER_LOGOUT"); s.stored(HIGH)
    end },
    { "manual snapshot can remember Fair", function()
        local s = setup(HIGH)
        login(s); s.command("forget"); s.tick(); s.live(SAFE); s.stored(SAFE)
    end },
    { "unsupported CVar does not abort login", function()
        local s = setup(HIGH, "RAIDgiQuality")
        login(s); s.live(SAFE); s.tick(); s.live(HIGH)
    end },
}

local failures = 0
for _, case in ipairs(cases) do
    local ok, err = pcall(case[2])
    print((ok and "PASS: " or "FAIL: ") .. case[1] .. (ok and "" or ": " .. tostring(err)))
    if not ok then failures = failures + 1 end
end
assert(failures == 0, tostring(failures) .. " tests failed")
