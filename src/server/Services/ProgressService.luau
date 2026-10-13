--!nonstrict
-- ProgressService.luau
-- Everything that makes players come back: daily quests, achievements, the
-- Cloudling Index, login streaks, offline earnings, rebirths and the
-- first-time tutorial. Also owns player-facing notifications.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local CloudlingData = require(Shared.CloudlingData)
local Formulas = require(Shared.Formulas)
local QuestData = require(Shared.QuestData)
local Remotes = require(Shared.Remotes)

local ProgressService = {}

local S: any
local notifyRemote: RemoteEvent
local announceRemote: RemoteEvent
local tutorialRemote: RemoteEvent
local effectRemote: RemoteEvent

-- Tutorial steps (index = data.tutorial). 99 = finished.
ProgressService.TUTORIAL_DONE = 99

function ProgressService:Init(services)
	S = services
	notifyRemote = Remotes.Get("Notify")
	announceRemote = Remotes.Get("Announce")
	tutorialRemote = Remotes.Get("Tutorial")
	effectRemote = Remotes.Get("Effect")
end

function ProgressService:Notify(player: Player, text: string, kind: string?)
	notifyRemote:FireClient(player, { text = text, kind = kind or "info" })
end

local function income(player: Player): number
	return S.PlotService:GetIncome(player, true)
end

-- Daily quests ---------------------------------------------------------------
function ProgressService:RefreshDaily(player: Player)
	local data = S.DataService:GetRaw(player)
	local today = Formulas.DayNumber()
	if data.daily.day == today then
		return
	end
	-- Deterministic per player per day, so rejoining can't reroll quests.
	local r = Random.new(today * 7919 + player.UserId % 100_003)
	local pool = table.clone(QuestData.Pool)
	local quests = {}
	local inc = income(player)
	for _ = 1, QuestData.DailyCount do
		local def = table.remove(pool, r:NextInteger(1, #pool)) :: QuestData.QuestDef
		local target = r:NextInteger(def.min, def.max)
		if def.scaleSeconds then
			target = Formulas.ScaledReward(inc, def.scaleSeconds, def.min)
		end
		table.insert(quests, {
			id = def.id,
			target = target,
			progress = 0,
			claimed = false,
			reward = Formulas.ScaledReward(inc, def.rewardSeconds, def.rewardMin),
		})
	end
	data.daily = { day = today, quests = quests, bonusClaimed = false }
	S.DataService:MarkDirty(player, true)
end

local function questDef(id: string): QuestData.QuestDef?
	for _, d in QuestData.Pool do
		if d.id == id then
			return d
		end
	end
	return nil
end

-- Progress events from gameplay: "Catch", "Collect", "Upgrade", ...
function ProgressService:Event(player: Player, event: string, amount: number)
	local data = S.DataService:GetRaw(player)
	if not data then
		return
	end
	if data.daily.day ~= Formulas.DayNumber() then
		self:RefreshDaily(player)
	end
	local changed = false
	for _, q in data.daily.quests do
		local def = questDef(q.id)
		if def and def.event == event and q.progress < q.target then
			q.progress = math.min(q.target, q.progress + amount)
			changed = true
			if q.progress >= q.target then
				self:Notify(player, "✅ Quest complete: " .. string.format(def.text, Formulas.Format(q.target)) .. " — claim it in Quests!", "success")
			end
		end
	end
	if changed then
		S.DataService:MarkDirty(player, event ~= "Collect" and event ~= "PlayMinute")
	end
end

function ProgressService:ClaimQuest(player: Player, index: number): (boolean, string?)
	local data = S.DataService:Get(player)
	local q = data and data.daily.quests[index]
	if not q then
		return false
	end
	if q.claimed then
		return false, "Already claimed."
	end
	if q.progress < q.target then
		return false, "Not finished yet!"
	end
	q.claimed = true
	S.DataService:AddSparkles(player, q.reward)
	local allDone = true
	for _, other in data.daily.quests do
		allDone = allDone and other.claimed
	end
	if allDone and not data.daily.bonusClaimed then
		data.daily.bonusClaimed = true
		local bonus = Formulas.ScaledReward(income(player), QuestData.AllCompleteBonusSeconds, QuestData.AllCompleteBonusMin)
		S.DataService:AddSparkles(player, bonus)
		self:Notify(player, "🌟 All daily quests done! Bonus +" .. Formulas.Format(bonus) .. " Sparkles!", "success")
	end
	S.DataService:MarkDirty(player, true)
	effectRemote:FireClient(player, "Reward", { amount = q.reward })
	return true, "+" .. Formulas.Format(q.reward) .. " Sparkles!"
end

-- Login streak -----------------------------------------------------------------
function ProgressService:UpdateLogin(player: Player)
	local data = S.DataService:GetRaw(player)
	local today = Formulas.DayNumber()
	local login = data.login
	if login.lastDay == today then
		return
	end
	if login.lastDay == today - 1 then
		login.streak += 1
	else
		login.streak = 1
	end
	login.lastDay = today
	data.stats.bestStreak = math.max(data.stats.bestStreak, login.streak)
end

function ProgressService:LoginRewardFor(player: Player): (number, any)
	local data = S.DataService:GetRaw(player)
	local day = ((data.login.streak - 1) % #QuestData.LoginRewards) + 1
	local def = QuestData.LoginRewards[day]
	return Formulas.ScaledReward(income(player), def.seconds, def.min), def
end

function ProgressService:ClaimLogin(player: Player): (boolean, string?)
	local data = S.DataService:Get(player)
	if not data then
		return false
	end
	local today = Formulas.DayNumber()
	if data.login.claimedDay == today then
		return false, "Come back tomorrow for your next reward!"
	end
	data.login.claimedDay = today
	local amount, def = self:LoginRewardFor(player)
	S.DataService:AddSparkles(player, amount)
	if def.boostMinutes then
		data.boostUntil = math.max(data.boostUntil, os.time()) + def.boostMinutes * 60
	end
	self:CheckAchievements(player)
	S.DataService:MarkDirty(player, true)
	effectRemote:FireClient(player, "Reward", { amount = amount })
	return true, "Day " .. data.login.streak .. " reward: +" .. Formulas.Format(amount) .. " Sparkles!" .. (if def.boostMinutes then " +15 min 2x Boost!" else "")
end

-- Achievements ---------------------------------------------------------------
function ProgressService:CheckAchievements(player: Player)
	local data = S.DataService:GetRaw(player)
	if not data then
		return
	end
	for _, a in QuestData.Achievements do
		if not data.achievements[a.id] then
			local value = if a.stat == "totalEarned" then data.totalEarned
				elseif a.stat == "rebirths" then data.rebirths
				else data.stats[a.stat] or 0
			if value >= a.goal then
				data.achievements[a.id] = true
				-- Achievement rewards are flat; don't count them toward goals.
				data.sparkles += a.reward
				self:Notify(player, "🏆 Achievement unlocked: " .. a.name .. "! +" .. Formulas.Format(a.reward), "achievement")
				S.DataService:MarkDirty(player, true)
			end
		end
	end
end

-- Catch hook (stats, index, quests, announcements) ----------------------------
function ProgressService:OnCatch(player: Player, speciesId: string, mutation: string)
	local data = S.DataService:Get(player)
	local species = CloudlingData.Get(speciesId) :: CloudlingData.Species
	local rarity = CloudlingData.Rarities[species.rarity]
	data.stats.caught += 1
	self:Event(player, "Catch", 1)
	if rarity.order >= 3 then
		data.stats.rareCaught += 1
		self:Event(player, "CatchRare", 1)
	end
	if mutation ~= "None" then
		data.stats.mutationsCaught += 1
		self:Event(player, "CatchMutation", 1)
	end
	if species.rarity == "Secret" then
		data.stats.secretsCaught += 1
	end
	if S.WeatherService:GetWeather() then
		self:Event(player, "CatchWeather", 1)
	end

	local key = CloudlingData.IndexKey(speciesId, mutation)
	if not data.index[key] then
		data.index[key] = true
		data.stats.discovered += 1
		local bonus = math.max(10, math.floor(Formulas.CatchPrice(speciesId, mutation) * 0.1))
		S.DataService:AddSparkles(player, bonus)
		self:Notify(player, "📖 NEW Index entry: " .. (if mutation ~= "None" then mutation .. " " else "") .. species.name .. "! +" .. Formulas.Format(bonus), "achievement")
	end

	S.CommunityService:AddCatch()
	self:CheckAchievements(player)
	self:TutorialAdvance(player, 0)

	if rarity.announce or mutation ~= "None" then
		announceRemote:FireAllClients({
			text = string.format("%s caught a %s %s%s!", player.DisplayName, species.rarity:upper(), if mutation ~= "None" then mutation .. " " else "", species.name),
			color = if mutation ~= "None" then CloudlingData.Mutations[mutation].color else rarity.color,
			kind = "catch",
		})
	end
	S.DataService:MarkDirty(player, true)
end

-- Rebirth ----------------------------------------------------------------------
function ProgressService:Rebirth(player: Player): (boolean, string?)
	local data = S.DataService:Get(player)
	if not data then
		return false
	end
	local cost = Formulas.RebirthCost(data.rebirths)
	if data.sparkles < cost then
		return false, "You need ✨" .. Formulas.Format(cost) .. " to rebirth."
	end
	for _, c in data.cloudlings do
		S.PlotService:RemoveModel(player, c.slot)
	end
	data.cloudlings = {}
	data.sparkles = Config.StartingSparkles
	data.rebirths += 1
	S.PlotService:RefreshAllPedestals(player)
	self:CheckAchievements(player)
	S.DataService:MarkDirty(player, true)
	S.LeaderboardService:UpdateStats(player)
	announceRemote:FireAllClients({
		text = string.format("🔁 %s reached Rebirth %d! (x%s income)", player.DisplayName, data.rebirths, Formulas.Format(Formulas.RebirthMultiplier(data.rebirths))),
		color = Color3.fromRGB(170, 130, 255),
		kind = "rebirth",
	})
	effectRemote:FireAllClients("Rebirth", { userId = player.UserId })
	return true, "Reborn! Your Cloudlings now earn x" .. Formulas.Format(Formulas.RebirthMultiplier(data.rebirths)) .. " forever."
end

-- Tutorial -----------------------------------------------------------------------
function ProgressService:SendTutorial(player: Player)
	local data = S.DataService:GetRaw(player)
	tutorialRemote:FireClient(player, data.tutorial)
end

-- Advances only if the player is currently on `fromStep`.
function ProgressService:TutorialAdvance(player: Player, fromStep: number)
	local data = S.DataService:GetRaw(player)
	if not data or data.tutorial ~= fromStep then
		return
	end
	data.tutorial = if fromStep >= 3 then self.TUTORIAL_DONE else fromStep + 1
	self:SendTutorial(player)
	S.DataService:MarkDirty(player, true)
end

function ProgressService:SkipTutorial(player: Player)
	local data = S.DataService:GetRaw(player)
	if data then
		data.tutorial = self.TUTORIAL_DONE
		self:SendTutorial(player)
		S.DataService:MarkDirty(player, true)
	end
end

-- Join flow ------------------------------------------------------------------------
function ProgressService:OnJoin(player: Player)
	local data = S.DataService:GetRaw(player)
	self:UpdateLogin(player)
	self:RefreshDaily(player)

	-- Offline earnings (never on the very first visit).
	if data.lastOnline > 0 then
		local away = math.min(os.time() - data.lastOnline, Config.OfflineEarningsCapSeconds)
		local amount = math.floor(away * income(player) * Config.OfflineEarningsRate)
		if away > 60 and amount > 0 then
			S.DataService:AddSparkles(player, amount)
			task.delay(4, function()
				self:Notify(player, string.format("☁ Welcome back! Your Cloudlings saved ✨%s while you were away.", Formulas.Format(amount)), "success")
			end)
		end
	end
	data.lastOnline = os.time()
	self:SendTutorial(player)
	self:CheckAchievements(player)
end

function ProgressService:Start()
	-- "Play X minutes" quests + midnight rollover.
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in Players:GetPlayers() do
				if S.DataService:IsReady(player) then
					self:Event(player, "PlayMinute", 1)
					local data = S.DataService:Get(player)
					if data.daily.day ~= Formulas.DayNumber() then
						self:UpdateLogin(player)
						self:RefreshDaily(player)
					end
				end
			end
		end
	end)
end

return ProgressService
