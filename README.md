# ForeverLoadGuard

Stops the WoW: Forever Beta (`1.60.1.69913`) GPU hang on world entry:
Secondary Lighting above Fair can wedge the graphics queue
(`WaitForFence` / `GPU Hung` / Xid 109 → `ERROR #109`). The addon loads
every world at Fair, then restores your own lighting a few seconds later.
Your prefs are remembered at zone-out/logout; the disk config stays Fair.

## Install — release zip

1. Download [ForeverLoadGuard-v1.0.1.zip](https://github.com/suvikyi/ForeverLoadGuard/releases/download/v1.0.1/ForeverLoadGuard-v1.0.1.zip)
   from [Releases](https://github.com/suvikyi/ForeverLoadGuard/releases/latest).
2. Copy the `ForeverLoadGuard` folder from the zip to:
   `World of Warcraft/_classic_beta_/Interface/AddOns/`
3. Launch the game (or `/reload`), then run `/flg status`.

## Install — git clone

```bash
cd "World of Warcraft/_classic_beta_/Interface/AddOns"
git clone https://github.com/suvikyi/ForeverLoadGuard.git
```

Then `/reload` or relaunch, and `/flg status`.

## First run

Already on Fair just to get in? Expected. Enter the world, set your
lighting in Options, then zone out or log out once — that's when it's
remembered. From then on: Fair on every load, yours after entry.

Forever Beta build `1.60.1.69913` uses TOC interface `16001`, independently
[confirmed in-game](https://github.com/Ninjaskurk/forever-mouse-tooltip#notes-on-the-interface-version).
The executable build number (`69913`) and TOC interface number are different.
If a later client flags it out of date, run `/dump select(4, GetBuildInfo())`
and put the returned interface number in `## Interface:` in `ForeverLoadGuard.toc`.

## Commands

`/flg status` — live vs stored settings · `/flg restore` — restore now ·
`/flg safe` — force Fair · `/flg forget` — store current settings now

`/flg safe` cancels both pending and combat-deferred restores until the
next world entry (or `/flg restore`). It preserves your stored preferences.
To make Fair your remembered preference immediately, run `/flg safe` then
`/flg forget`. Choosing Fair in Options after your settings have been
restored is also remembered when you zone out or log out.

## Tests

Run `lua5.1 tests/events.lua` (or `luajit tests/events.lua`) from the repository
root. These tests simulate addon events, CVars and timers; they do not run
the game client or verify GPU behavior.
