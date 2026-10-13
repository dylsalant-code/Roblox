# Retention & Growth

## Why players come back (systems already in the build)
| Hook | Mechanism | File |
|---|---|---|
| Offline earnings | Cloudlings bank 25% of income for 2 h while you're away. "Welcome back" toast | `ProgressService:OnJoin` |
| Login streak | 7-day ladder with a growing reward. Day 7 gives a free 2x boost. The popup opens automatically | `QuestData.LoginRewards` |
| Daily quests | 3 per day, different each day, reward scaled to income, bonus for all 3 | `QuestData.Pool` |
| Index | 88 entries. Mutations make it a long-term goal. Each first discovery pays a bonus | `IndexPanel` |
| Weather | Something exciting every 4–6 minutes, so short sessions still get a peak | `WeatherService` |
| Seasonal Cloudlings | Only spawn during their event window, and you keep them forever once caught | `Config.SeasonalEvents` |
| Community goals | Every server's catches move one global bar. Milestones boost everyone | `CommunityService` |
| Rebirth | Permanent multiplier. "One more rebirth" loop | `ProgressService:Rebirth` |
| Social | Friend boost, likes, leaderboards, VIP lounge, announcements | `PlotService`, `LeaderboardService` |

## Shareable moments (built for TikTok/Shorts)
- 🤫 Server-wide "**A SECRET is drifting down the Rainbow Stream!**" banner, followed by everyone sprinting.
- Rainbow/Galaxy mutations glowing and color-cycling; the catch arc flying across the sky to your island.
- "**X summoned a Starfall for everyone!**": the sky turns to night with falling stars.
- Rebirth screen flash plus a server announcement; big Sparkle numbers flying into the counter.

## Launch plan

### Phase A: First 100 players (week 0–1)
1. Soft-launch **public** with the icon, 2 thumbnails and a description containing the keywords.
2. Friends, family and Discord: ask 10 people to each bring 2 friends. The friend boost makes this rewarding in-game.
3. Post 3–5 raw gameplay clips per day on TikTok/YouTube Shorts from your own account (see the ideas below).
4. Ask Roblox-focused Discords and subreddits (r/robloxgamedev showcase threads) for feedback. Feedback posts don't come across as spam.
5. Watch every session with the Studio Developer Console and in-game; fix the top 3 confusion points.

### Phase B: 1,000 players (weeks 2–4)
1. **Sponsored Ads / Ads Manager**: start with about 1,000–3,000 R$/day for 3–5 days on the best-CTR thumbnail. Kill creatives under 2% CTR.
2. Ship **Update 1** (new species pack plus a 5th weather). Change the title to "**[UPDATE 🌈] Catch a Cloudling**". Update tags strongly drive Roblox discovery.
3. Run a **Community Goal** event ("help us reach 100K catches → +10% forever"). Announce it in Discord and on social media.
4. Reach out to 20–30 small Roblox YouTubers/TikTokers (1K–50K subs). Offer free passes and a custom Cloudling named after their community.
5. Set up a Discord with #clips, #suggestions and #bugs. Pin a "post your Secret catch" challenge.

### Phase C: 10,000 players (months 2–3)
1. **Weekly update cadence** (below). Every update gets the [UPDATE] title tag, a new thumbnail and a short trailer.
2. Run a **seasonal event** (Spooky Skies is already built for October). Limited species bring lapsed players back.
3. Hold weekend **2x Weather** events (shorter `WeatherMinGap`) announced in advance on social media.
4. Pitch creators with 100K+ subscribers using metrics (D1 retention, session length) and a creator code reward.
5. Localize the description and key UI strings (Spanish, Portuguese, Indonesian, Filipino, Thai are big Roblox markets).

## TikTok / Shorts content ideas (15–30 s, vertical)
1. "POV: a SECRET Cloudling spawns and the whole server panics" (screen-record the banner and the race).
2. "Rating every Cloudling from Common to Secret": walk the Index.
3. "I summoned a Starfall for a random server…" (people's reactions in chat).
4. "Day 1 vs Day 7 island" glow-up time-lapse.
5. "Rebirth 0 → Rebirth 5 in one video" (speed-run).
6. "Rarest mutation in Catch a Cloudling (Galaxy Prism King?!)".
7. "Catching ONLY rainbow Cloudlings challenge".
8. "Guess the Cloudling by its silhouette" (uses the Index silhouettes).
9. "Making my little brother's island the most liked in the server" (wholesome likes).
10. Dev-log style: "I made a Roblox game where clouds are pets" with code and design snippets.

Hook in the first second (banner or rare glow), big captions, trending audio, and the game name on screen at the end.

## Roblox discovery checklist
- Title under 30 characters plus an update tag. Description: first line is the hook, then features, then the update log.
- Genre: Simulation. Supported devices: all. Fill in the content maturity questionnaire (expected: Minimal).
- Keep the icon and thumbnails crisp and bright, and test thumbnails against each other.
- Discovery rewards **session length, retention and Qualified Play-throughs**, so improve those first (see LAUNCH.md).

## Update schedule (realistic for a solo dev or small team)
| Cadence | Content |
|---|---|
| Weekly (Fri) | 2–3 new Cloudlings (one line of data each), a balance pass, bug fixes, [UPDATE] tag |
| Bi-weekly | New weather type or mechanic (e.g. "Thunder Surge": stream speed ×1.5) |
| Monthly | Larger feature: trading (with safeguards), island decorations, or a second stream biome |
| Seasonal | Event species + map recolor (Spooky Skies Oct, Frosty Fluffmas Dec, Spring Blossom Apr, Summer Splash Jul) |

## Next features (ranked by retention impact / effort)
1. **Island decorations** (Sparkle sink + self-expression + likes synergy).
2. **Cloudling evolutions**: max-level Cloudlings evolve into a new look (long-term goal).
3. **Friend gifting** of boosts (social, no trading exploits).
4. **Weekly server tournaments**: most Sparkles collected in 10 minutes, with cosmetic badges.
5. **Trading** only once the data layer has full audit logs. It's high virality but also high exploit risk.
