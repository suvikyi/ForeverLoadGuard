# ForeverLoadGuard

An automatic workaround for the Secondary Lighting loading hang in
WoW: Forever Beta (`1.60.1.69913`). Applies Fair at login and zone transitions,
then restores your saved lighting settings five seconds after world entry.

**No commands are required for automatic protection.** `/flg safe` is an
optional manual override.

## Install

1. Download [ForeverLoadGuard-v1.0.1.zip](https://github.com/suvikyi/ForeverLoadGuard/releases/download/v1.0.1/ForeverLoadGuard-v1.0.1.zip)
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

## Usage

- **First use:** enter the world and choose your preferred Secondary Lighting
  in Options, then zone out or log out to have it remembered. If you already
  use Fair to get into the game, keep it for that first login.
- **Normal play:** Fair is applied automatically for loading; your preferences
  return after five seconds. Restoration waits until combat ends if necessary.
- **Logout or `/reload`:** lighting is left at Fair for the next login.
  Preferences are shared across your account and saved to disk on a normal
  logout or `/reload`.

## Optional commands

| Command | Effect |
| --- | --- |
| `/flg status` | Show live and stored lighting settings. |
| `/flg safe` | Manually force Fair and cancel pending or combat-deferred restoration until the next world entry or `/flg restore`. Keeps stored preferences. |
| `/flg restore` | Restore stored preferences now, or defer until combat ends. |
| `/flg forget` | Replace stored preferences with the current settings. Does not delete them. |

To remember Fair immediately, run `/flg safe` followed by `/flg forget`.
You can also choose Fair in Options after restoration and then zone out or log out.
`/slfix` is an alias for `/flg`.

## Compatibility

Targets Forever Beta build `1.60.1.69913`, interface `16001`
([in-game confirmation](https://github.com/Ninjaskurk/forever-mouse-tooltip#notes-on-the-interface-version)).
If a later beta marks the addon out of date, check for an updated release.
`/dump select(4, GetBuildInfo())` shows your client's interface number.

## Tests

Run `lua5.1 tests/events.lua` (or `luajit tests/events.lua`) from the repository
root. These tests simulate addon events, CVars and timers; they do not run
the game client or verify GPU behavior.
