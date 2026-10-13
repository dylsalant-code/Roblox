--!nonstrict
-- IndexPanel.luau
-- The Cloudling Index (collection book). Discovered species show a live 3D
-- preview; undiscovered ones are mysterious silhouettes. Four dots show which
-- mutations (Normal / Golden / Rainbow / Galaxy) you've found.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CloudlingData = require(Shared.CloudlingData)
local CloudlingModel = require(Shared.CloudlingModel)
local Formulas = require(Shared.Formulas)
local UI = require(script.Parent.UI)
local State = require(script.Parent.State)

local IndexPanel = {}

local grid: ScrollingFrame
local header: TextLabel
local built = false
local entries: { [string]: { card: Frame, viewport: ViewportFrame, name: TextLabel, dots: { Frame }, preview: boolean } } = {}

local function buildPreview(viewport: ViewportFrame, speciesId: string, silhouette: boolean)
	viewport:ClearAllChildren()
	local model = CloudlingModel.Build(speciesId, "None")
	for _, d in model:GetDescendants() do
		if d:IsA("ParticleEmitter") or d:IsA("PointLight") or d:IsA("BillboardGui") then
			d:Destroy()
		elseif silhouette and d:IsA("BasePart") then
			d.Color = Color3.fromRGB(60, 50, 90)
			d.Material = Enum.Material.SmoothPlastic
		end
	end
	model:PivotTo(CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(200), 0))
	model.Parent = viewport
	local species = CloudlingData.Get(speciesId) :: CloudlingData.Species
	local cam = Instance.new("Camera")
	cam.FieldOfView = 40
	local dist = species.size * 3.2
	cam.CFrame = CFrame.lookAt(Vector3.new(dist * 0.35, species.size * 0.4, -dist), Vector3.new(0, species.size * 0.1, 0))
	cam.Parent = viewport
	viewport.CurrentCamera = cam
end

local function build()
	built = true
	local order = 0
	for _, rarityName in CloudlingData.RarityOrder do
		for _, s in CloudlingData.Species do
			if s.rarity == rarityName then
				order += 1
				local rarity = CloudlingData.Rarities[s.rarity]
				local card = UI.Card({ LayoutOrder = order, Parent = grid }, rarity.color)
				UI.New("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), rarity.color:Lerp(Color3.new(1, 1, 1), 0.5)), Parent = card })
				local viewport = UI.New("ViewportFrame", {
					Size = UDim2.new(1, -16, 0, 100),
					Position = UDim2.fromOffset(8, 8),
					BackgroundTransparency = 1,
					Ambient = Color3.fromRGB(200, 200, 220),
					LightColor = Color3.new(1, 1, 1),
					LightDirection = Vector3.new(-1, -1, 1),
					Parent = card,
				})
				local name = UI.Label({ Text = "???", Size = UDim2.new(1, -12, 0, 24), Position = UDim2.fromOffset(6, 110), Parent = card })
				UI.Label({
					Text = s.rarity .. (if s.event then " • Event" else ""),
					Size = UDim2.new(1, -12, 0, 18),
					Position = UDim2.fromOffset(6, 134),
					TextColor3 = UI.Darker(rarity.color, 0.2),
					Parent = card,
				})
				local dotsFrame = UI.New("Frame", {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 16),
					Position = UDim2.fromOffset(0, 156),
					Parent = card,
				}, {
					UI.New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6) }),
				})
				local dots = {}
				for i, mutName in CloudlingData.MutationOrder do
					local mut = CloudlingData.Mutations[mutName]
					local dot = UI.New("Frame", {
						Size = UDim2.fromOffset(16, 16),
						BackgroundColor3 = if mutName == "None" then Color3.fromRGB(240, 240, 255) else mut.color,
						LayoutOrder = i,
						Parent = dotsFrame,
					}, { UI.Corner(8), UI.Stroke(2) })
					table.insert(dots, dot)
				end
				entries[s.id] = { card = card, viewport = viewport, name = name, dots = dots, preview = false }
			end
		end
	end
end

function IndexPanel.Refresh()
	if not built then
		return
	end
	local index = State.data.index or {}
	local found = 0
	for _, s in CloudlingData.Species do
		local e = entries[s.id]
		local any = false
		for i, mutName in CloudlingData.MutationOrder do
			local has = index[CloudlingData.IndexKey(s.id, mutName)] == true
			if has then
				found += 1
				any = true
			end
			e.dots[i].BackgroundTransparency = if has then 0 else 0.8
		end
		e.name.Text = if any then s.name else "???"
		if not e.preview or e.card:GetAttribute("Discovered") ~= any then
			e.preview = true
			e.card:SetAttribute("Discovered", any)
			buildPreview(e.viewport, s.id, not any)
		end
	end
	header.Text = string.format("📖 Discovered %d / %d  (%d%%)  —  first catches give bonus Sparkles!", found, CloudlingData.IndexTotal(), math.floor(found / CloudlingData.IndexTotal() * 100))
	local _ = Formulas
end

function IndexPanel.Init()
	local content = UI.Panel("Index", "📖 Cloudling Index", UI.Colors.Blue, Vector2.new(860, 560), function()
		if not built then
			build()
		end
		IndexPanel.Refresh()
	end)
	header = UI.Label({ Text = "", Size = UDim2.new(1, 0, 0, 30), TextColor3 = UI.Colors.Text, Parent = content })
	grid = UI.Scroller({ Size = UDim2.new(1, 0, 1, -38), Position = UDim2.fromOffset(0, 36), Parent = content }, Vector2.new(150, 182), 10)
	State.Changed:Connect(function(full)
		if full and UI.IsOpen("Index") then
			IndexPanel.Refresh()
		end
	end)
end

return IndexPanel
