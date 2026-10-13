--!nonstrict
-- Effects.luau
-- All client-side juice: weather skies, catch flights, Sparkle bursts that
-- fly into the HUD counter, level-up pops, hearts, rainbow mutations,
-- idle bobbing, VIP crowns, rainbow trails and VIP chat tags.
-- Purely cosmetic; nothing here affects game state.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CloudlingData = require(Shared.CloudlingData)
local Formulas = require(Shared.Formulas)
local Remotes = require(Shared.Remotes)
local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Sound = require(script.Parent.Sound)
local HUD = require(script.Parent.HUD)

local Effects = {}

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local fxGui: ScreenGui
local fxFolder: Folder
local weatherPart: Part
local weatherEmitter: ParticleEmitter

-- Helpers -------------------------------------------------------------------------
local function burst(position: Vector3, color: Color3, count: number, size: number?)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.one
	p.Position = position
	p.Parent = fxFolder
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(color)
	e.LightEmission = 0.8
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size or 0.8), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(0.6, 1.1)
	e.Speed = NumberRange.new(8, 16)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, -20, 0)
	e.Rate = 0
	e.Parent = p
	e:Emit(count)
	task.delay(1.5, function()
		p:Destroy()
	end)
end

local function floatingText(position: Vector3, text: string, color: Color3)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = position
	anchor.Parent = fxFolder
	local gui = UI.New("BillboardGui", {
		Size = UDim2.fromOffset(220, 50),
		AlwaysOnTop = true,
		LightInfluence = 0,
		Adornee = anchor,
		Parent = anchor,
	})
	local label = UI.Label({ Text = text, Size = UDim2.fromScale(1, 1), TextColor3 = color, Stroke = true, StrokeThickness = 3, Parent = gui })
	TweenService:Create(gui, TweenInfo.new(1.4, Enum.EasingStyle.Quad), { StudsOffset = Vector3.new(0, 5, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 }):Play()
	task.delay(1.5, function()
		anchor:Destroy()
	end)
end

-- Little ✨ icons that fly from a world point (or screen centre) into the counter.
local function sparklesToCounter(from: Vector3?, count: number)
	local start: Vector2
	if from then
		local p, onScreen = camera:WorldToScreenPoint(from)
		start = if onScreen then Vector2.new(p.X, p.Y) else camera.ViewportSize / 2
	else
		start = camera.ViewportSize / 2
	end
	local target = HUD.CounterPosition()
	for i = 1, count do
		local icon = UI.Label({
			Text = "✨",
			Size = UDim2.fromOffset(34, 34),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(start.X + math.random(-40, 40), start.Y + math.random(-40, 40)),
			Parent = fxGui,
		})
		task.delay(i * 0.04, function()
			local t = TweenService:Create(icon, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.fromOffset(target.X, target.Y),
				Size = UDim2.fromOffset(18, 18),
			})
			t:Play()
			t.Completed:Wait()
			icon:Destroy()
			if i == count then
				HUD.Bump()
			end
		end)
	end
end

-- Effect handlers --------------------------------------------------------------
local handlers: { [string]: (any) -> () } = {}

function handlers.CatchFly(p)
	local species = CloudlingData.Get(p.species)
	if not species then
		return
	end
	local rarity = CloudlingData.Rarities[species.rarity]
	local color = if p.mutation ~= "None" then CloudlingData.Mutations[p.mutation].color else rarity.color
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.one * 2
	ball.Material = Enum.Material.Neon
	ball.Color = color
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.Position = p.from
	ball.Parent = fxFolder
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.8, 0)
	a0.Parent = ball
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.8, 0)
	a1.Parent = ball
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	trail.Lifetime = 0.5
	trail.LightEmission = 1
	trail.Parent = ball

	local mine = p.userId == player.UserId
	if mine then
		Sound.Play("Catch", 0.6, 1 + rarity.order * 0.05)
	end
	burst(p.from, color, 25)
	-- Arc flight using a quadratic bezier.
	local to: Vector3 = p.to or p.from
	local mid = (p.from + to) / 2 + Vector3.new(0, 30, 0)
	local start = os.clock()
	local duration = 1.1
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = math.min(1, (os.clock() - start) / duration)
		local a = p.from:Lerp(mid, t)
		local b = mid:Lerp(to, t)
		ball.Position = a:Lerp(b, t)
		if t >= 1 then
			conn:Disconnect()
			burst(to + Vector3.new(0, 3, 0), color, 30)
			if mine then
				floatingText(to + Vector3.new(0, 6, 0), "NEW CLOUDLING!", color)
			end
			task.delay(0.3, function()
				ball:Destroy()
			end)
		end
	end)
end

function handlers.Collect(p)
	Sound.Play("Collect", 0.6, 1.2)
	if p.position then
		floatingText(p.position + Vector3.new(0, 4, 0), "+✨" .. Formulas.Format(p.amount), Color3.fromRGB(255, 230, 90))
		burst(p.position + Vector3.new(0, 1, 0), Color3.fromRGB(255, 220, 80), 30)
	end
	sparklesToCounter(p.position, 10)
end

function handlers.Reward(p)
	Sound.Play("Collect", 0.7, 1.4)
	sparklesToCounter(nil, 14)
	local _ = p
end

function handlers.LevelUp(p)
	if not p.position then
		return
	end
	Sound.Play("Upgrade", 0.6, 1.2)
	burst(p.position + Vector3.new(0, 3, 0), Color3.fromRGB(120, 255, 160), 30)
	floatingText(p.position + Vector3.new(0, 7, 0), "LEVEL " .. p.level .. "!", Color3.fromRGB(120, 255, 160))
end

function handlers.Hearts(p)
	burst(p.position, Color3.fromRGB(255, 100, 150), 25, 1.2)
end

function handlers.Rebirth(p)
	if p.userId ~= player.UserId then
		return
	end
	local flash = UI.New("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(220, 200, 255),
		BackgroundTransparency = 0,
		ZIndex = 100,
		Parent = fxGui,
	})
	TweenService:Create(flash, TweenInfo.new(1.2), { BackgroundTransparency = 1 }):Play()
	Sound.Play("Announce", 0.8, 0.8)
	task.delay(1.3, function()
		flash:Destroy()
	end)
end

function handlers.Splash()
	Sound.Play("Splash", 0.6)
end

-- Weather ------------------------------------------------------------------------
local WEATHER_VISUALS = {
	RainbowStorm = {
		colors = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 110)),
			ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 225, 80)),
			ColorSequenceKeypoint.new(0.66, Color3.fromRGB(90, 180, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 120, 255)),
		}),
		rate = 160,
		accel = Vector3.new(0, -40, 0),
		tint = Color3.fromRGB(255, 225, 255),
		clock = 14.5,
	},
	GoldenHour = { colors = ColorSequence.new(Color3.fromRGB(255, 215, 80)), rate = 70, accel = Vector3.new(0, -8, 0), tint = Color3.fromRGB(255, 225, 180), clock = 17.6 },
	Starfall = { colors = ColorSequence.new(Color3.fromRGB(190, 160, 255)), rate = 90, accel = Vector3.new(6, -60, 0), tint = Color3.fromRGB(200, 190, 255), clock = 20.5 },
	BubbleBreeze = { colors = ColorSequence.new(Color3.fromRGB(180, 235, 255)), rate = 60, accel = Vector3.new(0, 14, 0), tint = Color3.fromRGB(225, 245, 255), clock = 13 },
}

local function applyWeather()
	local key = workspace:GetAttribute("Weather")
	local v = WEATHER_VISUALS[key or ""]
	local tint = Lighting:FindFirstChild("WeatherTint") :: ColorCorrectionEffect?
	if v then
		weatherEmitter.Color = v.colors
		weatherEmitter.Rate = v.rate
		weatherEmitter.Acceleration = v.accel
		weatherEmitter.Enabled = true
		if tint then
			TweenService:Create(tint, TweenInfo.new(2), { TintColor = v.tint }):Play()
		end
		TweenService:Create(Lighting, TweenInfo.new(3), { ClockTime = v.clock }):Play()
	else
		weatherEmitter.Enabled = false
		if tint then
			TweenService:Create(tint, TweenInfo.new(2), { TintColor = Color3.new(1, 1, 1) }):Play()
		end
		TweenService:Create(Lighting, TweenInfo.new(3), { ClockTime = 14.5 }):Play()
	end
end

-- Cosmetics: rainbow mutation bodies, bobbing, crowns, trails -----------------------
local rainbowParts: { BasePart } = {}

local function trackRainbow(inst: Instance)
	if inst:IsA("BasePart") then
		table.insert(rainbowParts, inst)
	end
end

local function untrackRainbow(inst: Instance)
	local i = table.find(rainbowParts, inst :: any)
	if i then
		table.remove(rainbowParts, i)
	end
end

local function startBob(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local root = model.PrimaryPart or model:WaitForChild("Root", 5) :: BasePart?
	if not root then
		return
	end
	local base = root.CFrame
	local tween = TweenService:Create(root, TweenInfo.new(1.2 + math.random() * 0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		CFrame = base * CFrame.new(0, 0.7, 0) * CFrame.Angles(0, math.rad(8), 0),
	})
	tween:Play()
	model.AncestryChanged:Connect(function()
		if not model.Parent then
			tween:Cancel()
		end
	end)
end

local function cosmeticsEnabled(): boolean
	local s = State.data.settings
	return not s or s.trail ~= false
end

local function decorateCharacter(p: Player)
	local character = p.Character
	if not character then
		return
	end
	local head = character:FindFirstChild("Head") :: BasePart?
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local show = cosmeticsEnabled()

	-- VIP crown
	local crown = character:FindFirstChild("VipCrown")
	if p:GetAttribute("VIP") and show and head then
		if not crown then
			local c = Instance.new("Part")
			c.Name = "VipCrown"
			c.Shape = Enum.PartType.Cylinder
			c.Size = Vector3.new(0.5, 1.4, 1.4)
			c.Color = Color3.fromRGB(255, 205, 50)
			c.Material = Enum.Material.Foil
			c.CanCollide = false
			c.CanQuery = false
			c.Massless = true
			c.CFrame = head.CFrame * CFrame.new(0, head.Size.Y / 2 + 0.3, 0) * CFrame.Angles(0, 0, math.pi / 2)
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = head
			weld.Part1 = c
			weld.Parent = c
			local sparkle = Instance.new("Sparkles")
			sparkle.SparkleColor = Color3.fromRGB(255, 220, 100)
			sparkle.Parent = c
			c.Parent = character
		end
	elseif crown then
		crown:Destroy()
	end

	-- Rainbow trail
	local trail = root and root:FindFirstChild("RainbowTrail")
	if p:GetAttribute("RainbowTrail") and show and root then
		if not trail then
			local a0 = Instance.new("Attachment")
			a0.Name = "TrailA0"
			a0.Position = Vector3.new(0, 1, 0)
			a0.Parent = root
			local a1 = Instance.new("Attachment")
			a1.Name = "TrailA1"
			a1.Position = Vector3.new(0, -1.5, 0)
			a1.Parent = root
			local t = Instance.new("Trail")
			t.Name = "RainbowTrail"
			t.Attachment0 = a0
			t.Attachment1 = a1
			t.Lifetime = 0.8
			t.LightEmission = 0.7
			t.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 110)),
				ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 225, 80)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(110, 220, 120)),
				ColorSequenceKeypoint.new(0.75, Color3.fromRGB(90, 180, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 120, 255)),
			})
			t.Parent = root
		end
	elseif trail then
		trail:Destroy()
	end
end

local function watchPlayer(p: Player)
	p.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart", 5)
		character:WaitForChild("Head", 5)
		decorateCharacter(p)
	end)
	p:GetAttributeChangedSignal("VIP"):Connect(function()
		decorateCharacter(p)
	end)
	p:GetAttributeChangedSignal("RainbowTrail"):Connect(function()
		decorateCharacter(p)
	end)
	if p.Character then
		task.spawn(decorateCharacter, p)
	end
end

-- Chat tags ---------------------------------------------------------------------------
local function setupChatTags()
	TextChatService.OnIncomingMessage = function(message: TextChatMessage)
		local props = Instance.new("TextChatMessageProperties")
		local source = message.TextSource
		if source then
			local p = Players:GetPlayerByUserId(source.UserId)
			if p and p:GetAttribute("VIP") then
				props.PrefixText = "<font color='#FFD040'>[👑 VIP]</font> " .. message.PrefixText
			end
		end
		return props
	end
end

function Effects.Init()
	fxGui = UI.New("ScreenGui", {
		Name = "FX",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		DisplayOrder = 5,
		Parent = player:WaitForChild("PlayerGui"),
	})
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "ClientFX"
	fxFolder.Parent = workspace

	weatherPart = Instance.new("Part")
	weatherPart.Name = "WeatherEmitter"
	weatherPart.Anchored = true
	weatherPart.CanCollide = false
	weatherPart.CanQuery = false
	weatherPart.CanTouch = false
	weatherPart.Transparency = 1
	weatherPart.Size = Vector3.new(160, 1, 160)
	weatherPart.Parent = fxFolder
	weatherEmitter = Instance.new("ParticleEmitter")
	weatherEmitter.Enabled = false
	weatherEmitter.LightEmission = 0.8
	weatherEmitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.2) })
	weatherEmitter.Lifetime = NumberRange.new(2, 3)
	weatherEmitter.Speed = NumberRange.new(0, 2)
	weatherEmitter.EmissionDirection = Enum.NormalId.Bottom
	weatherEmitter.Parent = weatherPart
	workspace:GetAttributeChangedSignal("Weather"):Connect(applyWeather)
	applyWeather()

	Remotes.Get("Effect").OnClientEvent:Connect(function(kind: string, payload: any)
		local h = handlers[kind]
		if h then
			h(payload)
		end
	end)

	for _, inst in CollectionService:GetTagged("RainbowBody") do
		trackRainbow(inst)
	end
	CollectionService:GetInstanceAddedSignal("RainbowBody"):Connect(trackRainbow)
	CollectionService:GetInstanceRemovedSignal("RainbowBody"):Connect(untrackRainbow)
	for _, m in CollectionService:GetTagged("OwnedCloudling") do
		task.spawn(startBob, m)
	end
	CollectionService:GetInstanceAddedSignal("OwnedCloudling"):Connect(startBob)

	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for i, part in rainbowParts do
			part.Color = Color3.fromHSV((t * 0.25 + i * 0.13) % 1, 0.55, 1)
		end
		local camPos = camera.CFrame.Position
		local key = workspace:GetAttribute("Weather")
		local yOff = if key == "BubbleBreeze" then -20 else 45
		weatherPart.Position = Vector3.new(camPos.X, camPos.Y + yOff, camPos.Z)
		weatherEmitter.EmissionDirection = if key == "BubbleBreeze" then Enum.NormalId.Top else Enum.NormalId.Bottom
	end)

	for _, p in Players:GetPlayers() do
		watchPlayer(p)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	State.Changed:Connect(function(full)
		if full then
			for _, p in Players:GetPlayers() do
				decorateCharacter(p)
			end
		end
	end)
	setupChatTags()
end

return Effects
