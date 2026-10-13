--!nonstrict
-- PlotService.luau
-- Owns island assignment, pedestals, owned Cloudling models, the income tick
-- and Sparkle collection. All economy math happens here, server-side.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local CloudlingData = require(Shared.CloudlingData)
local CloudlingModel = require(Shared.CloudlingModel)
local Remotes = require(Shared.Remotes)

local PlotService = {}

local S: any
local effectRemote: RemoteEvent
local plotOf: { [Player]: any } = {} -- Player -> MapService plot
local models: { [Player]: { [number]: Model } } = {}
local friendBoost: { [Player]: number } = {}
local lastCollect: { [Player]: number } = {}
local sessionLikes: { [Player]: { [number]: boolean } } = {}

function PlotService:Init(services)
	S = services
	effectRemote = Remotes.Get("Effect")
end

-- Queries --------------------------------------------------------------------
function PlotService:GetPlot(player: Player)
	return plotOf[player]
end

function PlotService:GetPlotIndex(player: Player): number?
	local p = plotOf[player]
	return p and p.index
end

function PlotService:TotalSlots(player: Player): number
	local data = S.DataService:GetRaw(player)
	if not data then
		return 0
	end
	local bonus = if S.MarketService:HasPass(player, "BiggerIsland") then Config.PassBonusSlots else 0
	return math.min(data.slots + bonus, Config.MaxTotalSlots)
end

function PlotService:GetMultiplierBreakdown(player: Player)
	local data = S.DataService:GetRaw(player)
	local rebirth = Formulas.RebirthMultiplier(data and data.rebirths or 0)
	local vip = if S.MarketService:HasPass(player, "VIP") then 0.1 else 0
	local friends = friendBoost[player] or 0
	local community = S.CommunityService:GetBoost()
	local double = if S.MarketService:HasPass(player, "DoubleSparkles") then 2 else 1
	local boost = if data and data.boostUntil > os.time() then 2 else 1
	return {
		rebirth = rebirth,
		vip = vip,
		friends = friends,
		community = community,
		double = double,
		boost = boost,
		total = rebirth * (1 + vip + friends + community) * double * boost,
	}
end

function PlotService:GetMultiplier(player: Player): number
	return self:GetMultiplierBreakdown(player).total
end

-- Income per second including every multiplier.
function PlotService:GetIncome(player: Player, withoutBoosts: boolean?): number
	local data = S.DataService:GetRaw(player)
	if not data then
		return 0
	end
	local base = 0
	for _, c in data.cloudlings do
		base += Formulas.CloudlingIncome(c.id, c.mut, c.lvl)
	end
	if withoutBoosts then
		return base * Formulas.RebirthMultiplier(data.rebirths)
	end
	return base * self:GetMultiplier(player)
end

function PlotService:FindCloudling(player: Player, slot: number)
	local data = S.DataService:GetRaw(player)
	if not data then
		return nil
	end
	for i, c in data.cloudlings do
		if c.slot == slot then
			return c, i
		end
	end
	return nil
end

function PlotService:FreeSlot(player: Player): number?
	local total = self:TotalSlots(player)
	for slot = 1, total do
		if not self:FindCloudling(player, slot) then
			return slot
		end
	end
	return nil
end

-- Visuals ---------------------------------------------------------------------
function PlotService:RefreshPedestal(player: Player, slot: number)
	local plot = plotOf[player]
	local data = S.DataService:GetRaw(player)
	if not plot or not data then
		return
	end
	local pedestal = plot.pedestals[slot]
	local total = self:TotalSlots(player)
	local c = self:FindCloudling(player, slot)
	local state
	if c then
		state = "Occupied"
	elseif slot <= total then
		state = "Empty"
	elseif slot == total + 1 and data.slots < Config.MaxPurchasableSlots then
		state = "Next"
	else
		state = "Locked"
	end
	pedestal:SetAttribute("State", state)
	pedestal:SetAttribute("Stored", if c then math.floor(c.stored or 0) else 0)
	pedestal.Transparency = if state == "Locked" then 0.7 elseif state == "Next" then 0.4 else 0
	pedestal:SetAttribute("Cost", if state == "Next" then Formulas.SlotCost(data.slots) else 0)
	if c then
		pedestal:SetAttribute("UpgradeCost", if c.lvl < Config.MaxLevel then Formulas.UpgradeCost(c.id, c.mut, c.lvl) else 0)
		pedestal:SetAttribute("SellValue", Formulas.SellValue(c.id, c.mut, c.lvl))
	end
end

function PlotService:RefreshAllPedestals(player: Player)
	local plot = plotOf[player]
	if not plot then
		return
	end
	for slot = 1, #plot.pedestals do
		self:RefreshPedestal(player, slot)
	end
end

local function updateModelLabel(model: Model, c: any, player: Player)
	local detail = model:FindFirstChild("Detail", true) :: TextLabel?
	if detail then
		local income = Formulas.CloudlingIncome(c.id, c.mut, c.lvl) * PlotService:GetMultiplier(player)
		detail.Text = string.format("Lv.%d  •  +%s/s", c.lvl, Formulas.Format(math.floor(income)))
	end
end

function PlotService:SpawnModel(player: Player, c: any)
	local plot = plotOf[player]
	if not plot then
		return
	end
	local pedestal = plot.pedestals[c.slot]
	if not pedestal then
		return
	end
	models[player] = models[player] or {}
	local old = models[player][c.slot]
	if old then
		old:Destroy()
	end
	local model = CloudlingModel.Build(c.id, c.mut)
	local species = CloudlingData.Get(c.id) :: CloudlingData.Species
	local pos = pedestal.Position + Vector3.new(0, 0.8 + species.size * 0.8, 0)
	-- Face the island entrance so owners see their Cloudlings' faces.
	model:PivotTo(CFrame.lookAt(pos, pos + plot.cframe.LookVector))
	local _, _, detail = CloudlingModel.MakeBillboard(model.PrimaryPart :: BasePart, c.id, c.mut, species.size * 0.6 + 2)
	detail.Name = "Detail"
	model:SetAttribute("OwnerId", player.UserId)
	model:SetAttribute("Slot", c.slot)
	CollectionService:AddTag(model, "OwnedCloudling")
	model.Parent = plot.folder
	models[player][c.slot] = model
	updateModelLabel(model, c, player)
end

function PlotService:RefreshLabels(player: Player)
	local data = S.DataService:GetRaw(player)
	if not data or not models[player] then
		return
	end
	for _, c in data.cloudlings do
		local m = models[player][c.slot]
		if m then
			updateModelLabel(m, c, player)
		end
	end
end

function PlotService:RemoveModel(player: Player, slot: number)
	local m = models[player] and models[player][slot]
	if m then
		m:Destroy()
		models[player][slot] = nil
	end
end

-- Plot lifecycle ----------------------------------------------------------------
function PlotService:TeleportHome(player: Player)
	local plot = plotOf[player]
	local character = player.Character
	if plot and character then
		S.AntiCheatService:Grace(player, 3)
		character:PivotTo(plot.spawn)
	end
end

local function updateSign(player: Player)
	local plot = plotOf[player]
	local data = S.DataService:GetRaw(player)
	if plot and data then
		plot.ownerLabel.Text = player.DisplayName .. "'s Island"
		plot.likesLabel.Text = "❤ " .. Formulas.Format(data.stats.likesReceived) .. " likes"
	end
end

function PlotService:Assign(player: Player): boolean
	local chosen
	for _, plot in S.MapService.Plots do
		if not plot.owner then
			chosen = plot
			break
		end
	end
	if not chosen then
		return false
	end
	chosen.owner = player
	plotOf[player] = chosen
	chosen.folder:SetAttribute("OwnerId", player.UserId)
	chosen.likePrompt.Enabled = true
	chosen.likePrompt.ObjectText = player.DisplayName .. "'s Island"
	updateSign(player)

	local data = S.DataService:GetRaw(player)
	for _, c in data.cloudlings do
		c.stored = c.stored or 0
		self:SpawnModel(player, c)
	end
	self:RefreshAllPedestals(player)

	player.CharacterAdded:Connect(function(character)
		task.defer(function()
			if plotOf[player] then
				character:WaitForChild("HumanoidRootPart", 5)
				self:TeleportHome(player)
			end
		end)
	end)
	if player.Character then
		self:TeleportHome(player)
	end
	return true
end

-- Converts what's sitting on pedestals into the save before leaving.
function PlotService:BakeStored(player: Player)
	-- Stored values already live inside data.cloudlings; nothing to convert,
	-- but keep the hook so future stored-state can be flushed here.
	local _ = player
end

function PlotService:Release(player: Player)
	local plot = plotOf[player]
	if plot then
		local owned = models[player]
		if owned then
			for _, m in owned do
				m:Destroy()
			end
		end
		plot.owner = nil
		plot.folder:SetAttribute("OwnerId", nil)
		plot.ownerLabel.Text = "Empty Island"
		plot.likesLabel.Text = ""
		plot.likePrompt.Enabled = false
		for _, pedestal in plot.pedestals do
			pedestal:SetAttribute("State", "Locked")
			pedestal:SetAttribute("Stored", 0)
			pedestal.Transparency = 0.7
		end
	end
	plotOf[player] = nil
	models[player] = nil
	friendBoost[player] = nil
	lastCollect[player] = nil
	sessionLikes[player] = nil
	for _, likes in sessionLikes do
		likes[player.UserId] = nil
	end
end

-- Actions -----------------------------------------------------------------------
-- Adds a Cloudling to the first free pedestal. Returns the slot or nil.
function PlotService:AddCloudling(player: Player, speciesId: string, mutation: string): number?
	local data = S.DataService:Get(player)
	local slot = self:FreeSlot(player)
	if not data or not slot then
		return nil
	end
	local c = { slot = slot, id = speciesId, mut = mutation, lvl = 1, stored = 0 }
	table.insert(data.cloudlings, c)
	self:SpawnModel(player, c)
	self:RefreshPedestal(player, slot)
	S.DataService:MarkDirty(player, true)
	return slot
end

function PlotService:PedestalPosition(player: Player, slot: number): Vector3?
	local plot = plotOf[player]
	local p = plot and plot.pedestals[slot]
	return p and p.Position
end

local function nearPedestal(player: Player, slot: number, range: number): boolean
	local pos = PlotService:PedestalPosition(player, slot)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return pos ~= nil and root ~= nil and (root.Position - pos).Magnitude <= range
end

function PlotService:Upgrade(player: Player, slot: number): (boolean, string?)
	local c = self:FindCloudling(player, slot)
	if not c then
		return false, "No Cloudling there!"
	end
	if not nearPedestal(player, slot, 20) then
		return false, "Get closer to your Cloudling."
	end
	if c.lvl >= Config.MaxLevel then
		return false, "Already max level!"
	end
	local cost = Formulas.UpgradeCost(c.id, c.mut, c.lvl)
	if not S.DataService:SpendSparkles(player, cost) then
		return false, "Not enough Sparkles."
	end
	c.lvl += 1
	local data = S.DataService:Get(player)
	data.stats.upgrades += 1
	S.ProgressService:Event(player, "Upgrade", 1)
	S.ProgressService:CheckAchievements(player)
	S.ProgressService:TutorialAdvance(player, 2)
	self:RefreshPedestal(player, slot)
	local m = models[player] and models[player][slot]
	if m then
		updateModelLabel(m, c, player)
	end
	effectRemote:FireAllClients("LevelUp", { position = self:PedestalPosition(player, slot), level = c.lvl })
	S.DataService:MarkDirty(player, true)
	return true
end

function PlotService:ReleaseCloudling(player: Player, slot: number): (boolean, string?)
	local c, i = self:FindCloudling(player, slot)
	if not c then
		return false, "No Cloudling there!"
	end
	if not nearPedestal(player, slot, 20) then
		return false, "Get closer to your Cloudling."
	end
	local data = S.DataService:Get(player)
	local value = Formulas.SellValue(c.id, c.mut, c.lvl) + math.floor(c.stored or 0)
	table.remove(data.cloudlings, i)
	self:RemoveModel(player, slot)
	S.DataService:AddSparkles(player, value, false)
	self:RefreshPedestal(player, slot)
	S.DataService:MarkDirty(player, true)
	return true, "Released for " .. Formulas.Format(value) .. " Sparkles. Bye bye! 👋"
end

function PlotService:UnlockSlot(player: Player): (boolean, string?)
	local data = S.DataService:Get(player)
	if not data then
		return false
	end
	if data.slots >= Config.MaxPurchasableSlots then
		return false, "All pedestals unlocked!"
	end
	local cost = Formulas.SlotCost(data.slots)
	if not S.DataService:SpendSparkles(player, cost) then
		return false, "Not enough Sparkles."
	end
	data.slots += 1
	self:RefreshAllPedestals(player)
	S.DataService:MarkDirty(player, true)
	return true, "New pedestal unlocked! 🏝️"
end

function PlotService:Collect(player: Player)
	local data = S.DataService:Get(player)
	if not data then
		return
	end
	local total = 0
	for _, c in data.cloudlings do
		total += c.stored or 0
		c.stored = 0
	end
	total = math.floor(total)
	if total <= 0 then
		return
	end
	S.DataService:AddSparkles(player, total)
	data.stats.collected += total
	S.ProgressService:Event(player, "Collect", total)
	S.ProgressService:TutorialAdvance(player, 1)
	self:RefreshAllPedestals(player)
	local plot = plotOf[player]
	effectRemote:FireClient(player, "Collect", { amount = total, position = plot and plot.collectPad.Position })
end

-- Social -------------------------------------------------------------------------
function PlotService:Like(liker: Player, plot: any)
	local owner = plot.owner
	if not owner or owner == liker then
		return
	end
	sessionLikes[liker] = sessionLikes[liker] or {}
	if sessionLikes[liker][owner.UserId] then
		S.ProgressService:Notify(liker, "You already liked this island today! ❤", "info")
		return
	end
	local ownerData = S.DataService:Get(owner)
	local likerData = S.DataService:Get(liker)
	if not ownerData or not likerData then
		return
	end
	sessionLikes[liker][owner.UserId] = true
	ownerData.stats.likesReceived += 1
	likerData.stats.likesGiven += 1
	updateSign(owner)
	S.ProgressService:Event(liker, "LikeGiven", 1)
	S.ProgressService:CheckAchievements(owner)
	S.ProgressService:Notify(liker, "You liked " .. owner.DisplayName .. "'s island! ❤", "success")
	S.ProgressService:Notify(owner, liker.DisplayName .. " liked your island! ❤", "success")
	effectRemote:FireAllClients("Hearts", { position = plot.likePrompt.Parent.WorldPosition })
	S.LeaderboardService:UpdateStats(owner)
	S.DataService:MarkDirty(owner, true)
	S.DataService:MarkDirty(liker, true)
end

-- Friend boost: +10% per friend in the same server (max 30%).
function PlotService:RecomputeFriendBoosts()
	local list = Players:GetPlayers()
	for _, p in list do
		local count = 0
		for _, other in list do
			if other ~= p then
				local ok, isFriend = pcall(p.IsFriendsWith, p, other.UserId)
				if ok and isFriend then
					count += 1
				end
			end
		end
		local boost = math.min(count * Config.FriendBoostPerFriend, Config.FriendBoostMax)
		if friendBoost[p] ~= boost then
			friendBoost[p] = boost
			if boost > 0 then
				S.ProgressService:Notify(p, string.format("👯 Friend Boost: +%d%% Sparkles!", boost * 100), "success")
			end
			S.DataService:MarkDirty(p, true)
		end
	end
end

-- Main loops ---------------------------------------------------------------------
function PlotService:Start()
	for _, plot in S.MapService.Plots do
		plot.collectPad.Touched:Connect(function(hit)
			local character = hit.Parent
			local player = character and Players:GetPlayerFromCharacter(character)
			if player and plot.owner == player then
				local now = os.clock()
				if now - (lastCollect[player] or 0) > 0.6 then
					lastCollect[player] = now
					self:Collect(player)
				end
			end
		end)
		plot.likePrompt.Triggered:Connect(function(player)
			self:Like(player, plot)
		end)
	end

	-- Falling into the cloud sea bounces you home instead of killing you.
	local seaCooldown: { [Player]: number } = {}
	S.MapService.CloudSea.Touched:Connect(function(hit)
		local player = hit.Parent and Players:GetPlayerFromCharacter(hit.Parent)
		if player and os.clock() - (seaCooldown[player] or 0) > 1 then
			seaCooldown[player] = os.clock()
			effectRemote:FireClient(player, "Splash", {})
			if plotOf[player] then
				self:TeleportHome(player)
			else
				S.AntiCheatService:Grace(player, 3)
				hit.Parent:PivotTo(CFrame.new(0, 5, -15))
			end
		end
	end)

	-- VIP lounge pad.
	local vipCooldown: { [Player]: number } = {}
	S.MapService.VipPad.Touched:Connect(function(hit)
		local player = hit.Parent and Players:GetPlayerFromCharacter(hit.Parent)
		if not player or os.clock() - (vipCooldown[player] or 0) < 2 then
			return
		end
		vipCooldown[player] = os.clock()
		if S.MarketService:HasPass(player, "VIP") then
			S.AntiCheatService:Grace(player, 3)
			hit.Parent:PivotTo(S.MapService.VipLoungeSpawn)
		else
			S.ProgressService:Notify(player, "👑 The cloud lounge is for VIPs. Check the Shop if you'd like to support the game!", "info")
		end
	end)

	-- Income tick
	task.spawn(function()
		local labelTimer = 0
		while true do
			local dt = task.wait(Config.IncomeTickInterval)
			labelTimer += dt
			for player, plot in plotOf do
				local data = S.DataService:Get(player)
				if data then
					local mult = self:GetMultiplier(player)
					local auto = S.MarketService:HasPass(player, "AutoCollect")
					local autoTotal = 0
					for _, c in data.cloudlings do
						local gain = Formulas.CloudlingIncome(c.id, c.mut, c.lvl) * mult * dt
						if auto then
							autoTotal += gain
						else
							c.stored = (c.stored or 0) + gain
							local pedestal = plot.pedestals[c.slot]
							if pedestal then
								pedestal:SetAttribute("Stored", math.floor(c.stored))
							end
						end
					end
					if autoTotal > 0 then
						S.DataService:AddSparkles(player, autoTotal)
						data.stats.collected += autoTotal
						S.ProgressService:Event(player, "Collect", autoTotal)
						S.ProgressService:TutorialAdvance(player, 1)
					end
					data.stats.playSeconds += dt
					if labelTimer >= 5 then
						self:RefreshLabels(player)
					end
				end
			end
			if labelTimer >= 5 then
				labelTimer = 0
			end
		end
	end)

	Players.PlayerAdded:Connect(function()
		task.delay(3, self.RecomputeFriendBoosts, self)
	end)
	Players.PlayerRemoving:Connect(function()
		task.delay(1, self.RecomputeFriendBoosts, self)
	end)
end

return PlotService
