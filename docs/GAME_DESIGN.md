# Game Design: Catch a Cloudling

## 1. Market research (time-boxed)

### Verified (web sources, 2025–2026)
- **Grow a Garden** set a platform record of about 21M concurrent players. **Steal a Brainrot** later passed it, with reported peaks above 25M. Both are owned by the same studio group. Sources disagree on exact peaks.
- Steal a Brainrot's loop: you buy meme characters from a shared conveyor, they generate cash in your base, and others can steal them. Commentators credit its virality to meme alignment, built-in clip moments (steals, rare spawns) and unpredictability.
- In 2026, the top charts are led by Murder Mystery 2, Grow a Garden 2, Brookhaven RP, Blox Fruits, Adopt Me!, 99 Nights in the Forest, RIVALS and Fish It!. Simulators and social/roleplay games dominate, and fishing / "catching" games grew strongly (one report: +55% YoY).
- Sources: exitlag.com (genre trends 2026), rowatcher.com (live player rankings), studiokrew.com (monthly top games), plus press coverage of the Grow a Garden and Steal a Brainrot records.

### Assumptions (industry pattern knowledge, not freshly verified)
- The winning formula is **simple verbs** (buy, plant, catch) plus **visible value** (you can see what your thing earns) plus **shared-world scarcity** (everyone sees the same rare spawn) plus **timed server events** (weather, admin abuse, restocks).
- Young players respond to **cute creatures with faces**, bright saturated colors and big satisfying numbers.
- Retention comes from **offline progress, daily streaks and collection books**. Virality comes from **"OMG it spawned"** moments that are easy to clip.
- Monetization in top simulators: x2 currency passes, auto-collect convenience, server-wide event summons, and currency packs that scale with progress.

## 2. Five original concepts

Each concept is scored 1–10 on five criteria (higher is better; for Dev Difficulty, higher means easier).

| # | Concept | Pitch | Viral | Dev Difficulty | Retention | Monetization | Originality | **Total** |
|---|---|---|---|---|---|---|---|---|
| 1 | **Catch a Cloudling** | Cute cloud creatures drift down a shared Rainbow Stream. Buy what you see, they earn Sparkles on your sky island, weather storms spawn rare mutations | 9 | 8 | 9 | 9 | 7 | **42** |
| 2 | Bake a Monster | Mix ingredients in an oven to hatch monster-cakes that work in your bakery | 7 | 5 | 8 | 8 | 8 | 36 |
| 3 | Grow a Volcano | Feed lava to a pet volcano; eruptions fling collectibles across the server | 8 | 5 | 6 | 7 | 9 | 35 |
| 4 | Robot Pet Arena | Build tiny robots from parts and battle friends in 60-second matches | 7 | 3 | 7 | 7 | 6 | 30 |
| 5 | Sky Taxi Tycoon | Fly passengers between floating islands to unlock new routes | 5 | 5 | 6 | 6 | 7 | 29 |

### Why Catch a Cloudling wins
- **Proven loop, fresh skin.** It keeps the conveyor-buy-earn loop that powered the biggest 2025 hits but removes stealing. Stealing drives clips, but it also drives rage-quits and negative parent sentiment. Competition comes from **racing**: whoever reaches the Secret Cloudling first gets it, which keeps the clip moments without the toxicity.
- **Instantly readable.** It explains itself in 15 seconds: "Cloudlings float by → press E → they make Sparkles → step on the pad."
- **Built from code.** Cute creatures made from spheres look intentional and polished, so a small team can ship fast and add new species in minutes (one line of data each).
- **Strong event hooks.** Weather is free, server-wide and timed, which creates natural "everyone rush the stream!" moments and a fair, optional product (summon a storm for everyone).
- **Ethical monetization fits naturally.** Every Cloudling is visible with its price before you buy, so there are no blind boxes.

## 3. Core gameplay

### The 15-second pitch, as players see it
1. You spawn on **your own floating island** with 75 Sparkles.
2. A glowing beam points to the **Rainbow Stream**, where Cloudlings drift by showing their price and income.
3. You press **E** or tap and catch one. It arcs through the sky onto your pedestal.
4. Sparkles pile up on the pedestal. You step on the **golden Collect Pad** and the counter jumps.

### Core loop (seconds to minutes)
```
 Watch the stream → Catch (spend) → Cloudling earns on pedestal → Collect (pad)
        ↑                                                          │
        └──────── Upgrade / unlock pedestals / catch rarer ←───────┘
```

### Meta loop (hours to weeks)
- **Rebirth**: reset Sparkles and Cloudlings for a permanent +50% income per rebirth. Pedestals, Index, achievements and passes are kept.
- **Index**: 22 species × 4 mutations = 88 entries. Each first discovery pays a bonus.
- **Daily quests** (3 per day, deterministic per player) plus a bonus for completing all three.
- **7-day login streak**. Day 7 grants a free 15-minute 2x boost.
- **Achievements**: 18 trophies with Sparkle rewards.
- **Seasonal Cloudlings**: Pumpcloud and Ghostfluff (Spooky Skies, Oct 1–Nov 5), Jinglepuff and Snowcrown (Frosty Fluffmas, Dec 10–Jan 5).
- **Community Goal**: all servers' catches add up, and each milestone permanently gives everyone +10%.

### Economy (see `Config.luau`, `CloudlingData.luau`, `Formulas.luau`)
| Rarity | Spawn weight | Price range | Income/s | Payback |
|---|---|---|---|---|
| Common | 60 | 25 – 120 | 1 – 4 | ~25–30 s |
| Uncommon | 25 | 300 – 1.2K | 9 – 32 | ~33–38 s |
| Rare | 10 | 3K – 12K | 70 – 240 | ~43–50 s |
| Epic | 3.5 | 30K – 120K | 550 – 2K | ~55–60 s |
| Legendary | 1.2 | 350K – 800K | 5.5K – 12K | ~64–67 s |
| Mythic | 0.25 | 2.5M – 6M | 35K – 80K | ~71–75 s |
| Secret | 0.05 | 25M – 60M | 300K – 700K | ~83–86 s |

- **Mutations** multiply price and income equally (Golden ×2, Rainbow ×3, Galaxy ×5), so they're fair value but rarer and flashier.
- **Upgrades**: income +35% per level; cost `price × 0.35 × level^1.25`. Payback goes from ~30 s at level 1 to under 30 min at level 25, which is enforced by tests.
- **Pedestals**: 8 at start, buy up to 16 (cost `500 × 3.2^n`), +4 with a pass.
- **Rebirth** cost `50K × 5^r`.
- **Offline earnings**: 25% of income for up to 2 hours.

### Multiplayer & social
- **Shared stream.** Every player sees the same Cloudlings, so racing for rare ones is the core social tension.
- **Server announcements** for Epic+ catches, mutations, Mythic/Secret spawns, rebirths and summoned weather.
- **Island likes** (one per island per session) feed a global "Most Loved Islands" board.
- **Friend Boost**: +10% income per friend in the server, up to +30%. This drives invites.
- **Leaderboards**: in-server leaderstats plus 3 global boards (earnings, rebirths, likes) and the Community board.
- **VIP lounge** on a floating cloud above the arch, a social hangout for supporters.

### Weather events (free, every 4–6 min, 90 s each)
| Weather | Effect | Visual |
|---|---|---|
| 🌈 Rainbow Storm | Rainbow mutation chance 20% | rainbow particle rain, pink tint |
| 🌅 Golden Hour | Golden mutation chance 25% | sunset clock, warm tint, gold motes |
| 🌠 Starfall | Galaxy 6%, Legendary+ spawn weight ×4 | night sky, falling purple stars |
| 🫧 Bubble Breeze | Spawn rate ×2 | rising bubbles, cool tint |

### Tutorial (server-driven, skippable)
| Step | Prompt | Advances when |
|---|---|---|
| 0 | Walk to the Rainbow Stream and catch one you can afford | first catch (beam points at nearest affordable upstream Cloudling) |
| 1 | Step on the golden Collect Pad | first collect |
| 2 | Upgrade your Cloudling at its pedestal | first upgrade |
| 3 | "You're a natural!" summary | auto-finishes after 9 s |

### Accessibility & platforms
- All interactions use **ProximityPrompts** (keyboard E/F/R, tap, gamepad).
- One **UIScale** maps a 1100×650 virtual canvas to any screen (clamped 0.5–1.4).
- Menu buttons sit mid-left, clear of the mobile thumbstick and jump button.
- Toasts appear at bottom-center above the tutorial, banners at top-center.
- Music, SFX and cosmetics can each be toggled in Settings.
