--!nonstrict
-- QuestData.luau
-- Daily quest pool and permanent achievements. Rewards scale with the
-- player's income so they stay meaningful from minute one to rebirth 10.

export type QuestDef = {
	id: string,
	text: string, -- "%s" is replaced by the formatted target
	event: string,
	min: number,
	max: number,
	scaleSeconds: number?, -- if set, target = max(min, income * scaleSeconds)
	rewardSeconds: number,
	rewardMin: number,
}

export type AchievementDef = {
	id: string,
	name: string,
	description: string,
	stat: string,
	goal: number,
	reward: number,
}

local QuestData = {}

QuestData.DailyCount = 3

QuestData.Pool = {
	{ id = "catch", text = "Catch %s Cloudlings", event = "Catch", min = 5, max = 12, rewardSeconds = 240, rewardMin = 300 },
	{ id = "catchRare", text = "Catch %s Rare-or-better Cloudling", event = "CatchRare", min = 1, max = 1, rewardSeconds = 420, rewardMin = 800 },
	{ id = "collect", text = "Collect %s Sparkles", event = "Collect", min = 500, max = 500, scaleSeconds = 600, rewardSeconds = 300, rewardMin = 400 },
	{ id = "upgrade", text = "Upgrade Cloudlings %s times", event = "Upgrade", min = 3, max = 8, rewardSeconds = 240, rewardMin = 300 },
	{ id = "like", text = "Like %s other islands", event = "LikeGiven", min = 2, max = 3, rewardSeconds = 180, rewardMin = 250 },
	{ id = "play", text = "Play for %s minutes", event = "PlayMinute", min = 10, max = 20, rewardSeconds = 300, rewardMin = 400 },
	{ id = "weather", text = "Catch %s Cloudling during a weather event", event = "CatchWeather", min = 1, max = 2, rewardSeconds = 360, rewardMin = 500 },
	{ id = "mutation", text = "Catch %s mutated Cloudling", event = "CatchMutation", min = 1, max = 1, rewardSeconds = 600, rewardMin = 1000 },
} :: { QuestDef }

-- Bonus for finishing all three dailies (in seconds of income).
QuestData.AllCompleteBonusSeconds = 900
QuestData.AllCompleteBonusMin = 1500

-- 7-day login streak. Day 7 also grants a free 15-minute 2x boost.
QuestData.LoginRewards = {
	{ seconds = 120, min = 100 },
	{ seconds = 180, min = 200 },
	{ seconds = 300, min = 350 },
	{ seconds = 420, min = 500 },
	{ seconds = 600, min = 800 },
	{ seconds = 900, min = 1200 },
	{ seconds = 1500, min = 2500, boostMinutes = 15 },
}

QuestData.Achievements = {
	{ id = "catch1", name = "First Friend", description = "Catch your first Cloudling", stat = "caught", goal = 1, reward = 50 },
	{ id = "catch25", name = "Cloud Collector", description = "Catch 25 Cloudlings", stat = "caught", goal = 25, reward = 1_000 },
	{ id = "catch250", name = "Sky Rancher", description = "Catch 250 Cloudlings", stat = "caught", goal = 250, reward = 50_000 },
	{ id = "catch1000", name = "Cloud Whisperer", description = "Catch 1,000 Cloudlings", stat = "caught", goal = 1000, reward = 2_000_000 },
	{ id = "rare1", name = "Shiny Eye", description = "Catch a Rare-or-better Cloudling", stat = "rareCaught", goal = 1, reward = 500 },
	{ id = "mutation1", name = "Something's Different", description = "Catch a mutated Cloudling", stat = "mutationsCaught", goal = 1, reward = 1_500 },
	{ id = "secret1", name = "Keeper of Secrets", description = "Catch a Secret Cloudling", stat = "secretsCaught", goal = 1, reward = 5_000_000 },
	{ id = "index10", name = "Bookworm", description = "Discover 10 Index entries", stat = "discovered", goal = 10, reward = 2_500 },
	{ id = "index40", name = "Cloudopedia", description = "Discover 40 Index entries", stat = "discovered", goal = 40, reward = 250_000 },
	{ id = "upgrade25", name = "Fluff Trainer", description = "Upgrade Cloudlings 25 times", stat = "upgrades", goal = 25, reward = 5_000 },
	{ id = "upgrade250", name = "Fluff Master", description = "Upgrade Cloudlings 250 times", stat = "upgrades", goal = 250, reward = 250_000 },
	{ id = "earn1m", name = "Millionaire Mist", description = "Earn 1M Sparkles total", stat = "totalEarned", goal = 1_000_000, reward = 25_000 },
	{ id = "earn1b", name = "Billionaire Breeze", description = "Earn 1B Sparkles total", stat = "totalEarned", goal = 1_000_000_000, reward = 10_000_000 },
	{ id = "rebirth1", name = "Born Again", description = "Rebirth once", stat = "rebirths", goal = 1, reward = 10_000 },
	{ id = "rebirth5", name = "Cloud Phoenix", description = "Rebirth 5 times", stat = "rebirths", goal = 5, reward = 5_000_000 },
	{ id = "likes10", name = "Island Influencer", description = "Receive 10 island likes", stat = "likesReceived", goal = 10, reward = 5_000 },
	{ id = "likes100", name = "Sky Celebrity", description = "Receive 100 island likes", stat = "likesReceived", goal = 100, reward = 500_000 },
	{ id = "streak7", name = "Regular", description = "Reach a 7-day login streak", stat = "bestStreak", goal = 7, reward = 20_000 },
} :: { AchievementDef }

return QuestData
