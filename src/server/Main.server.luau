--!nonstrict
-- Main.server.luau
-- Server bootstrap. Loads every service, wires them together with a shared
-- registry, then runs Init (no yielding) and Start (may spawn loops) in a
-- fixed order. Also orchestrates the player join/leave lifecycle.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
Remotes.CreateAll()

local ServicesFolder = script.Parent:WaitForChild("Services")

local ORDER = {
	"DataService",
	"MapService",
	"MarketService",
	"WeatherService",
	"CommunityService",
	"LeaderboardService",
	"ProgressService",
	"PlotService",
	"StreamService",
	"AntiCheatService",
	"ActionService",
}

local S: { [string]: any } = {}
for _, name in ORDER do
	S[name] = require(ServicesFolder:WaitForChild(name)) :: any
end
for _, name in ORDER do
	S[name]:Init(S)
end
for _, name in ORDER do
	S[name]:Start()
end

local function onPlayerAdded(player: Player)
	local data = S.DataService:Load(player)
	if not data or not player.Parent then
		return
	end
	S.MarketService:LoadPasses(player)
	S.LeaderboardService:SetupLeaderstats(player)
	if not S.PlotService:Assign(player) then
		player:Kick("This server is full of islands! Please join another server.")
		return
	end
	S.ProgressService:OnJoin(player)
	S.DataService:SetReady(player)
	S.LeaderboardService:UpdateStats(player)
end

local function onPlayerRemoving(player: Player)
	S.LeaderboardService:Submit(player)
	S.PlotService:BakeStored(player)
	S.PlotService:Release(player)
	S.MarketService:Unload(player)
	S.DataService:Release(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

print("☁ Catch a Cloudling server ready")
