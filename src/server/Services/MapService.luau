--!nonstrict
-- MapService.luau
-- Procedurally builds the whole world: the Rainbow Stream promenade, eight
-- floating islands, the iconic rainbow arch, leaderboards, the VIP lounge
-- and decorative clouds. No uploaded assets are required.
--
-- Layout (top view, river flows -X -> +X):
--
--     [P5]    [P6]    [P7]    [P8]        z = +70  (islands)
--      ||      ||      ||      ||         bridges
--   =========== RAINBOW STREAM ==========  z = 0
--      ||      ||      ||      ||
--     [P1]    [P2]    [P3]    [P4]        z = -70

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local MapService = {}

export type Plot = {
	index: number,
	cframe: CFrame,
	folder: Folder,
	pedestals: { BasePart },
	collectPad: BasePart,
	spawn: CFrame,
	ownerLabel: TextLabel,
	likesLabel: TextLabel,
	likePrompt: ProximityPrompt,
	color: Color3,
}

MapService.Plots = {} :: { Plot }
MapService.Boards = {} :: { [string]: Frame }
MapService.World = nil :: Folder?
MapService.VipPad = nil :: BasePart?
MapService.VipLoungeSpawn = CFrame.new()
MapService.CloudSea = nil :: BasePart?

local RAINBOW = {
	Color3.fromRGB(255, 90, 110),
	Color3.fromRGB(255, 160, 70),
	Color3.fromRGB(255, 225, 80),
	Color3.fromRGB(110, 220, 120),
	Color3.fromRGB(90, 180, 255),
	Color3.fromRGB(140, 120, 255),
	Color3.fromRGB(220, 120, 255),
}

local ISLAND_COLORS = {
	Color3.fromRGB(150, 230, 160),
	Color3.fromRGB(255, 200, 220),
	Color3.fromRGB(180, 210, 255),
	Color3.fromRGB(255, 230, 160),
	Color3.fromRGB(210, 190, 255),
	Color3.fromRGB(170, 240, 230),
	Color3.fromRGB(255, 205, 170),
	Color3.fromRGB(220, 245, 170),
}

local function part(parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

local function label(parent: Instance, text: string, size: UDim2, pos: UDim2, color: Color3): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = size
	t.Position = pos
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.Text = text
	t.TextColor3 = color
	local s = Instance.new("UIStroke")
	s.Thickness = 3
	s.Color = Color3.fromRGB(40, 25, 70)
	s.Parent = t
	t.Parent = parent
	return t
end

-- A fluffy cloud cluster made of overlapping spheres.
local function cloud(parent: Instance, pos: Vector3, scale: number, rng: Random)
	for _ = 1, rng:NextInteger(4, 7) do
		local d = rng:NextNumber(8, 16) * scale
		part(parent, {
			Name = "Cloud",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * d,
			Position = pos + Vector3.new(rng:NextNumber(-10, 10), rng:NextNumber(-2, 3), rng:NextNumber(-6, 6)) * scale,
			Color = Color3.fromRGB(255, 255, 255),
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
		})
	end
end

local function setupLighting()
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.5
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.4

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.28
	atmosphere.Offset = 0.15
	atmosphere.Color = Color3.fromRGB(220, 230, 255)
	atmosphere.Decay = Color3.fromRGB(255, 200, 230)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1.2
	atmosphere.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.6
	bloom.Size = 30
	bloom.Threshold = 1.6
	bloom.Parent = Lighting

	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "WeatherTint"
	cc.Saturation = 0.18
	cc.Contrast = 0.05
	cc.Parent = Lighting

	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.06
	rays.Parent = Lighting
end

local function buildRainbowArch(parent: Instance, center: Vector3, radius: number)
	local segments = 28
	for band, color in RAINBOW do
		local r = radius - (band - 1) * 1.6
		for i = 0, segments - 1 do
			local a0 = i / segments * math.pi
			local a1 = (i + 1) / segments * math.pi
			local mid = (a0 + a1) / 2
			local len = 2 * r * math.sin((a1 - a0) / 2) + 0.2
			local pos = center + Vector3.new(0, math.sin(mid) * r, math.cos(mid) * r)
			part(parent, {
				Name = "Rainbow",
				Size = Vector3.new(1.6, 1.6, len),
				CFrame = CFrame.lookAt(pos, pos + Vector3.new(0, math.cos(mid), -math.sin(mid))),
				Color = color,
				Material = Enum.Material.Neon,
				CanCollide = false,
				CastShadow = false,
			})
		end
	end
end

local function buildGate(parent: Instance, x: number, text: string)
	for _, z in { -11, 11 } do
		part(parent, {
			Name = "GatePillar",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(22, 3, 3),
			CFrame = CFrame.new(x, 11, z) * CFrame.Angles(0, 0, math.pi / 2),
			Color = Color3.fromRGB(255, 255, 255),
		})
	end
	local top = part(parent, {
		Name = "GateSign",
		Size = Vector3.new(3, 5, 26),
		Position = Vector3.new(x, 23, 0),
		Color = Color3.fromRGB(140, 110, 255),
	})
	for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
		local g = Instance.new("SurfaceGui")
		g.Face = face
		g.LightInfluence = 0
		g.PixelsPerStud = 30
		label(g, text, UDim2.fromScale(1, 1), UDim2.new(), Color3.new(1, 1, 1))
		g.Parent = top
	end
	local cloudEmitter = Instance.new("ParticleEmitter")
	cloudEmitter.Color = ColorSequence.new(Color3.new(1, 1, 1))
	cloudEmitter.Size = NumberSequence.new(3, 0)
	cloudEmitter.Transparency = NumberSequence.new(0.3, 1)
	cloudEmitter.Rate = 10
	cloudEmitter.Lifetime = NumberRange.new(1.5, 2.5)
	cloudEmitter.Speed = NumberRange.new(2, 5)
	cloudEmitter.SpreadAngle = Vector2.new(60, 60)
	cloudEmitter.Parent = top
end

local function buildBoard(parent: Instance, key: string, title: string, cf: CFrame, accent: Color3)
	local board = part(parent, {
		Name = key .. "Board",
		Size = Vector3.new(22, 16, 1),
		CFrame = cf * CFrame.new(0, 11, 0),
		Color = Color3.fromRGB(40, 30, 80),
	})
	for _, x in { -10, 10 } do
		part(parent, {
			Name = "Post",
			Size = Vector3.new(1, 4, 1),
			CFrame = cf * CFrame.new(x, 1, 0),
			Color = Color3.fromRGB(255, 255, 255),
		})
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.PixelsPerStud = 25
	gui.Parent = board
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(35, 25, 70)
	frame.Parent = gui
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new(accent, Color3.fromRGB(35, 25, 70))
	grad.Transparency = NumberSequence.new(0.4, 0)
	grad.Parent = frame
	label(frame, title, UDim2.fromScale(0.95, 0.14), UDim2.fromScale(0.025, 0.02), Color3.new(1, 1, 1))
	local list = Instance.new("Frame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.Size = UDim2.fromScale(0.92, 0.8)
	list.Position = UDim2.fromScale(0.04, 0.18)
	list.Parent = frame
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.Parent = list
	MapService.Boards[key] = list
end

local function buildIsland(world: Folder, index: number, center: Vector3, color: Color3): Plot
	local folder = Instance.new("Folder")
	folder.Name = "Plot" .. index
	folder.Parent = world
	local cf = CFrame.lookAt(center, Vector3.new(center.X, center.Y, 0))
	local rng = Random.new(index * 77)

	-- Ground
	part(folder, {
		Name = "Ground",
		Size = Vector3.new(80, 6, 70),
		CFrame = cf * CFrame.new(0, -3, 0),
		Color = color,
		Material = Enum.Material.Grass,
	})
	part(folder, {
		Name = "Underside",
		Size = Vector3.new(72, 8, 62),
		CFrame = cf * CFrame.new(0, -9, 0),
		Color = Color3.fromRGB(190, 160, 140),
		Material = Enum.Material.Sand,
	})
	cloud(folder, (cf * CFrame.new(0, -14, 0)).Position, 2.2, rng)

	-- Bridge to the promenade (front edge of island is local z = -35)
	part(folder, {
		Name = "Bridge",
		Size = Vector3.new(16, 2, 15),
		CFrame = cf * CFrame.new(0, -1, -42),
		Color = Color3.fromRGB(255, 255, 255),
	})
	for _, x in { -8, 8 } do
		part(folder, {
			Name = "Rail",
			Size = Vector3.new(1, 3, 15),
			CFrame = cf * CFrame.new(x, 1.5, -42),
			Color = color,
			CanCollide = true,
		})
	end

	-- Fence posts around the edge (leaving the front entrance open)
	for i = 0, 15 do
		local t = i / 15
		for _, side in { -1, 1 } do
			part(folder, {
				Name = "Fence",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 2,
				CFrame = cf * CFrame.new(side * 39, 1, -34 + t * 68),
				Color = Color3.fromRGB(255, 255, 255),
			})
		end
	end

	-- Pedestals: 4 columns x 5 rows, slot 1 is front-left.
	local pedestals = {}
	local cols = { -24, -8, 8, 24 }
	local rows = { -16, -5, 6, 17, 28 }
	local slot = 0
	for _, rz in rows do
		for _, cx in cols do
			slot += 1
			local base = part(folder, {
				Name = "Pedestal" .. slot,
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(1.6, 7, 7),
				CFrame = cf * CFrame.new(cx, 0.8, rz) * CFrame.Angles(0, 0, math.pi / 2),
				Color = Color3.fromRGB(255, 255, 255),
			})
			base:SetAttribute("Slot", slot)
			base:SetAttribute("Plot", index)
			base:SetAttribute("State", "Locked")
			base:SetAttribute("Stored", 0)
			part(base, {
				Name = "Ring",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(1.7, 5.5, 5.5),
				CFrame = base.CFrame,
				Color = color,
				Material = Enum.Material.Neon,
				CanCollide = false,
			})
			pedestals[slot] = base
		end
	end

	-- Collect pad near the entrance.
	local pad = part(folder, {
		Name = "CollectPad",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 10, 10),
		CFrame = cf * CFrame.new(0, 0.3, -27) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(255, 215, 60),
		Material = Enum.Material.Neon,
	})
	local padGui = Instance.new("BillboardGui")
	padGui.Size = UDim2.fromOffset(160, 50)
	padGui.StudsOffset = Vector3.new(0, 3.5, 0)
	padGui.MaxDistance = 80
	padGui.LightInfluence = 0
	label(padGui, "✨ COLLECT ✨", UDim2.fromScale(1, 1), UDim2.new(), Color3.fromRGB(255, 240, 120))
	padGui.Parent = pad

	-- Owner sign with likes counter + like prompt.
	local sign = part(folder, {
		Name = "Sign",
		Size = Vector3.new(30, 9, 1),
		CFrame = cf * CFrame.new(0, 9, 34) * CFrame.Angles(0, math.pi, 0),
		Color = Color3.fromRGB(255, 255, 255),
	})
	for _, x in { -12, 12 } do
		part(folder, { Name = "SignPost", Size = Vector3.new(1, 5, 1), CFrame = cf * CFrame.new(x, 2.5, 34), Color = color })
	end
	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Back
	signGui.LightInfluence = 0
	signGui.PixelsPerStud = 25
	signGui.Parent = sign
	local ownerLabel = label(signGui, "Empty Island", UDim2.fromScale(0.96, 0.6), UDim2.fromScale(0.02, 0.05), Color3.fromRGB(255, 255, 255))
	ownerLabel.TextColor3 = color
	local likesLabel = label(signGui, "❤ 0 likes", UDim2.fromScale(0.96, 0.3), UDim2.fromScale(0.02, 0.65), Color3.fromRGB(255, 120, 160))
	local likePrompt = Instance.new("ProximityPrompt")
	likePrompt.Name = "LikePrompt"
	likePrompt.ActionText = "Like Island ❤"
	likePrompt.ObjectText = ""
	likePrompt.KeyboardKeyCode = Enum.KeyCode.R
	likePrompt.MaxActivationDistance = 14
	likePrompt.RequiresLineOfSight = false
	likePrompt.Enabled = false
	local likeAttach = Instance.new("Attachment")
	likeAttach.Position = Vector3.new(0, -6, 0)
	likeAttach.Parent = sign
	likePrompt.Parent = likeAttach

	-- Decorative trees (sphere-on-cylinder lollipop trees)
	for _, pos in { Vector3.new(-34, 0, 30), Vector3.new(34, 0, 30), Vector3.new(-34, 0, -28), Vector3.new(34, 0, -28) } do
		local base = cf * CFrame.new(pos)
		part(folder, {
			Name = "Trunk",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(7, 1.4, 1.4),
			CFrame = base * CFrame.new(0, 3.5, 0) * CFrame.Angles(0, 0, math.pi / 2),
			Color = Color3.fromRGB(200, 150, 110),
		})
		part(folder, {
			Name = "Leaves",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 6,
			CFrame = base * CFrame.new(0, 8, 0),
			Color = RAINBOW[rng:NextInteger(1, #RAINBOW)]:Lerp(Color3.new(1, 1, 1), 0.35),
		})
	end

	return {
		index = index,
		cframe = cf,
		folder = folder,
		pedestals = pedestals,
		collectPad = pad,
		spawn = cf * CFrame.new(0, 4, -31) * CFrame.Angles(0, math.pi, 0),
		ownerLabel = ownerLabel,
		likesLabel = likesLabel,
		likePrompt = likePrompt,
		color = color,
	}
end

function MapService:Init()
	setupLighting()
	local world = Instance.new("Folder")
	world.Name = "World"
	world.Parent = workspace
	self.World = world
	local rng = Random.new(2026)

	-- Promenade + Rainbow Stream
	local promenade = part(world, {
		Name = "Promenade",
		Size = Vector3.new(480, 4, 44),
		Position = Vector3.new(0, -2, 0),
		Color = Color3.fromRGB(235, 228, 255),
	})
	part(world, {
		Name = "PromenadeUnder",
		Size = Vector3.new(470, 6, 36),
		Position = Vector3.new(0, -7, 0),
		Color = Color3.fromRGB(200, 190, 240),
	})
	cloud(world, Vector3.new(0, -14, 0), 3, rng)
	promenade:SetAttribute("Walkable", true)
	for i, color in RAINBOW do
		local stripe = part(world, {
			Name = "StreamStripe",
			Size = Vector3.new(Config.StreamEndX - Config.StreamStartX + 20, 0.2, 2),
			Position = Vector3.new(0, 0.1, -7 + (i - 0.5) * 2),
			Color = color,
			Material = Enum.Material.Neon,
		})
		stripe:SetAttribute("Stripe", i)
		stripe.Transparency = 0.15
	end
	buildGate(world, Config.StreamStartX, "☁ CLOUD GATE ☁")
	buildGate(world, Config.StreamEndX, "SKY DRAIN")
	buildRainbowArch(world, Vector3.new(0, 0, 0), 21)

	-- Title sign under the arch
	local title = part(world, {
		Name = "TitleSign",
		Size = Vector3.new(1, 8, 34),
		Position = Vector3.new(0, 26, 0),
		Transparency = 1,
		CanCollide = false,
	})
	for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
		local g = Instance.new("SurfaceGui")
		g.Face = face
		g.LightInfluence = 0
		g.PixelsPerStud = 30
		label(g, "CATCH A CLOUDLING", UDim2.fromScale(1, 1), UDim2.new(), Color3.fromRGB(255, 255, 255))
		g.Parent = title
	end

	-- Islands
	local xs = { -150, -50, 50, 150 }
	local i = 0
	for _, side in { -1, 1 } do
		for _, x in xs do
			i += 1
			table.insert(self.Plots, buildIsland(world, i, Vector3.new(x, 0, side * 70), ISLAND_COLORS[i]))
		end
	end

	-- Leaderboards on the promenade edges, facing the stream.
	buildBoard(world, "Earned", "🏆 Top Sparkle Earners", CFrame.lookAt(Vector3.new(-100, 0, 20), Vector3.new(-100, 0, 0)), Color3.fromRGB(255, 200, 60))
	buildBoard(world, "Rebirths", "🔁 Most Rebirths", CFrame.lookAt(Vector3.new(100, 0, 20), Vector3.new(100, 0, 0)), Color3.fromRGB(140, 120, 255))
	buildBoard(world, "Likes", "❤ Most Loved Islands", CFrame.lookAt(Vector3.new(-100, 0, -20), Vector3.new(-100, 0, 0)), Color3.fromRGB(255, 110, 160))
	buildBoard(world, "Community", "🌍 Community Goal", CFrame.lookAt(Vector3.new(100, 0, -20), Vector3.new(100, 0, 0)), Color3.fromRGB(90, 200, 255))

	-- Neutral spawn (players are moved to their island once data loads).
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.Position = Vector3.new(0, 0.5, -15)
	spawn.Color = Color3.fromRGB(255, 255, 255)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Transparency = 0.5
	spawn.Duration = 0
	spawn.Parent = world

	-- VIP Lounge: floating cloud above the arch. Pad teleports VIPs up.
	local loungeCenter = Vector3.new(0, 60, 0)
	part(world, {
		Name = "VipLounge",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(3, 46, 46),
		CFrame = CFrame.new(loungeCenter) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(255, 230, 140),
		Material = Enum.Material.Foil,
	})
	cloud(world, loungeCenter - Vector3.new(0, 5, 0), 2.5, rng)
	local loungeLight = Instance.new("PointLight")
	loungeLight.Range = 40
	loungeLight.Color = Color3.fromRGB(255, 220, 120)
	loungeLight.Parent = world:FindFirstChild("VipLounge")
	self.VipLoungeSpawn = CFrame.new(loungeCenter + Vector3.new(0, 5, 0))
	local pad = part(world, {
		Name = "VipPad",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 8, 8),
		CFrame = CFrame.new(0, 0.3, 16) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(255, 200, 40),
		Material = Enum.Material.Neon,
	})
	local vipGui = Instance.new("BillboardGui")
	vipGui.Size = UDim2.fromOffset(160, 40)
	vipGui.StudsOffset = Vector3.new(0, 3, 0)
	vipGui.MaxDistance = 60
	vipGui.LightInfluence = 0
	label(vipGui, "👑 VIP LOUNGE", UDim2.fromScale(1, 1), UDim2.new(), Color3.fromRGB(255, 220, 90))
	vipGui.Parent = pad
	self.VipPad = pad

	-- Soft cloud sea: falling in returns you to your island instead of dying.
	self.CloudSea = part(world, {
		Name = "CloudSea",
		Size = Vector3.new(2048, 4, 2048),
		Position = Vector3.new(0, -45, 0),
		Color = Color3.fromRGB(255, 255, 255),
		Transparency = 0.15,
		CanCollide = false,
	})

	-- Decorative sky clouds
	for _ = 1, 40 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local dist = rng:NextNumber(260, 520)
		cloud(world, Vector3.new(math.cos(angle) * dist, rng:NextNumber(-30, 80), math.sin(angle) * dist), rng:NextNumber(1.5, 3.5), rng)
	end
end

function MapService:Start() end

return MapService
