# Monetization: ethical, optional, long-term

## Principles (enforced in code)
1. **Nothing is required.** Every Cloudling, mutation, weather type, pedestal (up to 16) and area can be earned by playing. The shop says so on screen.
2. **No gambling.** There are no eggs, crates or random paid rolls. Every Cloudling shows its species, mutation and price before you catch it, and Robux never buys a random outcome.
3. **No pressure tactics.** No countdown "deals", fake discounts, limited-time paid items or nagging pop-ups. The shop only opens when the player taps it.
4. **Transparent.** Each card states exactly what you get. Sparkle packs show the live amount ("You get: ✨12.3K"), and Roblox's native dialog always confirms the price before charging.
5. **Social goodwill.** The priciest products (weather summons) benefit **everyone in the server**, so spenders become local heroes instead of making others feel bad.

## Game passes (permanent)
| Pass | Price | What it does | Why players buy it |
|---|---|---|---|
| ✨ 2x Sparkles | **399 R$** | Doubles all Cloudling income forever | Genre-standard "best value". Progression feels twice as fast without locking content |
| 🧲 Auto Collect | **149 R$** | Income goes straight to your balance | Convenience for players who want to stay at the stream. Free players just walk to the pad |
| 🏝️ Bigger Island | **199 R$** | +4 pedestals (20 total) | More Cloudlings on show. 16 pedestals are still free |
| 👑 VIP | **249 R$** | Gold chat tag, floating crown, +10% income, VIP lounge | Status and identity. The crown is visible to everyone, which advertises the pass organically |
| 🌈 Rainbow Trail | **79 R$** | Rainbow trail cosmetic | Low-price impulse buy for self-expression |
| 👟 Cloud Sneakers | **99 R$** | +30% walk speed | Reach rare Cloudlings a bit sooner. Free players still win plenty of races; it's a modest edge |

## Developer products (repeatable)
| Product | Price | Gives | Notes |
|---|---|---|---|
| 👝 Sparkle Pouch | **29 R$** | 10 min of income (min 1K) | Scales with progress so it's never useless; amount shown live |
| 🫙 Sparkle Jar | **99 R$** | 45 min of income (min 5K) | |
| 🎁 Cloud Chest | **299 R$** | 3 h of income (min 25K) | |
| ⚡ 2x Boost (30 min) | **49 R$** | 2× income for 30 min, stacks time | Free version comes from the day-7 login streak |
| 🌈 Summon Rainbow Storm | **199 R$** | Starts a Rainbow Storm **for the whole server** | Name is announced. Free storms happen every 4–6 min anyway |
| 🌠 Summon Starfall | **349 R$** | Starts a Starfall for the whole server | Most "clip-able" moment in the game |

Purchased Sparkles **don't count** toward the "Top Sparkle Earners" leaderboard (`AddSparkles(..., false)`), so boards stay fair.

## Private servers
Recommended at **free (0 R$)** for launch, so friend groups and content creators can play together and record. After 10K+ DAU, consider **50–100 R$/month**.

## Pricing rationale
- Price points sit at Roblox impulse anchors (29 / 49 / 79–99 / 149–249 / 299–399) that young players and parents already know.
- The "anchor" pass (2x Sparkles, 399) makes VIP (249) and Auto Collect (149) look approachable without fake discounting.
- Weather summons are priced high because each one buys a shared server-wide experience; expect many first purchases there.

## Purchase safety (implemented)
- `MarketService.processReceipt` is idempotent. `PurchaseId` is stored in the player's save, the receipt is saved **before** `PurchaseGranted` is returned, and `NotProcessedYet` is returned if the player isn't loaded or the grant fails. Roblox then retries automatically.
- Pass ownership is checked with `UserOwnsGamePassAsync` on join and granted instantly on `PromptGamePassPurchaseFinished`.
- Studio-only free test purchases work while IDs are `0`. They are blocked outside Studio.

## Setting up the IDs
1. Publish the place (File → Publish to Roblox).
2. Creator Dashboard → your experience → **Monetization → Passes**: create the 6 passes with the prices above and icons (see VISUAL_IDENTITY.md).
3. **Monetization → Developer Products**: create the 6 products.
4. Paste each ID into `src/shared/Products.luau` (`id = 0` → `id = 123456789`).
5. Test in a live server with a small purchase. Roblox charges real Robux in live games; Studio purchases are simulated.

## Revenue expectations (planning assumptions, not guarantees)
Healthy ethical simulators often see **1.5–4% payer conversion** and **0.5–2 R$ revenue per DAU per day**. Track the real numbers in Creator Analytics (see LAUNCH.md) and adjust only by adding value, never by adding pressure.
