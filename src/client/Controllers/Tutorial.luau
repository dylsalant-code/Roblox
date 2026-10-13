--!nonstrict
-- Tutorial.luau
-- 15-second onboarding. A glowing beam + bouncing arrow guide new players
-- through the core loop: catch -> collect -> upgrade. Steps are driven by
-- the server (which advances them when the real action happens).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Formulas = require(Shared.Formulas)
local Remotes = require(Shared.Remotes)
local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Pedestals = require(script.Parent.Pedestals)

local Tutorial = {}

local player = Players.LocalPlayer
local box: Frame
local text: TextLabel
local step = -1
local beam: Beam
local targetAttachment: Attachment
local arrowPart: Part
local playerAttachment: Attachment?

local STEPS = {
	[0] = "☁ Welcome! Walk to the glowing Rainbow Stream and catch a Cloudling you can afford (press E or tap)!",
	[1] = "✨ Your Cloudling is making Sparkles! Step on the golden Collect Pad on your island to grab them.",
	[2] = "⬆ Upgrade your Cloudling at its pedestal (E) so it earns even faster!",
	[3] = "🎉 You're a natural! Catch rarer Cloudlings, finish Daily Quests 📜 and climb the leaderboards 🏆",
}

-- Finds the current tutorial target position.
local function findTarget(): Vector3?
	if step == 0 then
		local stream = workspace:FindFirstChild("Stream")
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not stream or not root then
			return nil
		end
		local best, bestDist = nil, math.huge
		local money = State.data.sparkles or 0
		for _, model in stream:GetChildren() do
			if model:IsA("Model") and model.PrimaryPart then
				local species = model:GetAttribute("Species")
				local mutation = model:GetAttribute("Mutation") or "None"
				if species and Formulas.CatchPrice(species, mutation) <= money then
					local d = (model.PrimaryPart.Position - root.Position).Magnitude
					-- Prefer Cloudlings still upstream (they'll come toward you).
					if model.PrimaryPart.Position.X > root.Position.X + 15 then
						d += 200
					end
					if d < bestDist then
						best, bestDist = model.PrimaryPart.Position, d
					end
				end
			end
		end
		return best
	end
	local plot = Pedestals.GetPlotFolder()
	if not plot then
		return nil
	end
	if step == 1 then
		local pad = plot:FindFirstChild("CollectPad") :: BasePart?
		return pad and pad.Position
	elseif step == 2 then
		for _, c in State.data.cloudlings or {} do
			local pedestal = plot:FindFirstChild("Pedestal" .. c.slot) :: BasePart?
			if pedestal then
				return pedestal.Position
			end
		end
	end
	return nil
end

local function attachToCharacter()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and (not playerAttachment or playerAttachment.Parent ~= root) then
		local a = Instance.new("Attachment")
		a.Name = "TutorialAttachment"
		a.Parent = root
		playerAttachment = a
		beam.Attachment0 = a
	end
end

local function setStep(newStep: number)
	step = newStep
	local msg = STEPS[newStep]
	box.Visible = msg ~= nil
	if msg then
		text.Text = msg
		local s = box:FindFirstChildOfClass("UIScale") :: UIScale
		s.Scale = 0.6
		TweenService:Create(s, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	if newStep == 3 then
		task.delay(9, function()
			if step == 3 then
				State.Send("SkipTutorial")
			end
		end)
	end
end

function Tutorial.Init(screen: ScreenGui)
	box = UI.New("Frame", {
		Name = "Tutorial",
		Size = UDim2.fromOffset(620, 82),
		Position = UDim2.new(0.5, 0, 1, -16),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		Visible = false,
		Parent = screen,
	}, { UI.Corner(20), UI.Stroke(4, UI.Colors.Purple), UI.New("UIScale") })
	text = UI.Label({ Text = "", Size = UDim2.new(1, -110, 1, -16), Position = UDim2.fromOffset(14, 8), TextColor3 = UI.Colors.Text, TextXAlignment = Enum.TextXAlignment.Left, Parent = box })
	UI.Button({
		Text = "Skip",
		Color = UI.Colors.Grey,
		Size = UDim2.fromOffset(80, 40),
		Position = UDim2.new(1, -12, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Parent = box,
		OnClick = function()
			State.Send("SkipTutorial")
		end,
	})

	-- World guide: beam from player to target + bouncing arrow.
	arrowPart = Instance.new("Part")
	arrowPart.Name = "TutorialTarget"
	arrowPart.Anchored = true
	arrowPart.CanCollide = false
	arrowPart.CanQuery = false
	arrowPart.CanTouch = false
	arrowPart.Transparency = 1
	arrowPart.Size = Vector3.one
	arrowPart.Parent = workspace
	targetAttachment = Instance.new("Attachment")
	targetAttachment.Parent = arrowPart
	beam = Instance.new("Beam")
	beam.Attachment1 = targetAttachment
	beam.Width0 = 0.8
	beam.Width1 = 0.8
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.Segments = 20
	beam.CurveSize0 = 6
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 240, 120), Color3.fromRGB(255, 120, 200))
	beam.Transparency = NumberSequence.new(0.2)
	beam.Enabled = false
	beam.Parent = arrowPart
	local arrowGui = UI.New("BillboardGui", {
		Size = UDim2.fromOffset(70, 70),
		StudsOffset = Vector3.new(0, 6, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		Enabled = false,
		Parent = arrowPart,
	})
	local arrow = UI.Label({ Text = "⬇", Size = UDim2.fromScale(1, 1), TextColor3 = Color3.fromRGB(255, 230, 90), Stroke = true, StrokeThickness = 4, Parent = arrowGui })
	TweenService:Create(arrow, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Position = UDim2.fromScale(0, 0.25) }):Play()

	Remotes.Get("Tutorial").OnClientEvent:Connect(setStep)
	-- The first step may arrive before this script loads; read it from state.
	State.Changed:Connect(function(full)
		local t = State.data.tutorial
		if full and t ~= nil and t ~= step then
			setStep(t)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.25)
			local target = if step >= 0 and step < 3 then findTarget() else nil
			if target then
				attachToCharacter()
				arrowPart.Position = target
				beam.Enabled = playerAttachment ~= nil
				arrowGui.Enabled = true
			else
				beam.Enabled = false
				arrowGui.Enabled = false
			end
		end
	end)
end

return Tutorial
