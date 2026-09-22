# ForeverLoadGuard

An automatic workaround for the Secondary Lighting loading hang in
WoW: Forever Beta (`1.60.1.69913`).

Defaults to setting "Good" for lighting after the first login (5s timer), then tracks your preference automatically so values higher (or lower) than "Good" can be used.

## What happens automatically

1. **During loading:** the addon applies Fair at login and zone transitions.
2. **First login, with no saved preferences:** it switches to **Good** five
   seconds after entering the world. You do not need to save anything first.
3. **Later logins and zone transitions:** it restores your saved lighting after
   five seconds. Existing saved settings, including Fair, take precedence over Good.
4. **When you want different lighting:** choose it in Options after restoration.
   The addon remembers it when you next zone out, log out or `/reload`.
5. **During `/reload`:** Fair is temporary. Your saved lighting returns automatically
   five seconds after world entry; you do not need `/flg restore`.
6. **At logout:** it leaves the game config on Fair for the next loading screen,
   while keeping your preferred lighting separately for restoration.

Restoration waits until combat ends if necessary. Preferences are shared across
your account and written to disk on a normal logout or `/reload`.

## Install

1. Download [ForeverLoadGuard-v1.0.4.zip](https://github.com/suvikyi/ForeverLoadGuard/releases/download/v1.0.4/ForeverLoadGuard-v1.0.4.zip)
   from [Releases](https://github.com/suvikyi/ForeverLoadGuard/releases/latest).
2. Extract the zip and copy its `ForeverLoadGuard` folder to:
   `World of Warcraft/_classic_beta_/Interface/AddOns/`
   Replace the existing addon files if updating; saved preferences are retained.
3. Restart WoW and enable Forever Load Guard in the AddOns list.

Alternatively, clone into `AddOns`, then restart WoW and enable the addon:

```bash
cd "World of Warcraft/_classic_beta_/Interface/AddOns"
git clone https://github.com/suvikyi/ForeverLoadGuard.git
```

## Optional commands

| Command | Effect |
| --- | --- |
| `/flg status` | Show live and stored lighting settings. |
| `/flg safe` | Manually force Fair and cancel pending or combat-deferred restoration until the next world entry or `/flg restore`. Keeps stored preferences. |
| `/flg restore` | Restore stored preferences now, or defer until combat ends. |
| `/flg forget` | Replace stored preferences with the current settings. Does not delete them. |
| `/flg debug toggle` | Toggle diagnostic chat messages. Off by default; the choice persists through reloads and logins. |

To remember Fair immediately, run `/flg safe` followed by `/flg forget`.
You can also choose Fair in Options after restoration and then zone out or log out.
`/slfix` is an alias for `/flg`.

For troubleshooting, run `/flg debug toggle`, then `/reload` and wait ten seconds
out of combat. Send a screenshot of the `[LoadGuard]` chat lines; they show the
saved settings, Fair application, timer and restore result. Run the toggle again
to disable diagnostics. `/flg status` also shows the installed version and debug state.

## Compatibility

Targets Forever Beta build `1.60.1.69913`, interface `16001`
([in-game confirmation](https://github.com/Ninjaskurk/forever-mouse-tooltip#notes-on-the-interface-version)).
If a later beta marks the addon out of date, check for an updated release.
`/dump select(4, GetBuildInfo())` shows your client's interface number.

## Tests

Run `lua5.1 tests/events.lua` (or `luajit tests/events.lua`) from the repository
root. These tests simulate addon events, CVars and timers; they do not run
the game client or verify GPU behavior.
