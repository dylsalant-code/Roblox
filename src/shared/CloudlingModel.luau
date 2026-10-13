--!nonstrict
-- CloudlingModel.luau
-- Builds a Cloudling out of primitive parts so the game needs zero uploaded
-- meshes. Used by the server (stream + islands) and client (Index previews).
--
-- Structure:  Model (PrimaryPart = Root, anchored, invisible)
--               └ Body / Eyes / Cheeks / Cloud puffs / Feature parts (welded)

local CollectionService = game:GetService("CollectionService")

local CloudlingData = require(script.Parent.CloudlingData)

local CloudlingModel = {}

local function weldTo(root: BasePart, p: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = root
	w.Part1 = p
	w.Parent = p
end

local function makePart(
	model: Model,
	root: BasePart,
	name: string,
	shape: Enum.PartType,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.Anchored = false
	p.CastShadow = false
	p.CFrame = root.CFrame * offset
	weldTo(root, p)
	p.Parent = model
	return p
end

local function addFeature(model: Model, root: BasePart, feature: string, s: number, accent: Color3)
	local ball = Enum.PartType.Ball
	local block = Enum.PartType.Block
	local cyl = Enum.PartType.Cylinder
	local top = s * 0.45
	if feature == "ears" then
		for _, side in { -1, 1 } do
			makePart(model, root, "Ear", ball, Vector3.new(s * 0.3, s * 0.45, s * 0.3),
				CFrame.new(side * s * 0.28, top, 0) * CFrame.Angles(0, 0, -side * 0.35), accent)
		end
	elseif feature == "antenna" then
		makePart(model, root, "Stalk", cyl, Vector3.new(s * 0.4, 0.15, 0.15),
			CFrame.new(0, top + s * 0.15, 0) * CFrame.Angles(0, 0, math.pi / 2), accent)
		makePart(model, root, "Tip", ball, Vector3.one * s * 0.2, CFrame.new(0, top + s * 0.38, 0), accent, Enum.Material.Neon)
	elseif feature == "wings" then
		for _, side in { -1, 1 } do
			makePart(model, root, "Wing", ball, Vector3.new(s * 0.15, s * 0.5, s * 0.7),
				CFrame.new(side * s * 0.55, s * 0.1, s * 0.1) * CFrame.Angles(0, 0, side * 0.5), accent)
		end
	elseif feature == "tail" then
		makePart(model, root, "Tail", ball, Vector3.one * s * 0.4, CFrame.new(0, -s * 0.05, s * 0.5), accent)
	elseif feature == "horns" then
		for _, side in { -1, 1 } do
			makePart(model, root, "Horn", cyl, Vector3.new(s * 0.45, s * 0.14, s * 0.14),
				CFrame.new(side * s * 0.22, top + s * 0.08, 0) * CFrame.Angles(0, 0, math.pi / 2 - side * 0.4), accent)
		end
	elseif feature == "bolt" then
		makePart(model, root, "Bolt", block, Vector3.new(s * 0.12, s * 0.5, s * 0.12),
			CFrame.new(0, top + s * 0.2, 0) * CFrame.Angles(0, 0, 0.5), Color3.fromRGB(255, 240, 60), Enum.Material.Neon)
	elseif feature == "crown" then
		local gold = Color3.fromRGB(255, 210, 50)
		makePart(model, root, "CrownBand", cyl, Vector3.new(s * 0.15, s * 0.5, s * 0.5),
			CFrame.new(0, top + s * 0.05, 0) * CFrame.Angles(0, 0, math.pi / 2), gold, Enum.Material.Foil)
		for i = 0, 4 do
			local a = i / 5 * math.pi * 2
			makePart(model, root, "CrownPoint", block, Vector3.one * s * 0.1,
				CFrame.new(math.cos(a) * s * 0.2, top + s * 0.17, math.sin(a) * s * 0.2) * CFrame.Angles(0, a, math.pi / 4), accent, Enum.Material.Neon)
		end
	elseif feature == "halo" then
		local halo = makePart(model, root, "Halo", cyl, Vector3.new(0.12, s * 0.7, s * 0.7),
			CFrame.new(0, top + s * 0.35, 0) * CFrame.Angles(0, 0, math.pi / 2), accent, Enum.Material.Neon)
		halo.Transparency = 0.25
	elseif feature == "antlers" then
		for _, side in { -1, 1 } do
			makePart(model, root, "Antler", cyl, Vector3.new(s * 0.5, 0.18, 0.18),
				CFrame.new(side * s * 0.25, top + s * 0.15, 0) * CFrame.Angles(0, 0, math.pi / 2 - side * 0.6), accent, Enum.Material.Neon)
			makePart(model, root, "AntlerTip", cyl, Vector3.new(s * 0.3, 0.15, 0.15),
				CFrame.new(side * s * 0.42, top + s * 0.32, 0) * CFrame.Angles(0, 0, math.pi / 2 - side * 1.1), accent, Enum.Material.Neon)
		end
	elseif feature == "stem" then
		makePart(model, root, "Stem", cyl, Vector3.new(s * 0.3, s * 0.15, s * 0.15),
			CFrame.new(0, top + s * 0.1, 0) * CFrame.Angles(0, 0, math.pi / 2), accent)
	elseif feature == "hat" then
		makePart(model, root, "Hat", cyl, Vector3.new(s * 0.35, s * 0.5, s * 0.5),
			CFrame.new(0, top + s * 0.08, 0) * CFrame.Angles(0, 0, math.pi / 2 + 0.2), Color3.fromRGB(220, 30, 50))
		makePart(model, root, "Pompom", ball, Vector3.one * s * 0.2, CFrame.new(s * 0.08, top + s * 0.33, 0), accent)
	end
end

-- Builds a Cloudling. `scale` lets previews shrink models (defaults to 1).
function CloudlingModel.Build(speciesId: string, mutation: string, scale: number?): Model
	local species = CloudlingData.Get(speciesId)
	assert(species, "Unknown species " .. tostring(speciesId))
	local mut = CloudlingData.Mutations[mutation] or CloudlingData.Mutations.None
	local s = species.size * (scale or 1)

	local model = Instance.new("Model")
	model.Name = species.name

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(s, s, s)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = true
	root.Parent = model
	model.PrimaryPart = root

	local bodyColor = species.body
	local material = Enum.Material.SmoothPlastic
	if mutation == "Golden" then
		bodyColor = Color3.fromRGB(255, 205, 60)
		material = Enum.Material.Foil
	elseif mutation == "Galaxy" then
		bodyColor = Color3.fromRGB(70, 40, 160)
		material = Enum.Material.Neon
	end

	local body = makePart(model, root, "Body", Enum.PartType.Ball, Vector3.one * s, CFrame.new(), bodyColor, material)
	-- Eyes + shine + cheeks on the front (-Z) face.
	for _, side in { -1, 1 } do
		makePart(model, root, "Eye", Enum.PartType.Ball, Vector3.new(s * 0.16, s * 0.22, s * 0.1),
			CFrame.new(side * s * 0.17, s * 0.08, -s * 0.46), Color3.fromRGB(25, 25, 35))
		makePart(model, root, "Shine", Enum.PartType.Ball, Vector3.one * s * 0.06,
			CFrame.new(side * s * 0.17 + s * 0.03, s * 0.13, -s * 0.51), Color3.new(1, 1, 1), Enum.Material.Neon)
		makePart(model, root, "Cheek", Enum.PartType.Ball, Vector3.new(s * 0.16, s * 0.1, s * 0.05),
			CFrame.new(side * s * 0.3, -s * 0.06, -s * 0.42), Color3.fromRGB(255, 140, 170))
	end
	makePart(model, root, "Smile", Enum.PartType.Ball, Vector3.new(s * 0.12, s * 0.05, s * 0.05),
		CFrame.new(0, -s * 0.08, -s * 0.49), Color3.fromRGB(60, 30, 40))

	-- Fluffy cloud the Cloudling sits on.
	local puffColor = Color3.fromRGB(250, 252, 255)
	for i, off in { Vector3.new(-0.4, -0.5, 0), Vector3.new(0.4, -0.5, 0), Vector3.new(0, -0.55, 0.3), Vector3.new(0, -0.5, -0.3) } do
		local p = makePart(model, root, "Puff" .. i, Enum.PartType.Ball, Vector3.one * s * 0.6, CFrame.new(off * s), puffColor)
		p.Transparency = 0.1
	end

	addFeature(model, root, species.feature, s, species.accent)

	-- Mutation dressing.
	if mutation ~= "None" then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Color = ColorSequence.new(mut.color)
		emitter.LightEmission = 1
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, s * 0.18), NumberSequenceKeypoint.new(1, 0) })
		emitter.Lifetime = NumberRange.new(0.8, 1.4)
		emitter.Rate = mutation == "Galaxy" and 14 or 8
		emitter.Speed = NumberRange.new(1, 2.5)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Parent = body
		if mutation == "Rainbow" then
			CollectionService:AddTag(body, "RainbowBody")
		end
	end

	-- Higher rarities get a soft glow so they pop out of the stream.
	local rarity = CloudlingData.Rarities[species.rarity]
	if rarity.order >= 4 then
		local light = Instance.new("PointLight")
		light.Color = rarity.color
		light.Range = 10 + rarity.order * 2
		light.Brightness = 1.5
		light.Parent = root
	end

	model:SetAttribute("Species", speciesId)
	model:SetAttribute("Mutation", mutation)
	model:SetAttribute("Rarity", species.rarity)
	return model
end

-- Billboard used over Cloudlings in the stream and on pedestals.
-- Lines are refreshed by the owner via the returned TextLabels.
function CloudlingModel.MakeBillboard(adornee: BasePart, speciesId: string, mutation: string, offsetY: number): (BillboardGui, TextLabel, TextLabel)
	local species = CloudlingData.Get(speciesId) :: CloudlingData.Species
	local rarity = CloudlingData.Rarities[species.rarity]
	local gui = Instance.new("BillboardGui")
	gui.Name = "Info"
	gui.Adornee = adornee
	gui.Size = UDim2.fromOffset(200, 78)
	gui.StudsOffset = Vector3.new(0, offsetY, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 90
	gui.LightInfluence = 0

	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Parent = gui

	local function line(text: string, color: Color3, height: number, order: number): TextLabel
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(1, 0, 0, height)
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.Text = text
		t.TextColor3 = color
		t.LayoutOrder = order
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = Color3.fromRGB(30, 20, 50)
		stroke.Parent = t
		t.Parent = gui
		return t
	end

	local prefix = if mutation ~= "None" then mutation .. " " else ""
	local rarityColor = if species.rarity == "Secret" then Color3.fromRGB(255, 255, 255) else rarity.color
	local mutColor = (CloudlingData.Mutations[mutation] or CloudlingData.Mutations.None).color
	line(species.rarity:upper(), rarityColor, 18, 1)
	local nameLabel = line(prefix .. species.name, if mutation ~= "None" then mutColor else Color3.new(1, 1, 1), 24, 2)
	local detail = line("", Color3.fromRGB(255, 230, 120), 22, 3)
	if species.rarity == "Secret" then
		local grad = Instance.new("UIGradient")
		grad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 255, 200)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 80, 255)),
		})
		grad.Parent = nameLabel
	end
	gui.Parent = adornee
	return gui, nameLabel, detail
end

return CloudlingModel
