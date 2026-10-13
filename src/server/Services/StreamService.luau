--!nonstrict
-- StreamService.luau
-- Spawns Cloudlings at the Cloud Gate and drifts them down the Rainbow
-- Stream. Every Cloudling shows its species, mutation and exact price BEFORE
-- purchase: there are no blind boxes or random paid rolls. Whoever reaches a
-- Cloudling first and can afford it catches it (the core social race).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local CloudlingData = require(Shared.CloudlingData)
local CloudlingModel = require(Shared.CloudlingModel)
local Formulas = require(Shared.Formulas)
local Remotes = require(Shared.Remotes)

local StreamService = {}

type Entry = {
	id: string,
	mutation: string,
	price: number,
	model: Model,
	claimed: boolean,
	startX: number,
	y: number,
	laneZ: number,
	spawnTime: number,
}

local S: any
local active: { [number]: Entry } = {}
local nextId = 0
local activeCount = 0
local folder: Folder
local rng = Random.new()
local effectRemote: RemoteEvent
local announceRemote: RemoteEvent

function StreamService:Init(services)
	S = services
	effectRemote = Remotes.Get("Effect")
	announceRemote = Remotes.Get("Announce")
	folder = Instance.new("Folder")
	folder.Name = "Stream"
	folder.Parent = workspace
end

-- Returns species ids that may spawn right now (core + live seasonal).
local function spawnableSpecies(): { CloudlingData.Species }
	local eventId = S.WeatherService:GetSeasonalEvent()
	local list = {}
	for _, s in CloudlingData.Species do
		if s.event == nil or s.event == eventId then
			table.insert(list, s)
		end
	end
	return list
end

function StreamService:RollRarity(): string
	local weather = S.WeatherService:GetWeatherDef()
	local boost = weather and weather.rarityBoost or 1
	local total = 0
	local weights = {}
	for _, name in CloudlingData.RarityOrder do
		local r = CloudlingData.Rarities[name]
		local w = r.weight * (if r.order >= 5 then boost else 1)
		weights[name] = w
		total += w
	end
	local roll = rng:NextNumber() * total
	for _, name in CloudlingData.RarityOrder do
		roll -= weights[name]
		if roll <= 0 then
			return name
		end
	end
	return "Common"
end

function StreamService:RollMutation(): string
	local weather = S.WeatherService:GetWeatherDef()
	-- Check rarest first so a lucky roll is never shadowed by a common one.
	for i = #CloudlingData.MutationOrder, 2, -1 do
		local name = CloudlingData.MutationOrder[i]
		local chance = CloudlingData.Mutations[name].baseChance
		if weather and weather.mutation == name then
			chance = math.max(chance, weather.chance)
		end
		if rng:NextNumber() < chance then
			return name
		end
	end
	return "None"
end

-- `progress` (0-1) starts the Cloudling part-way down the stream (pre-fill).
function StreamService:Spawn(forcedId: string?, forcedMutation: string?, progress: number?)
	if activeCount >= Config.StreamMaxActive then
		return
	end
	local species: CloudlingData.Species?
	if forcedId then
		species = CloudlingData.Get(forcedId)
	else
		local rarity = self:RollRarity()
		local pool = {}
		for _, s in spawnableSpecies() do
			if s.rarity == rarity then
				table.insert(pool, s)
			end
		end
		if #pool == 0 then
			return
		end
		species = pool[rng:NextInteger(1, #pool)]
	end
	if not species then
		return
	end
	local mutation = forcedMutation or self:RollMutation()
	local price = Formulas.CatchPrice(species.id, mutation)

	local model = CloudlingModel.Build(species.id, mutation)
	local laneZ = rng:NextNumber(-3, 3)
	local startX = Config.StreamStartX + (Config.StreamEndX - Config.StreamStartX) * (progress or 0)
	local y = Config.StreamHeight + species.size * 0.3
	-- Alternate facing so both sides of the promenade see faces.
	local face = if rng:NextNumber() < 0.5 then 1 else -1
	local startPos = Vector3.new(startX, y, laneZ)
	model:PivotTo(CFrame.lookAt(startPos, startPos + Vector3.new(0, 0, face)))

	-- Movement is deterministic: clients animate from these attributes every
	-- frame (smooth, zero replication cost); the server derives the exact
	-- position from the same formula when validating a catch.
	nextId += 1
	local streamId = nextId
	local spawnTime = workspace:GetServerTimeNow()
	model:SetAttribute("StreamId", streamId)
	model:SetAttribute("StartX", startX)
	model:SetAttribute("Y", y)
	model:SetAttribute("LaneZ", laneZ)
	model:SetAttribute("Face", face)
	model:SetAttribute("SpawnTime", spawnTime)
	model:SetAttribute("Speed", Config.StreamSpeed)
	model:SetAttribute("Price", price)
	model:SetAttribute("Income", Formulas.CloudlingIncome(species.id, mutation, 1))

	local root = model.PrimaryPart :: BasePart
	local _, _, detail = CloudlingModel.MakeBillboard(root, species.id, mutation, species.size * 0.6 + 2)
	detail.Text = string.format("✨%s  •  +%s/s", Formulas.Format(price), Formulas.Format(model:GetAttribute("Income")))

	local entry: Entry = {
		id = species.id,
		mutation = mutation,
		price = price,
		model = model,
		claimed = false,
		startX = startX,
		y = y,
		laneZ = laneZ,
		spawnTime = spawnTime,
	}
	active[streamId] = entry
	activeCount += 1
	CollectionService:AddTag(model, "StreamCloudling")
	model.Parent = folder

	local duration = (Config.StreamEndX - startX) / Config.StreamSpeed
	task.delay(duration, function()
		self:Remove(streamId)
	end)

	local rarity = CloudlingData.Rarities[species.rarity]
	local mutPrefix = if mutation ~= "None" then mutation .. " " else ""
	if rarity.order >= 6 or mutation == "Galaxy" then
		local lead = if species.rarity == "Secret" then "🤫 A SECRET" else "✨ A " .. species.rarity:upper()
		announceRemote:FireAllClients({
			text = string.format("%s %s%s is drifting down the Rainbow Stream!", lead, mutPrefix, species.name),
			color = rarity.color,
			kind = "spawn",
		})
	end
end

function StreamService:Remove(streamId: number?)
	local entry = streamId and active[streamId]
	if entry then
		active[streamId :: number] = nil
		activeCount -= 1
		entry.model:Destroy()
	end
end

-- Where a stream Cloudling is right now (same formula the clients use).
function StreamService:PositionOf(entry: Entry): Vector3
	local x = entry.startX + (workspace:GetServerTimeNow() - entry.spawnTime) * Config.StreamSpeed
	return Vector3.new(x, entry.y, entry.laneZ)
end

function StreamService:TryCatch(player: Player, streamId: number): (boolean, string?)
	local entry = active[streamId]
	if not entry or entry.claimed then
		return false, "Too slow — someone else caught that one! 💨"
	end
	local data = S.DataService:Get(player)
	if not data then
		return false
	end
	-- Range check against the authoritative position. Generous tolerance
	-- covers latency (the Cloudling keeps drifting while the request travels).
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local pos = self:PositionOf(entry)
	if not root or (root.Position - pos).Magnitude > 24 then
		return false, "Get closer to catch it!"
	end
	if not S.PlotService:FreeSlot(player) then
		return false, "Your island is full! Release a Cloudling or unlock a pedestal."
	end
	if data.sparkles < entry.price then
		return false, "Not enough Sparkles! Need ✨" .. Formulas.Format(entry.price - data.sparkles) .. " more."
	end
	entry.claimed = true
	if not S.DataService:SpendSparkles(player, entry.price) then
		entry.claimed = false
		return false
	end
	self:Remove(streamId)
	local slot = S.PlotService:AddCloudling(player, entry.id, entry.mutation)
	if not slot then
		-- Should not happen (checked above) but never eat Sparkles.
		S.DataService:AddSparkles(player, entry.price, false)
		return false
	end
	S.ProgressService:OnCatch(player, entry.id, entry.mutation)
	effectRemote:FireAllClients("CatchFly", {
		from = pos,
		to = S.PlotService:PedestalPosition(player, slot),
		species = entry.id,
		mutation = entry.mutation,
		userId = player.UserId,
	})
	return true
end

function StreamService:Start()
	-- Pre-fill the stream so the first player never sees it empty.
	for i = 1, 14 do
		pcall(self.Spawn, self, nil, nil, i / 16)
	end
	task.spawn(function()
		while true do
			local weather = S.WeatherService:GetWeatherDef()
			local rate = weather and weather.spawnRate or 1
			task.wait(Config.StreamSpawnInterval / rate)
			if #Players:GetPlayers() > 0 then
				local ok, err = pcall(self.Spawn, self)
				if not ok then
					warn("[StreamService] Spawn failed:", err)
				end
			end
		end
	end)
end

return StreamService
