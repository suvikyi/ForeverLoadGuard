# ForeverLoadGuard

Stops the WoW: Forever Beta (`1.60.1.69913`) GPU hang on world entry:
Secondary Lighting above Fair can wedge the graphics queue
(`WaitForFence` / `GPU Hung` / Xid 109 → `ERROR #109`). The addon loads
every world at Fair, then restores your own lighting a few seconds later.
Your prefs are remembered at zone-out/logout; the disk config stays Fair.

## Install — release zip

1. Download `ForeverLoadGuard-v1.0.zip` from
   [Releases](https://github.com/suvikyi/ForeverLoadGuard/releases).
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

If the client flags it out of date, run `/dump select(4, GetBuildInfo())`
and put that number in `## Interface:` in `ForeverLoadGuard.toc`.

## Commands

`/flg status` — live vs stored settings · `/flg restore` — restore now ·
`/flg safe` — force Fair · `/flg forget` — store current settings now
