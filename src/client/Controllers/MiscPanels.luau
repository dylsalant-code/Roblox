--!nonstrict
-- MiscPanels.luau
-- Rebirth panel (with two-step confirmation) and Settings panel.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local UI = require(script.Parent.UI)
local State = require(script.Parent.State)

local MiscPanels = {}

-- Rebirth ----------------------------------------------------------------------
local rebirthInfo: TextLabel
local rebirthButton: TextButton
local setRebirthBar: (number, string?) -> ()
local confirming = false

local function refreshRebirth()
	local d = State.data
	if d.rebirths == nil then
		return
	end
	local cost = Formulas.RebirthCost(d.rebirths)
	local now = Formulas.RebirthMultiplier(d.rebirths)
	local nextMult = Formulas.RebirthMultiplier(d.rebirths + 1)
	rebirthInfo.Text = string.format(
		"Rebirth %d → %d\nIncome multiplier: x%s → x%s (forever!)\n\nResets: Sparkles and Cloudlings\nKeeps: Index, pedestals, achievements, passes",
		d.rebirths, d.rebirths + 1, Formulas.Format(now), Formulas.Format(nextMult)
	)
	setRebirthBar(d.sparkles / cost, "✨" .. Formulas.Format(math.floor(d.sparkles)) .. " / " .. Formulas.Format(cost))
	if d.sparkles >= cost then
		UI.SetButton(rebirthButton, if confirming then "Tap again to confirm!" else "🔁 Rebirth!", if confirming then UI.Colors.Orange else UI.Colors.Purple)
	else
		confirming = false
		UI.SetButton(rebirthButton, "Need ✨" .. Formulas.Format(cost - d.sparkles) .. " more", UI.Colors.Grey)
	end
end

-- Settings ---------------------------------------------------------------------
local toggles: { [string]: TextButton } = {}

local function refreshSettings()
	local settings = State.data.settings or {}
	for key, b in toggles do
		local on = settings[key] ~= false
		UI.SetButton(b, if on then "ON" else "OFF", if on then UI.Colors.Green else UI.Colors.Grey)
	end
end

function MiscPanels.Init()
	local content = UI.Panel("Rebirth", "🔁 Rebirth", UI.Colors.Purple, Vector2.new(620, 460), function()
		confirming = false
		refreshRebirth()
	end)
	rebirthInfo = UI.Label({ Text = "", Size = UDim2.new(1, 0, 0, 170), TextColor3 = UI.Colors.Text, Parent = content })
	local _, setBar = UI.ProgressBar({ Size = UDim2.new(1, -40, 0, 40), Position = UDim2.fromOffset(20, 190), Parent = content }, UI.Colors.Purple)
	setRebirthBar = setBar
	rebirthButton = UI.Button({
		Text = "🔁 Rebirth!",
		Color = UI.Colors.Purple,
		Size = UDim2.fromOffset(320, 70),
		Position = UDim2.new(0.5, 0, 0, 260),
		AnchorPoint = Vector2.new(0.5, 0),
		Parent = content,
		OnClick = function()
			local d = State.data
			if d.sparkles < Formulas.RebirthCost(d.rebirths) then
				return
			end
			if not confirming then
				confirming = true
				refreshRebirth()
				task.delay(4, function()
					confirming = false
					if UI.IsOpen("Rebirth") then
						refreshRebirth()
					end
				end)
				return
			end
			confirming = false
			State.Send("Rebirth")
			UI.ClosePanel()
		end,
	})

	local settings = UI.Panel("Settings", "⚙️ Settings", UI.Colors.Grey, Vector2.new(520, 420), refreshSettings)
	UI.New("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = settings })
	for i, row in { { "music", "🎵 Music" }, { "sfx", "🔊 Sound Effects" }, { "trail", "🌈 Show Trails & Crowns" } } do
		local frame = UI.Card({ Size = UDim2.new(1, 0, 0, 64), LayoutOrder = i, Parent = settings })
		UI.Label({ Text = row[2], Size = UDim2.new(1, -170, 1, -16), Position = UDim2.fromOffset(14, 8), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UI.Colors.Text, Parent = frame })
		local key = row[1]
		toggles[key] = UI.Button({
			Text = "ON",
			Size = UDim2.fromOffset(130, 46),
			Position = UDim2.new(1, -10, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			Parent = frame,
			OnClick = function()
				local s = State.data.settings or {}
				State.Send("Setting", { key = key, value = s[key] == false })
			end,
		})
	end
	UI.Button({
		Text = "Skip / End Tutorial",
		Color = UI.Colors.Blue,
		Size = UDim2.new(1, 0, 0, 54),
		LayoutOrder = 10,
		Parent = settings,
		OnClick = function()
			State.Send("SkipTutorial")
		end,
	})
	UI.Label({
		Text = Config.GameName .. " • Be kind, have fun! ☁",
		Size = UDim2.new(1, 0, 0, 26),
		LayoutOrder = 11,
		TextColor3 = UI.Colors.Text,
		Parent = settings,
	})

	State.Changed:Connect(function()
		if UI.IsOpen("Rebirth") then
			refreshRebirth()
		end
		if UI.IsOpen("Settings") then
			refreshSettings()
		end
	end)
end

return MiscPanels
