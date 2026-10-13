--!nonstrict
-- Stream.luau
-- Animates Rainbow Stream Cloudlings locally at full frame rate from the
-- deterministic attributes the server sets (StartX, Speed, SpawnTime...),
-- and gives each one a local "Catch" prompt. The server recomputes the same
-- position to validate every catch, so this is smooth AND exploit-safe.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Formulas = require(Shared.Formulas)
local State = require(script.Parent.State)

local Stream = {}

type Tracked = { root: BasePart, model: Model, prompt: ProximityPrompt, phase: number, baseText: string, affordable: boolean? }
local tracked: { [Model]: Tracked } = {}

local function track(model: Instance)
	if not model:IsA("Model") or tracked[model] then
		return
	end
	local root = model.PrimaryPart or model:WaitForChild("Root", 5)
	if not root or not model.Parent then
		return
	end
	local price = model:GetAttribute("Price") or 0
	local mutation = model:GetAttribute("Mutation") or "None"
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CatchPrompt"
	prompt.ActionText = "Catch for ✨" .. Formulas.Format(price)
	prompt.ObjectText = (if mutation ~= "None" then mutation .. " " else "") .. model.Name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 13
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = root
	prompt.Triggered:Connect(function()
		State.Send("Catch", { id = model:GetAttribute("StreamId") })
	end)
	tracked[model] = { root = root, model = model, prompt = prompt, phase = math.random() * math.pi * 2, baseText = prompt.ObjectText, affordable = nil }
end

local function untrack(model: Instance)
	local t = tracked[model :: Model]
	if t then
		t.prompt:Destroy()
		tracked[model :: Model] = nil
	end
end

function Stream.Init()
	for _, m in CollectionService:GetTagged("StreamCloudling") do
		task.spawn(track, m)
	end
	CollectionService:GetInstanceAddedSignal("StreamCloudling"):Connect(track)
	CollectionService:GetInstanceRemovedSignal("StreamCloudling"):Connect(untrack)

	RunService.RenderStepped:Connect(function()
		local now = workspace:GetServerTimeNow()
		local clock = os.clock()
		for model, t in tracked do
			if not model.Parent then
				untrack(model)
				continue
			end
			local x = (model:GetAttribute("StartX") or 0) + (now - (model:GetAttribute("SpawnTime") or now)) * (model:GetAttribute("Speed") or 0)
			local y = (model:GetAttribute("Y") or 5) + math.sin(clock * 2.2 + t.phase) * 0.5
			local pos = Vector3.new(x, y, model:GetAttribute("LaneZ") or 0)
			local face = model:GetAttribute("Face") or 1
			t.root.CFrame = CFrame.lookAt(pos, pos + Vector3.new(0, 0, face)) * CFrame.Angles(0, 0, math.sin(clock * 1.7 + t.phase) * 0.08)
			-- Lock icon when unaffordable so players learn prices at a glance.
			local affordable = (State.data.sparkles or 0) >= (model:GetAttribute("Price") or 0)
			if affordable ~= t.affordable then
				t.affordable = affordable
				t.prompt.ObjectText = if affordable then t.baseText else "🔒 " .. t.baseText
			end
		end
	end)
end

return Stream
