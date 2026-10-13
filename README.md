# ☁ Catch a Cloudling

> Cute cloud creatures drift down a shared **Rainbow Stream**. Catch the ones you can afford, raise them on your floating island, and race the whole server when a **SECRET** Cloudling floats by during a Rainbow Storm.

A complete, playable Roblox game built as a **Rojo** project. The map, UI, creatures and effects are all generated in code, so you don't need to upload any meshes or images.

| | |
|---|---|
| **Genre** | Collect-and-idle tycoon with live social racing |
| **Players / server** | 8 (one floating island each) |
| **Session** | 5–60 min, offline earnings bring people back |
| **Platforms** | Mobile, tablet, PC, console (scaled UI, ProximityPrompts, gamepad keys) |
| **Monetization** | Optional passes and products only. No loot boxes and nothing is pay-to-win-only (see [docs/MONETIZATION.md](docs/MONETIZATION.md)) |

---

## Quick start (about 5 minutes)

### 1. Install Rojo
Pick one:
- **Aftman** (recommended): `aftman install` in this folder. It reads `aftman.toml` and installs Rojo 7.4.4.
- **Direct download**: https://github.com/rojo-rbx/rojo/releases. Put `rojo` on your PATH.
- **VS Code**: install the *Rojo* extension and use "Rojo: Start server".

Then install the **Rojo Studio plugin**: run `rojo plugin install`, or get it from the Creator Store.

### 2. Sync into Studio
```bash
rojo serve
```
1. Open Roblox Studio and create a new **Baseplate** place. The game removes the template Baseplate and SpawnLocation when it runs and builds its own sky map.
2. Open the **Rojo** plugin tab and click **Connect** (localhost:34872).

To build a place file without live sync:
```bash
rojo build -o CatchACloudling.rbxl
```
Then open `CatchACloudling.rbxl` in Studio.

### 3. Recommended Studio settings
- **Game Settings → Security → Enable Studio Access to API Services = ON**. Saving needs this. Without it the game still runs on temporary data and prints a warning.
- **Game Settings → Places → Max Players = 8**. There are 8 islands.
- **Workspace.StreamingEnabled**: leave it on or turn it off. The map is small and all client code waits for parts safely.

### 4. Play-test
- **Solo**: press **Play** (F5).
- **Multiplayer**: open **Test → Clients and Servers**, choose 2–3 players and click **Start**. This tests racing for Cloudlings, likes, friend boosts and announcements.
- **Shop in Studio**: while product IDs in `src/shared/Products.luau` are still `0`, buying in Studio grants the item for free. This only works in Studio. Use it to test every pass and product.

### 5. Run the logic tests (optional)
```bash
python3 tests/run_tests.py /path/to/luau     # luau CLI from github.com/luau-lang/luau/releases
```
Checks economy invariants: payback times, rarity ordering, upgrade curves, formatting and product setup.

---

## What's in the box

```
default.project.json        Rojo tree → ReplicatedStorage / ServerScriptService / StarterPlayerScripts
src/
  shared/                   → ReplicatedStorage.Shared   (pure data + helpers used by both sides)
    Config.luau               every balance knob (economy, timers, events, rate limits)
    CloudlingData.luau        22 species, 7 rarities, 4 mutations, 4 weather types
    CloudlingModel.luau       builds Cloudlings from primitive parts + their billboards
    Formulas.luau             prices, income, upgrades, rebirths, number formatting
    Products.luau             game passes & developer products (put your IDs here)
    QuestData.luau            daily quest pool, achievements, 7-day login rewards
    Remotes.luau              the 6 RemoteEvents (created by server, awaited by client)
    Signal.luau, Sounds.luau
  server/                   → ServerScriptService.Server
    Main.server.luau          bootstrap + join/leave orchestration
    Services/
      DataService             DataStore load/save, session locking, autosave, replication
      MapService              procedural world: stream, rainbow arch, 8 islands, boards, VIP lounge
      PlotService             island assignment, pedestals, income tick, collect, likes, friend boost
      StreamService           spawns Cloudlings, deterministic movement, validated catching
      WeatherService          timed weather + date-based seasonal events
      ProgressService         quests, achievements, index, login streak, offline earnings, rebirth, tutorial
      MarketService           game pass checks, ProcessReceipt (idempotent), Studio test purchases
      LeaderboardService      leaderstats + global OrderedDataStore boards
      CommunityService        cross-server "Community Goal" with milestone boosts
      ActionService           single rate-limited, type-checked client→server entry point
      AntiCheatService        movement sanity checks (rubber-band, no kicks)
  client/                   → StarterPlayerScripts.Client
    Main.client.luau          bootstrap
    Controllers/
      UI                      UI kit + global UIScale (1100×650 virtual canvas → any screen)
      State                   client mirror of server state
      HUD, ShopPanel, IndexPanel, QuestsPanel, MiscPanels (Rebirth/Settings)
      Pedestals               local prompts on YOUR pedestals (upgrade / release / unlock)
      Stream                  60 fps stream animation + catch prompts
      Effects                 weather skies, catch arcs, sparkle bursts, crowns, trails, chat tags
      Tutorial                3-step onboarding with world beam + bouncing arrow
      Notify, Sound
tests/                      economy spec + runner for the Luau CLI
docs/                       design, monetization, visuals, growth, launch & metrics
```

## Architecture rules
1. **The server is authoritative.** The client only *asks* by sending `Action { action = ... }`. The server rate-limits each request, checks its types, then re-checks ownership, distance, cost and capacity.
2. **Data flows one way.** Server state goes out as batched `StateSync` snapshots (5 Hz at most, light or full). The client never writes state.
3. **Deterministic stream.** Each Cloudling's position is `StartX + Speed × (ServerTime − SpawnTime)`. Clients animate it at 60 fps with no replication cost. The server computes the same position to validate catches.
4. **Data safety.** Saves use `UpdateAsync` with a session lock, autosave every 2 min, `BindToClose` flushing, and receipts recorded before `PurchaseGranted` is returned.

## Documentation
- [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md): market research, 5 concepts with scoring, the chosen concept, core loop, progression
- [docs/MONETIZATION.md](docs/MONETIZATION.md): every pass and product, prices, the reasoning behind each, ethics rules
- [docs/VISUAL_IDENTITY.md](docs/VISUAL_IDENTITY.md): name, logo, palette, thumbnail and icon concepts
- [docs/GROWTH.md](docs/GROWTH.md): retention systems, launch plan for 100 → 1K → 10K players, content calendar
- [docs/LAUNCH.md](docs/LAUNCH.md): testing checklist, exploit tests, performance, publishing checklist, metrics, roadmap
