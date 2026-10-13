# Testing, Launch & Metrics

## 1. MVP scope (done)
Everything below is implemented and syncs through Rojo:
- [x] Procedural sky world: stream, rainbow arch, 8 islands, bridges, boards, VIP lounge, cloud sea safety net
- [x] Catch → earn → collect → upgrade → unlock pedestals → rebirth
- [x] 22 species, 7 rarities, 4 mutations, 4 weather types, 2 seasonal events
- [x] DataStore saving with session locks, autosave, BindToClose, offline earnings
- [x] Quests, achievements, Index, login streak, tutorial
- [x] Leaderstats + 3 global boards + Community Goal
- [x] Shop with 6 passes and 6 products, idempotent receipts, Studio test purchases
- [x] Mobile-scaled UI, prompts with keyboard/touch/gamepad, effects, sounds

## 2. Functional test checklist (Studio)
Run **Test → Clients and Servers with 3 players** unless noted.

**Onboarding**
- [ ] New player spawns on an island; the sign shows "<Name>'s Island"
- [ ] Tutorial step 0 beam points at an affordable Cloudling upstream
- [ ] Catch → Cloudling arcs to pedestal 1 → step 1 text → beam to Collect Pad
- [ ] Collect → counter animates, sparkles fly to HUD → step 2 → upgrade → step 3 → auto-hides
- [ ] "Skip" and Settings → "Skip / End Tutorial" both end it

**Economy**
- [ ] Can't catch when broke (red toast shows how much is missing)
- [ ] Can't catch with a full island (toast)
- [ ] Two players trigger the same Cloudling: exactly one gets it; the other sees "Too slow"
- [ ] Upgrade cost is deducted, level label updates, LEVEL UP effect plays
- [ ] Release (hold F) refunds 50% of spent + stored Sparkles
- [ ] Next locked pedestal shows its unlock cost; unlocking makes the following one "Next"
- [ ] Rebirth requires the cost, asks for confirmation, resets Sparkles/Cloudlings, keeps pedestals/Index
- [ ] Income chip shows the multiplied rate; leaderstats update

**Persistence** (Studio API access ON)
- [ ] Leave and rejoin: Sparkles, Cloudlings (with levels and stored), Index, quests and streak all persist
- [ ] Rejoin after more than 1 min: offline earnings toast
- [ ] Stop the server while a player is in: data is saved (BindToClose)

**Events & social**
- [ ] Weather starts within 1–2 min; HUD chip countdown; sky/particles change; it ends cleanly
- [ ] Rainbow Storm visibly raises Rainbow spawns
- [ ] Like another island: owner and liker both get toasts; can't like twice; own like prompt hidden
- [ ] Two friend accounts: Friend Boost chip appears (requires real friends in a live server)
- [ ] Falling off an island bounces you home (no death)

**Shop** (IDs = 0 → Studio grants)
- [ ] Each pass grants its effect: 2x income, auto-collect, +4 pedestals, VIP crown/tag/lounge, trail, speed
- [ ] Each product: Sparkle amount matches the card; boost chip timer; summons announce your name
- [ ] Owned passes show "OWNED ✓"

**UI / devices** (Studio → Device emulator)
- [ ] iPhone SE / small Android: nothing overlaps the thumbstick/jump; panels fit; text readable
- [ ] iPad, 1080p, 4K TV: UI scales; gamepad can trigger prompts (ButtonX/ButtonY)

## 3. Exploit test procedures
Use a test account with a script executor **only in your own private test place**, or simulate with the Studio command bar (`game.ReplicatedStorage.Remotes.Action:FireServer(...)` from a client context).

| Attack | Test | Expected |
|---|---|---|
| Remote spam | Fire `Action` 1000× in a loop | Token bucket drops excess (8/s, burst 12); server stays healthy |
| Bad types | `{action="Upgrade", slot="1"}`, `slot=1.5`, `slot=-1`, `slot=1e9`, NaN | Ignored silently |
| Catch from afar | `{action="Catch", id=<id>}` from your island | "Get closer" (server computes true position, 24-stud limit) |
| Catch a gone Cloudling | Reuse an old id | "Too slow" toast, no charge |
| Upgrade others' pedestals | `{action="Upgrade", slot=n}` while standing on someone else's island | Rejected (server only reads *your* data and *your* pedestal position) |
| Negative / huge money | No remote accepts amounts | N/A by design |
| Speed / teleport hack | Set WalkSpeed 200 or CFrame-teleport | Rubber-banded after 3 strikes; logged in output |
| Receipt replay | Grant the same PurchaseId twice | Second returns PurchaseGranted with no extra grant |
| Studio test purchase on live | `{action="TestPurchase"}` on a live server | Rejected (`RunService:IsStudio()` check) |
| Data dup via server hop | Join server A, quickly join server B | B waits for A's session lock (up to ~30 s), then loads the latest save |

## 4. Performance recommendations
- The stream is animated client-side, so there's **no per-frame replication**. The server moves nothing.
- At most 24 stream Cloudlings and 20 per island (about 160 owned models in a full server); each is about 15 parts. Watch **MicroProfiler** for `RenderStepped` cost on low-end phones.
- Optional: lower `Config.StreamMaxActive` to 18 and use simpler Cloudlings (skip features) if mobile FPS drops below 45.
- Billboards use `MaxDistance` (45–90 studs). Raise or lower it to trade clarity against cost.
- Decorative clouds are anchored with `CanQuery/CanCollide = false`. Consider merging them into MeshParts after launch for fewer draw calls.
- DataStore budget: autosave staggered every 2 min, leaderboards every 3 min, community every 2 min. This is well under limits for 8 players.

## 5. Roblox publishing checklist
- [ ] File → Publish to Roblox; name **Catch a Cloudling**
- [ ] Game Settings: Max players **8**; Genre **Simulation**; all devices enabled; **Enable Studio Access to API Services**
- [ ] Create the 6 passes and 6 products, paste their IDs into `Products.luau`, then re-sync and publish
- [ ] Icon (512×512) and 2–3 thumbnails (1920×1080) uploaded
- [ ] Description with hook, features, update log and "All purchases optional"
- [ ] Complete the **Experience Questionnaire** (maturity and content)
- [ ] Turn on **private servers** (free at launch)
- [ ] Add music: Creator Store → Audio (Roblox-licensed tracks) → paste the ID in `Sounds.luau`
- [ ] Live-test a real purchase of the cheapest product (29 R$) end to end
- [ ] Set visibility to **Public**

## 6. Metrics to track (Creator Dashboard → Analytics)
| Metric | Healthy target (simulator benchmark) | If below target, try... |
|---|---|---|
| **Day 1 retention** | ≥ 20% (great: 30%+) | Tighten onboarding (watch where new players stop), make the first Rare reachable within 10 min, show the login popup earlier |
| **Day 7 retention** | ≥ 6% (great: 10%+) | More daily-quest variety, a stronger day-7 reward, a weekly event, a better rebirth payoff |
| **Avg session length** | ≥ 15 min | Shorter weather gaps, more mid-tier species, collection bonuses for Index tiers |
| **DAU** | Growing week over week | Thumbnails/title, update tags, creator outreach, seasonal events |
| **Payer conversion** | 1.5–4% of DAU | Clearer pass value in-game (show "2x" preview), better shop placement. Never add pressure |
| **Revenue per DAU (ARPDAU)** | 0.5–2 R$/day | Add cosmetic items (trails, crowns, island themes); improve summon visibility |
| **Player feedback** | Track in Discord #suggestions, Roblox likes ratio ≥ 85% | Fix the top-voted pain point each week and credit the community |

Custom events worth adding with `AnalyticsService:LogCustomEvent` after launch: tutorial step reached, first Rare catch time, rebirth count, shop opened, which product was viewed. Funnels show exactly where players drop.

## 7. Post-launch roadmap
| Week | Focus |
|---|---|
| 1 | Hotfixes from live data; analytics funnel events; tune spawn weights |
| 2 | Update 1: 3 new species and the "Thunder Surge" weather |
| 3–4 | Island decorations (Sparkle sink + likes synergy) |
| 5–6 | Cloudling evolutions at max level |
| 7–8 | Weekly tournaments + badges; creator codes |
| Seasonal | Event species + map recolor for each season |
| Later | Trading (only with audit logs and confirmations), second biome stream, pets following the player |
