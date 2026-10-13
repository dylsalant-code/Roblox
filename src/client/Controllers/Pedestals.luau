--!nonstrict
-- Pedestals.luau
-- Creates LOCAL proximity prompts on the player's own pedestals (so nobody
-- sees prompts for islands they can't manage) plus a floating "stored
-- Sparkles" counter. The server re-validates ownership and distance.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CloudlingData = require(Shared.CloudlingData)
local Formulas = require(Shared.Formulas)
local UI = require(script.Parent.UI)
local State = require(script.Parent.State)

local Pedestals = {}

local player = Players.LocalPlayer
local currentPlot: number? = nil
local connections: { RBXScriptConnection } = {}
local created: { Instance } = {}

local function cloudlingAt(slot: number): any
	for _, c in State.data.cloudlings or {} do
		if c.slot == slot then
			return c
		end
	end
	return nil
end

local function cleanup()
	for _, c in connections do
		c:Disconnect()
	end
	for _, i in created do
		i:Destroy()
	end
	connections, created = {}, {}
end

local function setupPedestal(pedestal: BasePart)
	local slot = pedestal:GetAttribute("Slot") :: number
	local attach = Instance.new("Attachment")
	attach.Position = Vector3.new(4, 0, 0) -- pedestal is a rotated cylinder: +X is up
	attach.Parent = pedestal
	table.insert(created, attach)

	local main = Instance.new("ProximityPrompt")
	main.KeyboardKeyCode = Enum.KeyCode.E
	main.MaxActivationDistance = 11
	main.RequiresLineOfSight = false
	main.Parent = attach

	local release = Instance.new("ProximityPrompt")
	release.KeyboardKeyCode = Enum.KeyCode.F
	release.GamepadKeyCode = Enum.KeyCode.ButtonY
	release.HoldDuration = 1.2
	release.MaxActivationDistance = 11
	release.RequiresLineOfSight = false
	release.UIOffset = Vector2.new(0, 80)
	release.Parent = attach

	local gui = UI.New("BillboardGui", {
		Size = UDim2.fromOffset(140, 34),
		StudsOffsetWorldSpace = Vector3.new(0, 0.2, 0),
		AlwaysOnTop = true,
		MaxDistance = 45,
		LightInfluence = 0,
		Adornee = pedestal,
		Parent = player:WaitForChild("PlayerGui"),
	})
	table.insert(created, gui)
	local text = UI.Label({ Text = "", Size = UDim2.fromScale(1, 1), TextColor3 = Color3.fromRGB(255, 235, 120), Stroke = true, Parent = gui })

	local function num(name: string): number
		return tonumber(pedestal:GetAttribute(name)) or 0
	end

	local function refresh()
		local state = pedestal:GetAttribute("State")
		local c = cloudlingAt(slot)
		if state == "Occupied" and c then
			local species = CloudlingData.Get(c.id)
			local upCost = num("UpgradeCost")
			main.Enabled = true
			main.ObjectText = string.format("Lv.%d %s", c.lvl, species and species.name or "")
			main.ActionText = if upCost > 0 then "Upgrade ✨" .. Formulas.Format(upCost) else "Max Level!"
			release.Enabled = true
			release.ActionText = "Release (+✨" .. Formulas.Format(num("SellValue")) .. ")"
			release.ObjectText = ""
			local stored = num("Stored")
			text.Text = if stored > 0 then "✨ " .. Formulas.Format(stored) else ""
		elseif state == "Next" then
			main.Enabled = true
			main.ObjectText = "Locked Pedestal"
			main.ActionText = "Unlock ✨" .. Formulas.Format(num("Cost"))
			release.Enabled = false
			text.Text = "🔒 ✨" .. Formulas.Format(num("Cost"))
		else
			main.Enabled = false
			release.Enabled = false
			text.Text = ""
		end
	end

	table.insert(connections, pedestal.AttributeChanged:Connect(refresh))
	table.insert(connections, State.Changed:Connect(function(full)
		if full then
			refresh()
		end
	end))
	table.insert(connections, main.Triggered:Connect(function()
		local state = pedestal:GetAttribute("State")
		if state == "Occupied" then
			State.Send("Upgrade", { slot = slot })
		elseif state == "Next" then
			State.Send("UnlockSlot")
		end
	end))
	table.insert(connections, release.Triggered:Connect(function()
		State.Send("Release", { slot = slot })
	end))
	refresh()
end

local function hideOwnLikePrompt(plotFolder: Instance)
	local sign = plotFolder:FindFirstChild("Sign")
	local prompt = sign and sign:FindFirstChild("LikePrompt", true) :: ProximityPrompt?
	if prompt then
		prompt.Enabled = false
		table.insert(connections, prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
			if prompt.Enabled then
				prompt.Enabled = false
			end
		end))
	end
end

local function bind(plotIndex: number)
	cleanup()
	currentPlot = plotIndex
	local world = workspace:WaitForChild("World", 10)
	local plotFolder = world and world:WaitForChild("Plot" .. plotIndex, 10)
	if not plotFolder then
		return
	end
	for _, child in plotFolder:GetChildren() do
		if child:IsA("BasePart") and child:GetAttribute("Slot") then
			setupPedestal(child)
		end
	end
	hideOwnLikePrompt(plotFolder)
end

function Pedestals.GetPlotFolder(): Instance?
	if not currentPlot then
		return nil
	end
	local world = workspace:FindFirstChild("World")
	return world and world:FindFirstChild("Plot" .. currentPlot)
end

function Pedestals.Init()
	State.Changed:Connect(function(full)
		if full and State.data.plotIndex and State.data.plotIndex ~= currentPlot then
			task.spawn(bind, State.data.plotIndex)
		end
	end)
end

return Pedestals
