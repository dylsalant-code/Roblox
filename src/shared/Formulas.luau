--!nonstrict
-- Formulas.luau
-- Pure math shared by server (authoritative) and client (display only).

local Config = require(script.Parent.Config)
local CloudlingData = require(script.Parent.CloudlingData)

local Formulas = {}

-- Catch price for a species with a given mutation.
function Formulas.CatchPrice(speciesId: string, mutation: string): number
	local s = CloudlingData.Get(speciesId)
	local m = CloudlingData.Mutations[mutation]
	if not s or not m then
		return math.huge
	end
	return math.floor(s.price * m.multiplier)
end

-- Base income before player-wide multipliers.
function Formulas.CloudlingIncome(speciesId: string, mutation: string, level: number): number
	local s = CloudlingData.Get(speciesId)
	local m = CloudlingData.Mutations[mutation]
	if not s or not m then
		return 0
	end
	local levelMult = 1 + 0.35 * (level - 1)
	return s.income * m.multiplier * levelMult
end

function Formulas.UpgradeCost(speciesId: string, mutation: string, level: number): number
	local price = Formulas.CatchPrice(speciesId, mutation)
	return math.floor(price * 0.35 * level ^ 1.25)
end

function Formulas.SellValue(speciesId: string, mutation: string, level: number): number
	local spent = Formulas.CatchPrice(speciesId, mutation)
	for l = 1, level - 1 do
		spent += Formulas.UpgradeCost(speciesId, mutation, l)
	end
	return math.floor(spent * Config.SellRefund)
end

-- Cost of the next pedestal; `owned` = slots unlocked so far.
function Formulas.SlotCost(owned: number): number
	local extra = owned - Config.StartingSlots
	return math.floor(500 * 3.2 ^ extra)
end

function Formulas.RebirthCost(rebirths: number): number
	return math.floor(Config.RebirthBaseCost * Config.RebirthCostGrowth ^ rebirths)
end

function Formulas.RebirthMultiplier(rebirths: number): number
	return 1 + Config.RebirthIncomeBonus * rebirths
end

-- Reward scaling: grants feel meaningful at every stage of progression.
function Formulas.ScaledReward(incomePerSecond: number, seconds: number, minimum: number): number
	return math.floor(math.max(minimum, incomePerSecond * seconds))
end

-- Number formatting ---------------------------------------------------------
local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

function Formulas.Format(n: number): string
	if n ~= n then
		return "0"
	end
	local negative = n < 0
	n = math.abs(n)
	if n < 1000 then
		local s = if n % 1 == 0 then tostring(n) else string.format("%.1f", n)
		return (negative and "-" or "") .. s
	end
	local tier = math.min(math.floor(math.log10(n) / 3), #SUFFIXES - 1)
	local scaled = n / 10 ^ (tier * 3)
	local text = if scaled >= 100 then string.format("%d", scaled) else string.format("%.1f", scaled)
	text = text:gsub("%.0$", "")
	return (negative and "-" or "") .. text .. SUFFIXES[tier + 1]
end

function Formulas.FormatTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local h = seconds // 3600
	local m = (seconds % 3600) // 60
	local s = seconds % 60
	if h > 0 then
		return string.format("%dh %02dm", h, m)
	end
	return string.format("%d:%02d", m, s)
end

-- UTC day number (used for daily quests / login streaks).
function Formulas.DayNumber(t: number?): number
	return math.floor((t or os.time()) / 86400)
end

return Formulas
