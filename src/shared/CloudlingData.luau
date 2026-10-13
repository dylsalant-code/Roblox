--!nonstrict
-- CloudlingData.luau
-- Static definitions for every Cloudling species, rarity tier, mutation and
-- weather type. Purely data + tiny lookup helpers; no side effects.

export type Rarity = {
	name: string,
	order: number,
	weight: number,
	color: Color3,
	announce: boolean, -- broadcast to the whole server when caught/spawned
}

export type Species = {
	id: string,
	name: string,
	rarity: string,
	price: number,
	income: number, -- Sparkles per second at level 1
	body: Color3,
	accent: Color3,
	feature: string, -- visual add-on built by CloudlingModel
	size: number,
	event: string?, -- seasonal event id; nil = always available
}

export type Mutation = {
	name: string,
	multiplier: number,
	baseChance: number,
	color: Color3,
	order: number,
}

local CloudlingData = {}

CloudlingData.Rarities = {
	Common = { name = "Common", order = 1, weight = 60, color = Color3.fromRGB(200, 214, 229), announce = false },
	Uncommon = { name = "Uncommon", order = 2, weight = 25, color = Color3.fromRGB(110, 220, 120), announce = false },
	Rare = { name = "Rare", order = 3, weight = 10, color = Color3.fromRGB(80, 160, 255), announce = false },
	Epic = { name = "Epic", order = 4, weight = 3.5, color = Color3.fromRGB(190, 100, 255), announce = true },
	Legendary = { name = "Legendary", order = 5, weight = 1.2, color = Color3.fromRGB(255, 190, 40), announce = true },
	Mythic = { name = "Mythic", order = 6, weight = 0.25, color = Color3.fromRGB(255, 70, 120), announce = true },
	Secret = { name = "Secret", order = 7, weight = 0.05, color = Color3.fromRGB(30, 30, 40), announce = true },
} :: { [string]: Rarity }

CloudlingData.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

CloudlingData.Species = {
	-- Common
	{ id = "puffle", name = "Puffle", rarity = "Common", price = 25, income = 1, body = rgb(255, 255, 255), accent = rgb(255, 170, 200), feature = "none", size = 2.4 },
	{ id = "drizzlet", name = "Drizzlet", rarity = "Common", price = 60, income = 2, body = rgb(170, 210, 255), accent = rgb(90, 150, 255), feature = "antenna", size = 2.4 },
	{ id = "snowmote", name = "Snowmote", rarity = "Common", price = 120, income = 4, body = rgb(235, 245, 255), accent = rgb(160, 200, 255), feature = "ears", size = 2.6 },
	-- Uncommon
	{ id = "breezy", name = "Breezy", rarity = "Uncommon", price = 300, income = 9, body = rgb(190, 255, 220), accent = rgb(60, 200, 140), feature = "wings", size = 2.7 },
	{ id = "fluffin", name = "Fluffin", rarity = "Uncommon", price = 650, income = 18, body = rgb(255, 220, 240), accent = rgb(255, 120, 180), feature = "ears", size = 2.8 },
	{ id = "mistmunch", name = "Mistmunch", rarity = "Uncommon", price = 1_200, income = 32, body = rgb(200, 200, 230), accent = rgb(130, 110, 200), feature = "tail", size = 2.9 },
	-- Rare
	{ id = "thunderpup", name = "Thunderpup", rarity = "Rare", price = 3_000, income = 70, body = rgb(255, 240, 120), accent = rgb(80, 80, 120), feature = "bolt", size = 3.0 },
	{ id = "sunnybun", name = "Sunnybun", rarity = "Rare", price = 6_500, income = 140, body = rgb(255, 200, 110), accent = rgb(255, 130, 60), feature = "ears", size = 3.0 },
	{ id = "hailhopper", name = "Hailhopper", rarity = "Rare", price = 12_000, income = 240, body = rgb(160, 240, 255), accent = rgb(40, 160, 220), feature = "horns", size = 3.1 },
	-- Epic
	{ id = "rainbeau", name = "Rainbeau", rarity = "Epic", price = 30_000, income = 550, body = rgb(255, 160, 210), accent = rgb(120, 220, 255), feature = "wings", size = 3.3 },
	{ id = "auroracat", name = "Auroracat", rarity = "Epic", price = 65_000, income = 1_100, body = rgb(140, 255, 200), accent = rgb(150, 90, 255), feature = "ears", size = 3.3 },
	{ id = "frostfox", name = "Frostfox", rarity = "Epic", price = 120_000, income = 2_000, body = rgb(220, 240, 255), accent = rgb(90, 170, 255), feature = "tail", size = 3.4 },
	-- Legendary
	{ id = "stormdrake", name = "Stormdrake", rarity = "Legendary", price = 350_000, income = 5_500, body = rgb(90, 100, 160), accent = rgb(255, 230, 80), feature = "horns", size = 3.8 },
	{ id = "solarion", name = "Solarion", rarity = "Legendary", price = 800_000, income = 12_000, body = rgb(255, 210, 60), accent = rgb(255, 120, 30), feature = "crown", size = 3.8 },
	-- Mythic
	{ id = "nebulynx", name = "Nebulynx", rarity = "Mythic", price = 2_500_000, income = 35_000, body = rgb(110, 60, 200), accent = rgb(255, 120, 230), feature = "ears", size = 4.1 },
	{ id = "cosmoose", name = "Cosmoose", rarity = "Mythic", price = 6_000_000, income = 80_000, body = rgb(40, 50, 120), accent = rgb(120, 230, 255), feature = "antlers", size = 4.3 },
	-- Secret
	{ id = "starwhale", name = "Starwhale", rarity = "Secret", price = 25_000_000, income = 300_000, body = rgb(30, 40, 90), accent = rgb(255, 255, 160), feature = "halo", size = 4.8 },
	{ id = "prismking", name = "Prism King", rarity = "Secret", price = 60_000_000, income = 700_000, body = rgb(255, 255, 255), accent = rgb(255, 80, 200), feature = "crown", size = 5.0 },
	-- Seasonal (only spawn while their event is live; kept forever once caught)
	{ id = "pumpcloud", name = "Pumpcloud", rarity = "Rare", price = 8_000, income = 180, body = rgb(255, 140, 40), accent = rgb(60, 160, 60), feature = "stem", size = 3.0, event = "Spooky" },
	{ id = "ghostfluff", name = "Ghostfluff", rarity = "Epic", price = 90_000, income = 1_600, body = rgb(240, 240, 255), accent = rgb(120, 60, 180), feature = "none", size = 3.4, event = "Spooky" },
	{ id = "jinglepuff", name = "Jinglepuff", rarity = "Rare", price = 8_000, income = 180, body = rgb(255, 80, 90), accent = rgb(255, 255, 255), feature = "hat", size = 3.0, event = "Frosty" },
	{ id = "snowcrown", name = "Snowcrown", rarity = "Legendary", price = 500_000, income = 8_000, body = rgb(230, 250, 255), accent = rgb(120, 200, 255), feature = "crown", size = 3.8, event = "Frosty" },
} :: { Species }

CloudlingData.Mutations = {
	None = { name = "None", multiplier = 1, baseChance = 0, color = Color3.new(1, 1, 1), order = 1 },
	Golden = { name = "Golden", multiplier = 2, baseChance = 0.03, color = rgb(255, 200, 40), order = 2 },
	Rainbow = { name = "Rainbow", multiplier = 3, baseChance = 0.01, color = rgb(255, 100, 200), order = 3 },
	Galaxy = { name = "Galaxy", multiplier = 5, baseChance = 0.003, color = rgb(120, 70, 255), order = 4 },
} :: { [string]: Mutation }

CloudlingData.MutationOrder = { "None", "Golden", "Rainbow", "Galaxy" }

-- Weather events: server-wide, visible, time-limited, never paywalled.
-- `mutation` sets that mutation's chance; `rarityBoost` multiplies weights
-- for Legendary+; `spawnRate` multiplies how fast the stream spawns.
CloudlingData.Weather = {
	RainbowStorm = { name = "Rainbow Storm", icon = "🌈", mutation = "Rainbow", chance = 0.2, color = rgb(255, 120, 220) },
	GoldenHour = { name = "Golden Hour", icon = "🌅", mutation = "Golden", chance = 0.25, color = rgb(255, 200, 60) },
	Starfall = { name = "Starfall", icon = "🌠", mutation = "Galaxy", chance = 0.06, rarityBoost = 4, color = rgb(120, 90, 255) },
	BubbleBreeze = { name = "Bubble Breeze", icon = "🫧", spawnRate = 2, color = rgb(120, 220, 255) },
}
CloudlingData.WeatherOrder = { "RainbowStorm", "GoldenHour", "Starfall", "BubbleBreeze" }

-- Lookups -------------------------------------------------------------------
local byId: { [string]: Species } = {}
for _, s in CloudlingData.Species do
	byId[s.id] = s
end

function CloudlingData.Get(id: string): Species?
	return byId[id]
end

function CloudlingData.IndexKey(id: string, mutation: string): string
	return id .. ":" .. mutation
end

-- Total possible Index entries (every species x every mutation).
function CloudlingData.IndexTotal(): number
	return #CloudlingData.Species * #CloudlingData.MutationOrder
end

return CloudlingData
