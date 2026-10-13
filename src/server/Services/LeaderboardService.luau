--!nonstrict
-- LeaderboardService.luau
-- In-server leaderstats + global OrderedDataStore boards rendered on the
-- physical boards built by MapService.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)

local LeaderboardService = {}

local S: any
local stores: { [string]: OrderedDataStore } = {}
local nameCache: { [number]: string } = {}

local BOARDS = {
	Earned = { store = "LB_TotalEarned_v1", value = function(d) return d.totalEarned end, format = Formulas.Format },
	Rebirths = { store = "LB_Rebirths_v1", value = function(d) return d.rebirths end, format = tostring },
	Likes = { store = "LB_Likes_v1", value = function(d) return d.stats.likesReceived end, format = Formulas.Format },
}

function LeaderboardService:Init(services)
	S = services
	for key, b in BOARDS do
		local ok, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, b.store)
		if ok then
			stores[key] = store
		end
	end
end

function LeaderboardService:SetupLeaderstats(player: Player)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	local sparkles = Instance.new("StringValue")
	sparkles.Name = "✨ Sparkles"
	sparkles.Parent = folder
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "🔁 Rebirths"
	rebirths.Parent = folder
	folder.Parent = player
	self:UpdateStats(player)
end

function LeaderboardService:UpdateStats(player: Player)
	local data = S.DataService:GetRaw(player)
	local folder = player:FindFirstChild("leaderstats")
	if not data or not folder then
		return
	end
	local sparkles = folder:FindFirstChild("✨ Sparkles") :: StringValue?
	local rebirths = folder:FindFirstChild("🔁 Rebirths") :: IntValue?
	if sparkles then
		sparkles.Value = Formulas.Format(math.floor(data.sparkles))
	end
	if rebirths then
		rebirths.Value = data.rebirths
	end
end

-- Writes this player's values to the ordered stores.
function LeaderboardService:Submit(player: Player)
	local data = S.DataService:GetRaw(player)
	if not data then
		return
	end
	for key, b in BOARDS do
		local store = stores[key]
		if store then
			-- OrderedDataStore holds 64-bit ints; clamp astronomical values.
			local v = math.clamp(math.floor(b.value(data)), 0, 2 ^ 53)
			if v > 0 then
				pcall(store.SetAsync, store, tostring(player.UserId), v)
			end
		end
	end
end

local function nameOf(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	nameCache[userId] = if ok then name else "Player"
	return nameCache[userId]
end

local function render(list: Frame, rows: { { name: string, value: string } }, emptyText: string)
	for _, child in list:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	if #rows == 0 then
		rows = { { name = emptyText, value = "" } }
	end
	for i, row in rows do
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = if i % 2 == 0 then 0.85 else 1
		t.BackgroundColor3 = Color3.new(1, 1, 1)
		t.Size = UDim2.new(1, 0, 0.098, 0)
		t.LayoutOrder = i
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.TextXAlignment = Enum.TextXAlignment.Left
		local medal = if i == 1 then "🥇" elseif i == 2 then "🥈" elseif i == 3 then "🥉" else "#" .. i
		t.Text = if row.value ~= "" then string.format("  %s  %s  —  %s", medal, row.name, row.value) else "  " .. row.name
		t.TextColor3 = if i <= 3 then Color3.fromRGB(255, 230, 120) else Color3.new(1, 1, 1)
		t.Parent = list
	end
end

function LeaderboardService:RefreshBoards()
	for key, b in BOARDS do
		local store = stores[key]
		local list = S.MapService.Boards[key]
		if list then
			local rows = {}
			if store then
				local ok, pages = pcall(store.GetSortedAsync, store, false, 10)
				if ok then
					for _, entry in pages:GetCurrentPage() do
						table.insert(rows, { name = nameOf(tonumber(entry.key) or 0), value = b.format(entry.value) })
					end
				end
			end
			if #rows == 0 then
				-- Fall back to in-server players (Studio / DataStores offline).
				local local_ = {}
				for _, p in Players:GetPlayers() do
					local d = S.DataService:GetRaw(p)
					if d then
						table.insert(local_, { name = p.DisplayName, raw = b.value(d) })
					end
				end
				table.sort(local_, function(a, c)
					return a.raw > c.raw
				end)
				for i = 1, math.min(10, #local_) do
					table.insert(rows, { name = local_[i].name, value = b.format(local_[i].raw) })
				end
			end
			render(list, rows, "Be the first on this board!")
		end
	end
end

function LeaderboardService:Start()
	task.spawn(function()
		task.wait(10)
		while true do
			for _, player in Players:GetPlayers() do
				self:Submit(player)
				task.wait(0.5)
			end
			self:RefreshBoards()
			task.wait(Config.LeaderboardRefresh)
		end
	end)
	-- Final submit on leave happens in Main before the profile is released.
end

return LeaderboardService
