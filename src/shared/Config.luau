--!nonstrict
-- Config.luau
-- Central tuning knobs for Catch a Cloudling. Every balance number lives here
-- (or in CloudlingData) so designers can iterate without touching game logic.

local Config = {}

Config.GameName = "Catch a Cloudling"
Config.DataVersion = 1
Config.DataStoreName = "CloudlingPlayerData_v1"

-- Economy -----------------------------------------------------------------
Config.StartingSparkles = 75 -- enough for a Puffle + Drizzlet on the first visit
Config.StartingSlots = 8 -- pedestals unlocked on a fresh island
Config.MaxPurchasableSlots = 16 -- unlockable with Sparkles
Config.PassBonusSlots = 4 -- extra pedestals from the "Bigger Island" pass
Config.MaxTotalSlots = 20 -- physical pedestals built per island
Config.SellRefund = 0.5 -- fraction of catch price returned when releasing
Config.MaxLevel = 25

Config.OfflineEarningsRate = 0.25 -- 25% of income while away...
Config.OfflineEarningsCapSeconds = 2 * 60 * 60 -- ...for up to 2 hours

Config.FriendBoostPerFriend = 0.10 -- +10% income per friend in the server
Config.FriendBoostMax = 0.30

Config.RebirthBaseCost = 50_000
Config.RebirthCostGrowth = 5
Config.RebirthIncomeBonus = 0.5 -- +50% income per rebirth (additive)

-- Rainbow Stream (the shared conveyor of Cloudlings) ----------------------
Config.StreamStartX = -215
Config.StreamEndX = 215
Config.StreamHeight = 5
Config.StreamSpeed = 8 -- studs / second
Config.StreamSpawnInterval = 2.6 -- seconds between spawns
Config.StreamMaxActive = 24

-- Weather -----------------------------------------------------------------
Config.WeatherMinGap = 240
Config.WeatherMaxGap = 360
Config.WeatherDuration = 90

-- Timers ------------------------------------------------------------------
Config.AutosaveInterval = 120
Config.IncomeTickInterval = 1
Config.LeaderboardRefresh = 180
Config.CommunityFlushInterval = 120

-- Community milestones: total Cloudlings caught by every player, all servers.
-- Each milestone reached permanently adds +10% income for everyone.
Config.CommunityMilestones = { 10_000, 100_000, 1_000_000, 10_000_000, 100_000_000 }
Config.CommunityBoostPerMilestone = 0.10

-- Seasonal events (date ranges are inclusive, UTC). Event Cloudlings only
-- spawn while the event is live, which gives players a reason to return.
Config.SeasonalEvents = {
	{
		id = "Spooky",
		name = "Spooky Skies",
		startMonth = 10,
		startDay = 1,
		endMonth = 11,
		endDay = 5,
		species = { "pumpcloud", "ghostfluff" },
		tint = Color3.fromRGB(255, 140, 60),
	},
	{
		id = "Frosty",
		name = "Frosty Fluffmas",
		startMonth = 12,
		startDay = 10,
		endMonth = 1,
		endDay = 5,
		species = { "jinglepuff", "snowcrown" },
		tint = Color3.fromRGB(150, 220, 255),
	},
}

-- Remote rate limits (calls per second, burst) ------------------------------
Config.ActionRate = 8
Config.ActionBurst = 12

-- Purchases are simulated (no Robux) only in Studio when an ID is still 0.
Config.AllowStudioTestPurchases = true

return Config
