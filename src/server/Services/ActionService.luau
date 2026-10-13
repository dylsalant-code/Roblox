--!nonstrict
-- ActionService.luau
-- The only client->server entry point. Every request is:
--   1. rate limited (token bucket per player),
--   2. type-checked (never trust client payloads),
--   3. dispatched to the owning service which re-validates game rules.
-- Results come back as toast notifications.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local ActionService = {}

local S: any
local buckets: { [Player]: { tokens: number, last: number } } = {}

local function allow(player: Player): boolean
	local now = os.clock()
	local b = buckets[player]
	if not b then
		b = { tokens = Config.ActionBurst, last = now }
		buckets[player] = b
	end
	b.tokens = math.min(Config.ActionBurst, b.tokens + (now - b.last) * Config.ActionRate)
	b.last = now
	if b.tokens < 1 then
		return false
	end
	b.tokens -= 1
	return true
end

local function isInt(v: any, lo: number, hi: number): boolean
	return type(v) == "number" and v == v and v % 1 == 0 and v >= lo and v <= hi
end

local function isShortString(v: any): boolean
	return type(v) == "string" and #v > 0 and #v <= 40
end

-- Each handler returns (ok, message?) — message is shown as a toast.
local handlers: { [string]: (Player, any) -> (boolean, string?) } = {
	Catch = function(player, p)
		if not isInt(p.id, 1, 2 ^ 31) then
			return false
		end
		return S.StreamService:TryCatch(player, p.id)
	end,
	Upgrade = function(player, p)
		if not isInt(p.slot, 1, Config.MaxTotalSlots) then
			return false
		end
		return S.PlotService:Upgrade(player, p.slot)
	end,
	Release = function(player, p)
		if not isInt(p.slot, 1, Config.MaxTotalSlots) then
			return false
		end
		return S.PlotService:ReleaseCloudling(player, p.slot)
	end,
	UnlockSlot = function(player)
		return S.PlotService:UnlockSlot(player)
	end,
	Rebirth = function(player)
		return S.ProgressService:Rebirth(player)
	end,
	ClaimQuest = function(player, p)
		if not isInt(p.index, 1, 10) then
			return false
		end
		return S.ProgressService:ClaimQuest(player, p.index)
	end,
	ClaimLogin = function(player)
		return S.ProgressService:ClaimLogin(player)
	end,
	SkipTutorial = function(player)
		S.ProgressService:SkipTutorial(player)
		return true
	end,
	GoHome = function(player)
		S.PlotService:TeleportHome(player)
		return true
	end,
	Setting = function(player, p)
		local data = S.DataService:Get(player)
		if not data or not isShortString(p.key) or type(p.value) ~= "boolean" then
			return false
		end
		if data.settings[p.key] == nil then
			return false
		end
		data.settings[p.key] = p.value
		S.DataService:MarkDirty(player, true)
		return true
	end,
	TestPurchase = function(player, p)
		if not isShortString(p.kind) or not isShortString(p.key) then
			return false
		end
		return S.MarketService:TestPurchase(player, p.kind, p.key)
	end,
	Sync = function(player)
		S.DataService:MarkDirty(player, true)
		return true
	end,
}

function ActionService:Init(services)
	S = services
end

function ActionService:Start()
	local actionRemote = Remotes.Get("Action")
	actionRemote.OnServerEvent:Connect(function(player: Player, payload: any)
		if type(payload) ~= "table" or not isShortString(payload.action) then
			return
		end
		if not allow(player) then
			return
		end
		if not S.DataService:IsReady(player) then
			return
		end
		local handler = handlers[payload.action]
		if not handler then
			return
		end
		local ok, success, message = pcall(handler, player, payload)
		if not ok then
			warn("[ActionService]", payload.action, success)
			return
		end
		if message then
			S.ProgressService:Notify(player, message, if success then "success" else "error")
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)
end

return ActionService
