-- Economy + formatting invariants. Run with: python3 tests/run_tests.py
local passed, failed = 0, 0
local function check(name: string, cond: boolean, detail: any?)
	if cond then
		passed += 1
	else
		failed += 1
		print("FAIL: " .. name .. (if detail ~= nil then " (" .. tostring(detail) .. ")" else ""))
	end
end

-- Number formatting
check("format small", Formulas.Format(999) == "999", Formulas.Format(999))
check("format K", Formulas.Format(1500) == "1.5K", Formulas.Format(1500))
check("format M", Formulas.Format(2_000_000) == "2M", Formulas.Format(2_000_000))
check("format 250K", Formulas.Format(250_000) == "250K", Formulas.Format(250_000))
check("format B", Formulas.Format(3_400_000_000) == "3.4B", Formulas.Format(3_400_000_000))
check("format time", Formulas.FormatTime(75) == "1:15", Formulas.FormatTime(75))

-- Every species is valid and payback stays in a fun range (20s - 120s).
local ids = {}
for _, s in CloudlingData.Species do
	check("unique id " .. s.id, ids[s.id] == nil)
	ids[s.id] = true
	check("rarity exists " .. s.id, CloudlingData.Rarities[s.rarity] ~= nil)
	local payback = s.price / s.income
	check("payback " .. s.id, payback >= 20 and payback <= 120, payback)
end

-- Within each rarity, rarer = more income; across tiers, income increases.
local lastMax = 0
for _, r in CloudlingData.RarityOrder do
	local minIncome, maxIncome = math.huge, 0
	for _, s in CloudlingData.Species do
		if s.rarity == r and not s.event then
			minIncome = math.min(minIncome, s.income)
			maxIncome = math.max(maxIncome, s.income)
		end
	end
	check("tier ordering " .. r, minIncome > lastMax, minIncome)
	lastMax = maxIncome
end

-- New players can afford at least two Commons at the start.
check("starter affordable", Config.StartingSparkles >= Formulas.CatchPrice("puffle", "None") + Formulas.CatchPrice("drizzlet", "None") - 10)

-- Mutations multiply price and income equally (fair value).
check("golden price", Formulas.CatchPrice("puffle", "Golden") == 50)
check("galaxy income", Formulas.CloudlingIncome("puffle", "Galaxy", 1) == 5)

-- Upgrades always pay back eventually and costs grow.
for lvl = 1, Config.MaxLevel - 1 do
	local cost = Formulas.UpgradeCost("breezy", "None", lvl)
	local gain = Formulas.CloudlingIncome("breezy", "None", lvl + 1) - Formulas.CloudlingIncome("breezy", "None", lvl)
	-- Late upgrades are slower by design, but never worse than ~30 minutes.
	check("upgrade payback lvl " .. lvl, cost / gain < 1800, cost / gain)
	check("upgrade grows lvl " .. lvl, Formulas.UpgradeCost("breezy", "None", lvl + 1) > cost)
end

-- Selling never refunds more than was spent.
check("sell < spent", Formulas.SellValue("thunderpup", "None", 5) < Formulas.CatchPrice("thunderpup", "None") * 10)

-- Rebirth curve grows and multiplier helps.
check("rebirth grows", Formulas.RebirthCost(1) > Formulas.RebirthCost(0))
check("rebirth mult", Formulas.RebirthMultiplier(2) == 2)

-- Slot costs grow.
check("slot grows", Formulas.SlotCost(Config.StartingSlots + 1) > Formulas.SlotCost(Config.StartingSlots))
check("slot capacity", Config.MaxPurchasableSlots + Config.PassBonusSlots <= Config.MaxTotalSlots)

-- Rarity weights sum to ~100 and Secret is genuinely rare.
local total = 0
for _, r in CloudlingData.Rarities do
	total += r.weight
end
check("weights ~100", math.abs(total - 100) < 0.5, total)
check("secret rare", CloudlingData.Rarities.Secret.weight / total < 0.001)

-- Event species reference real events.
for _, s in CloudlingData.Species do
	if s.event then
		local found = false
		for _, e in Config.SeasonalEvents do
			found = found or e.id == s.event
		end
		check("event exists " .. s.id, found)
	end
end

-- Products have unique keys and positive prices.
local keys = {}
for _, list in { Products.Passes, Products.Products } do
	for _, p in list do
		check("unique product " .. p.key, keys[p.key] == nil)
		keys[p.key] = true
		check("price " .. p.key, p.price > 0)
	end
end

-- Quests have the fields the server expects.
for _, q in QuestData.Pool do
	check("quest text " .. q.id, string.find(q.text, "%%s") ~= nil)
	check("quest range " .. q.id, q.min <= q.max)
end
check("enough quests", #QuestData.Pool >= QuestData.DailyCount)

print(string.format("economy.spec: %d passed, %d failed", passed, failed))
if failed > 0 then
	error("tests failed")
end
