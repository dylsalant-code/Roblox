--!nonstrict
-- CommunityService.luau
-- Global "Community Goal": every Cloudling caught in every server counts.
-- Each milestone reached adds a permanent income boost for everyone, which
-- gives players a shared reason to play and to invite friends.
--
-- Catches are batched locally and flushed with one UpdateAsync every couple
-- of minutes to stay well inside DataStore limits.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local Remotes = require(Shared.Remotes)

local CommunityService = {}

local S: any
local store: DataStore? = nil
local pending = 0
local total = 0
local boost = 0
local loaded = false -- don't announce milestones reached before this server started
local announceRemote: RemoteEvent

local KEY = "GlobalCatches"

function CommunityService:Init(services)
	S = services
	announceRemote = Remotes.Get("Announce")
	local ok, result = pcall(DataStoreService.GetDataStore, DataStoreService, "Community_v1")
	if ok then
		store = result
	end
end

function CommunityService:AddCatch()
	pending += 1
	total += 1
	self:Recompute()
end

function CommunityService:GetBoost(): number
	return boost
end

function CommunityService:Recompute()
	local reached = 0
	local nextGoal = nil
	for _, m in Config.CommunityMilestones do
		if total >= m then
			reached += 1
		elseif not nextGoal then
			nextGoal = m
		end
	end
	local newBoost = reached * Config.CommunityBoostPerMilestone
	if newBoost > boost and loaded then
		announceRemote:FireAllClients({
			text = string.format("🌍 COMMUNITY GOAL REACHED! Everyone now earns +%d%% Sparkles!", newBoost * 100),
			color = Color3.fromRGB(90, 220, 255),
			kind = "milestone",
		})
	end
	boost = newBoost
	workspace:SetAttribute("CommunityTotal", total)
	workspace:SetAttribute("CommunityNextGoal", nextGoal or 0)
	workspace:SetAttribute("CommunityBoost", boost)
	self:Render(nextGoal)
end

function CommunityService:Render(nextGoal: number?)
	local list = S.MapService.Boards.Community
	if not list then
		return
	end
	local lbl = list:FindFirstChild("Status") :: TextLabel?
	if not lbl then
		local l = Instance.new("TextLabel")
		l.Name = "Status"
		l.BackgroundTransparency = 1
		l.Size = UDim2.fromScale(1, 1)
		l.Font = Enum.Font.FredokaOne
		l.TextScaled = true
		l.TextColor3 = Color3.new(1, 1, 1)
		l.Parent = list
		lbl = l
	end
	local goalText = if nextGoal
		then string.format("Next goal: %s catches\n→ +%d%% Sparkles for EVERYONE", Formulas.Format(nextGoal), (boost + Config.CommunityBoostPerMilestone) * 100)
		else "All goals reached! You're legends! 🎉"
	;(lbl :: TextLabel).Text = string.format("%s Cloudlings caught by all players\n\nCurrent bonus: +%d%%\n%s", Formulas.Format(total), boost * 100, goalText)
end

function CommunityService:Flush()
	if not store then
		return
	end
	local toAdd = pending
	pending = 0
	local ok, result = pcall(function()
		return (store :: DataStore):UpdateAsync(KEY, function(old)
			return (old or 0) + toAdd
		end)
	end)
	if ok and typeof(result) == "number" then
		total = math.max(total, result)
		self:Recompute()
		loaded = true
	else
		pending += toAdd -- retry next flush
	end
end

function CommunityService:Start()
	self:Recompute()
	task.spawn(function()
		self:Flush()
		while true do
			task.wait(Config.CommunityFlushInterval)
			self:Flush()
		end
	end)
	game:BindToClose(function()
		if pending > 0 then
			self:Flush()
		end
	end)
end

return CommunityService
