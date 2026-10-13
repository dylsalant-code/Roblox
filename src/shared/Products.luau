--!nonstrict
-- Products.luau
-- Game passes and developer products. Replace the `id = 0` values with the
-- IDs you create on the Creator Dashboard (see docs/PUBLISHING.md).
-- Prices here are display hints; Roblox's own purchase prompt always shows
-- the real price before any Robux are spent.

export type Pass = {
	key: string,
	id: number,
	price: number,
	name: string,
	icon: string,
	description: string,
}

export type Product = {
	key: string,
	id: number,
	price: number,
	name: string,
	icon: string,
	description: string,
	category: string,
	-- Sparkle packs: reward = max(minimum, incomePerSecond * seconds)
	seconds: number?,
	minimum: number?,
}

local Products = {}

Products.Passes = {
	{ key = "DoubleSparkles", id = 0, price = 399, name = "2x Sparkles", icon = "✨", description = "Permanently double all Sparkles your Cloudlings earn." },
	{ key = "AutoCollect", id = 0, price = 149, name = "Auto Collect", icon = "🧲", description = "Sparkles fly straight into your pocket — no need to step on the Collect Pad." },
	{ key = "BiggerIsland", id = 0, price = 199, name = "Bigger Island", icon = "🏝️", description = "+4 extra pedestals on your island, forever." },
	{ key = "VIP", id = 0, price = 249, name = "VIP", icon = "👑", description = "Golden VIP chat tag, floating crown, +10% Sparkles and the VIP cloud lounge." },
	{ key = "RainbowTrail", id = 0, price = 79, name = "Rainbow Trail", icon = "🌈", description = "Leave a shimmering rainbow trail wherever you walk. Pure style!" },
	{ key = "CloudSneakers", id = 0, price = 99, name = "Cloud Sneakers", icon = "👟", description = "Run 30% faster to reach rare Cloudlings first." },
} :: { Pass }

Products.Products = {
	{ key = "SparklePouch", id = 0, price = 29, name = "Sparkle Pouch", icon = "👝", category = "Sparkles", seconds = 10 * 60, minimum = 1_000, description = "10 minutes of your current income (at least 1K)." },
	{ key = "SparkleJar", id = 0, price = 99, name = "Sparkle Jar", icon = "🫙", category = "Sparkles", seconds = 45 * 60, minimum = 5_000, description = "45 minutes of your current income (at least 5K)." },
	{ key = "SparkleChest", id = 0, price = 299, name = "Cloud Chest", icon = "🎁", category = "Sparkles", seconds = 3 * 60 * 60, minimum = 25_000, description = "3 hours of your current income (at least 25K)." },
	{ key = "Boost30", id = 0, price = 49, name = "2x Boost (30 min)", icon = "⚡", category = "Boosts", description = "Double Sparkles for 30 minutes. Stacks with other boosts' time." },
	{ key = "SummonRainbow", id = 0, price = 199, name = "Summon Rainbow Storm", icon = "🌈", category = "Boosts", description = "Start a Rainbow Storm for EVERYONE in the server. Your name goes in the sky!" },
	{ key = "SummonStarfall", id = 0, price = 349, name = "Summon Starfall", icon = "🌠", category = "Boosts", description = "Start a Starfall for EVERYONE: more Legendary+ and Galaxy Cloudlings." },
} :: { Product }

local passByKey: { [string]: Pass } = {}
local productByKey: { [string]: Product } = {}
for _, p in Products.Passes do
	passByKey[p.key] = p
end
for _, p in Products.Products do
	productByKey[p.key] = p
end

function Products.Pass(key: string): Pass?
	return passByKey[key]
end

function Products.Product(key: string): Product?
	return productByKey[key]
end

function Products.PassById(id: number): Pass?
	if id == 0 then
		return nil
	end
	for _, p in Products.Passes do
		if p.id == id then
			return p
		end
	end
	return nil
end

function Products.ProductById(id: number): Product?
	if id == 0 then
		return nil
	end
	for _, p in Products.Products do
		if p.id == id then
			return p
		end
	end
	return nil
end

return Products
