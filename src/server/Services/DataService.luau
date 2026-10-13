--!nonstrict
-- DataService.luau
-- Loads, saves and replicates player data.
--
-- * Session locking: every save stamps { jobId, time }. A second server that
--   sees a fresh lock waits and retries, preventing item duplication when a
--   player hops servers quickly. Stale locks (server crashed) expire.
-- * Data is reconciled against a default template so new fields appear for
--   old saves automatically.
-- * If DataStores are unavailable in Studio, the game still runs with
--   in-memory data (nothing is saved) so you can play-test immediately.
--   In a live server a failed load kicks the player instead of risking a
--   blank profile overwriting real progress.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local Remotes = require(Shared.Remotes)

local DataService = {}

type Profile = {
	data: any,
	ready: boolean,
	canSave: boolean,
	dirtyLight: boolean,
	dirtyFull: boolean,
	lastSave: number,
}

local profiles: { [Player]: Profile } = {}
local store: DataStore? = nil
local S: any
local stateSync: RemoteEvent

local LOCK_EXPIRY = 600 -- seconds before an abandoned session lock is ignored
local JOB_ID = if game.JobId ~= "" then game.JobId else "studio-" .. HttpService:GenerateGUID(false)

local function defaultData()
	return {
		version = Config.DataVersion,
		sparkles = Config.StartingSparkles,
		totalEarned = 0,
		rebirths = 0,
		slots = Config.StartingSlots,
		cloudlings = {}, -- array of { slot, id, mut, lvl, stored }
		index = {}, -- [speciesId:mutation] = true
		stats = {
			caught = 0,
			rareCaught = 0,
			mutationsCaught = 0,
			secretsCaught = 0,
			discovered = 0,
			upgrades = 0,
			collected = 0,
			likesGiven = 0,
			likesReceived = 0,
			playSeconds = 0,
			bestStreak = 0,
			robuxSpent = 0,
		},
		achievements = {},
		daily = { day = -1, quests = {}, bonusClaimed = false },
		login = { lastDay = -1, streak = 0, claimedDay = -1 },
		tutorial = 0,
		lastOnline = 0,
		boostUntil = 0,
		receipts = {}, -- [purchaseId] = os.time()
		settings = { music = true, sfx = true, trail = true },
	}
end

-- Copies missing keys from the template into `data` (recursively).
local function reconcile(data: any, template: any)
	for k, v in template do
		if data[k] == nil then
			data[k] = if type(v) == "table" then table.clone(v) else v
		elseif type(v) == "table" and type(data[k]) == "table" and next(v) ~= nil then
			reconcile(data[k], v)
		end
	end
end

local function migrate(data: any)
	-- Future schema changes go here, keyed on data.version.
	data.version = Config.DataVersion
end

function DataService:Init(services)
	S = services
	stateSync = Remotes.Get("StateSync")
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStores unavailable:", result)
	end
end

local function keyFor(player: Player): string
	return "u_" .. player.UserId
end

-- Attempts to claim the session lock and read the save. Returns
-- (success, data, lockedElsewhere).
local function tryLoad(player: Player, force: boolean): (boolean, any, boolean)
	if not store then
		return false, nil, false
	end
	local loaded, locked = nil, false
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(keyFor(player), function(old)
			if old and old.lock and old.lock.job ~= JOB_ID and os.time() - (old.lock.time or 0) < LOCK_EXPIRY and not force then
				locked = true
				return nil -- cancel the write
			end
			loaded = if old and old.data then old.data else defaultData()
			return { data = loaded, lock = { job = JOB_ID, time = os.time() } }
		end)
	end)
	if not ok then
		warn("[DataService] Load failed for", player.Name, err)
		return false, nil, false
	end
	return not locked, loaded, locked
end

-- Loads a profile. Yields. Returns the data table or nil if the player left
-- or was kicked.
function DataService:Load(player: Player): any
	local data, canSave = nil, true
	for attempt = 1, 6 do
		local ok, result, locked = tryLoad(player, attempt == 6)
		if ok then
			data = result
			break
		end
		if not locked and (attempt >= 3 or RunService:IsStudio()) then
			break
		end
		if not player.Parent then
			return nil
		end
		task.wait(if locked then 5 else 2)
	end

	if not data then
		if RunService:IsStudio() then
			warn("[DataService] Using temporary data (enable Studio API access to test saving).")
			data = defaultData()
			canSave = false
		else
			player:Kick("We couldn't load your Cloudlings safely. Please rejoin in a moment!")
			return nil
		end
	end

	reconcile(data, defaultData())
	migrate(data)
	profiles[player] = {
		data = data,
		ready = false,
		canSave = canSave,
		dirtyLight = false,
		dirtyFull = true,
		lastSave = os.clock(),
	}
	if not player.Parent then
		-- Left while loading: hand the session lock back immediately.
		self:Release(player)
		return nil
	end
	return data
end

function DataService:SetReady(player: Player)
	local p = profiles[player]
	if p then
		p.ready = true
		p.dirtyFull = true
	end
end

function DataService:Get(player: Player): any
	local p = profiles[player]
	return if p and p.ready then p.data else nil
end

-- Like Get but available before the player finishes joining.
function DataService:GetRaw(player: Player): any
	local p = profiles[player]
	return p and p.data
end

function DataService:IsReady(player: Player): boolean
	local p = profiles[player]
	return p ~= nil and p.ready
end

function DataService:MarkDirty(player: Player, full: boolean?)
	local p = profiles[player]
	if not p then
		return
	end
	if full then
		p.dirtyFull = true
	else
		p.dirtyLight = true
	end
end

-- Currency ------------------------------------------------------------------
-- `countsAsEarned` = false for purchased packs so leaderboards stay fair.
function DataService:AddSparkles(player: Player, amount: number, countsAsEarned: boolean?)
	local data = self:GetRaw(player)
	if not data or amount ~= amount or amount <= 0 or amount == math.huge then
		return
	end
	data.sparkles += amount
	if countsAsEarned ~= false then
		data.totalEarned += amount
	end
	self:MarkDirty(player)
	S.LeaderboardService:UpdateStats(player)
end

function DataService:SpendSparkles(player: Player, amount: number): boolean
	local data = self:Get(player)
	if not data or amount ~= amount or amount < 0 or data.sparkles < amount then
		return false
	end
	data.sparkles -= amount
	self:MarkDirty(player)
	S.LeaderboardService:UpdateStats(player)
	return true
end

-- Saving --------------------------------------------------------------------
function DataService:Save(player: Player, release: boolean?): boolean
	local p = profiles[player]
	if not p then
		return false
	end
	p.data.lastOnline = os.time()
	if not p.canSave or not store then
		return true
	end
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(keyFor(player), function(old)
			if old and old.lock and old.lock.job ~= JOB_ID and os.time() - (old.lock.time or 0) < LOCK_EXPIRY then
				return nil -- another server took over; never clobber it
			end
			return {
				data = p.data,
				lock = if release then nil else { job = JOB_ID, time = os.time() },
			}
		end)
	end)
	if not ok then
		warn("[DataService] Save failed for", player.Name, err)
	end
	p.lastSave = os.clock()
	return ok
end

function DataService:Release(player: Player)
	if profiles[player] then
		self:Save(player, true)
		profiles[player] = nil
	end
end

-- Replication ---------------------------------------------------------------
function DataService:BuildSnapshot(player: Player, full: boolean): any
	local data = profiles[player].data
	local income = S.PlotService:GetIncome(player)
	local snap: any = {
		sparkles = data.sparkles,
		totalEarned = data.totalEarned,
		income = income,
		boostUntil = data.boostUntil,
		serverTime = os.time(),
	}
	if full then
		snap.full = true
		snap.rebirths = data.rebirths
		snap.slots = data.slots
		snap.totalSlots = S.PlotService:TotalSlots(player)
		snap.cloudlings = data.cloudlings
		snap.index = data.index
		snap.stats = data.stats
		snap.achievements = data.achievements
		snap.daily = data.daily
		snap.login = data.login
		snap.today = Formulas.DayNumber()
		snap.tutorial = data.tutorial
		snap.settings = data.settings
		snap.passes = S.MarketService:GetPasses(player)
		snap.multipliers = S.PlotService:GetMultiplierBreakdown(player)
		snap.plotIndex = S.PlotService:GetPlotIndex(player)
	end
	return snap
end

function DataService:Start()
	-- Replication loop: batch changes into at most 5 messages per second.
	task.spawn(function()
		while true do
			task.wait(0.2)
			for player, p in profiles do
				if p.ready and (p.dirtyFull or p.dirtyLight) then
					local full = p.dirtyFull
					p.dirtyFull, p.dirtyLight = false, false
					local ok, snap = pcall(self.BuildSnapshot, self, player, full)
					if ok then
						stateSync:FireClient(player, snap)
					else
						warn("[DataService] Snapshot failed:", snap)
					end
				end
			end
		end
	end)

	-- Autosave loop (staggered so we don't burst the DataStore budget).
	task.spawn(function()
		while true do
			task.wait(10)
			for player, p in profiles do
				if p.ready and os.clock() - p.lastSave > Config.AutosaveInterval then
					task.spawn(self.Save, self, player)
				end
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				S.PlotService:BakeStored(player)
				self:Save(player, true)
				pending -= 1
			end)
		end
		local start = os.clock()
		while pending > 0 and os.clock() - start < 25 do
			task.wait(0.1)
		end
	end)
	-- PlayerRemoving is orchestrated in Main so plots bake before saving.
end

return DataService
