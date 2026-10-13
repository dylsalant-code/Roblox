--!nonstrict
-- HUD.luau
-- Always-on interface: Sparkle counter, income rate, menu buttons with
-- notification badges, and live status chips (weather, events, boosts).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CloudlingData = require(Shared.CloudlingData)
local Formulas = require(Shared.Formulas)
local UI = require(script.Parent.UI)
local State = require(script.Parent.State)

local HUD = {}

local sparkleLabel: TextLabel
local incomeLabel: TextLabel
local counterFrame: Frame
local badges: { [string]: TextLabel } = {}
local chips: { [string]: TextLabel } = {}
local displayed = 0

function HUD.CounterPosition(): Vector2
	return counterFrame.AbsolutePosition + counterFrame.AbsoluteSize / 2
end

function HUD.Bump()
	local s = counterFrame:FindFirstChildOfClass("UIScale") :: UIScale
	s.Scale = 1.15
	TweenService:Create(s, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

local function menuButton(parent: Instance, order: number, icon: string, text: string, color: Color3, onClick: () -> ()): TextButton
	local b = UI.Button({ Text = "", Color = color, Size = UDim2.fromOffset(72, 72), LayoutOrder = order, Parent = parent, OnClick = onClick })
	b.Name = text
	UI.Label({ Text = icon, Size = UDim2.fromOffset(46, 40), Position = UDim2.new(0.5, 0, 0, 6), AnchorPoint = Vector2.new(0.5, 0), Parent = b })
	UI.Label({ Text = text, Size = UDim2.new(1, -6, 0, 20), Position = UDim2.new(0.5, 0, 1, -24), AnchorPoint = Vector2.new(0.5, 0), Parent = b })
	local badge = UI.Label({
		Name = "Badge",
		Text = "!",
		Size = UDim2.fromOffset(26, 26),
		Position = UDim2.new(1, -14, 0, -10),
		BackgroundTransparency = 0,
		BackgroundColor3 = UI.Colors.Red,
		Visible = false,
		Parent = b,
	})
	UI.Corner(13).Parent = badge
	badges[text] = badge
	return b
end

local function chip(parent: Instance, key: string, order: number, color: Color3): TextLabel
	local c = UI.Label({
		Name = key,
		Text = "",
		Size = UDim2.fromOffset(250, 36),
		BackgroundTransparency = 0.1,
		BackgroundColor3 = color,
		LayoutOrder = order,
		Visible = false,
		Parent = parent,
	})
	UI.Corner(12).Parent = c
	UI.New("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), Parent = c })
	chips[key] = c
	return c
end

function HUD.Init(screen: ScreenGui, open: (string) -> ())
	-- Sparkle counter (top center)
	counterFrame = UI.New("Frame", {
		Name = "Counter",
		Size = UDim2.fromOffset(280, 58),
		Position = UDim2.new(0.5, 0, 0, 8),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		Parent = screen,
	}, {
		UI.Corner(29),
		UI.Stroke(4),
		UI.New("UIScale"),
		UI.New("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 250, 220), Color3.fromRGB(255, 225, 140)) }),
	})
	UI.Label({ Text = "✨", Size = UDim2.fromOffset(46, 46), Position = UDim2.fromOffset(8, 6), Parent = counterFrame })
	sparkleLabel = UI.Label({ Text = "0", Size = UDim2.new(1, -66, 0, 44), Position = UDim2.fromOffset(56, 7), TextXAlignment = Enum.TextXAlignment.Left, Parent = counterFrame })
	incomeLabel = UI.Label({
		Text = "+0/s",
		Size = UDim2.fromOffset(200, 26),
		Position = UDim2.new(0.5, 0, 1, 4),
		AnchorPoint = Vector2.new(0.5, 0),
		TextColor3 = Color3.fromRGB(255, 240, 150),
		Stroke = true,
		Parent = counterFrame,
	})

	-- Menu buttons (left side, vertically centered — clear of mobile thumbstick)
	local menu = UI.New("Frame", {
		Name = "Menu",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(160, 330),
		Position = UDim2.new(0, 10, 0.5, -10),
		AnchorPoint = Vector2.new(0, 0.5),
		Parent = screen,
	}, {
		UI.New("UIGridLayout", { CellSize = UDim2.fromOffset(72, 72), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	menuButton(menu, 1, "🛒", "Shop", UI.Colors.Yellow, function() open("Shop") end)
	menuButton(menu, 2, "📜", "Quests", UI.Colors.Green, function() open("Quests") end)
	menuButton(menu, 3, "📖", "Index", UI.Colors.Blue, function() open("Index") end)
	menuButton(menu, 4, "🔁", "Rebirth", UI.Colors.Purple, function() open("Rebirth") end)
	menuButton(menu, 5, "🏝️", "Home", UI.Colors.Pink, function()
		State.Send("GoHome")
	end)
	menuButton(menu, 6, "⚙️", "Settings", UI.Colors.Grey, function() open("Settings") end)

	-- Status chips (top right)
	local status = UI.New("Frame", {
		Name = "Status",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(250, 220),
		Position = UDim2.new(1, -12, 0, 8),
		AnchorPoint = Vector2.new(1, 0),
		Parent = screen,
	}, {
		UI.New("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Right }),
	})
	chip(status, "Weather", 1, UI.Colors.Purple)
	chip(status, "Event", 2, UI.Colors.Orange)
	chip(status, "Boost", 3, UI.Colors.Yellow)
	chip(status, "Friends", 4, UI.Colors.Pink)
	chip(status, "Community", 5, UI.Colors.Blue)

	State.Changed:Connect(function()
		HUD.Refresh()
	end)

	-- Smoothly count the Sparkle number up/down + tick timers.
	local timerAcc = 0
	RunService.RenderStepped:Connect(function(dt)
		local target = State.data.sparkles or 0
		if math.abs(target - displayed) < 1 then
			displayed = target
		else
			displayed += (target - displayed) * math.min(1, dt * 10)
		end
		sparkleLabel.Text = Formulas.Format(math.floor(displayed))
		timerAcc += dt
		if timerAcc > 0.5 then
			timerAcc = 0
			HUD.RefreshChips()
		end
	end)
end

function HUD.RefreshChips()
	local now = State.Now()
	local weather = workspace:GetAttribute("Weather")
	local wc = chips.Weather
	if weather and weather ~= "" then
		local def = CloudlingData.Weather[weather]
		wc.Visible = true
		wc.BackgroundColor3 = def.color
		wc.Text = string.format("%s %s  %s", def.icon, def.name, Formulas.FormatTime((workspace:GetAttribute("WeatherEnds") or now) - now))
	else
		wc.Visible = false
	end

	local eventName = workspace:GetAttribute("SeasonalEventName")
	chips.Event.Visible = eventName ~= nil and eventName ~= ""
	chips.Event.Text = "🎃 " .. tostring(eventName) .. " event live!"
	if workspace:GetAttribute("SeasonalEvent") == "Frosty" then
		chips.Event.Text = "❄️ " .. tostring(eventName) .. " event live!"
	end

	local boostUntil = State.data.boostUntil or 0
	chips.Boost.Visible = boostUntil > now
	chips.Boost.Text = "⚡ 2x Sparkles  " .. Formulas.FormatTime(boostUntil - now)

	local mult = State.data.multipliers
	chips.Friends.Visible = mult ~= nil and mult.friends > 0
	chips.Friends.Text = mult and string.format("👯 Friend Boost +%d%%", mult.friends * 100) or ""

	local cBoost = workspace:GetAttribute("CommunityBoost") or 0
	chips.Community.Visible = cBoost > 0
	chips.Community.Text = string.format("🌍 Community +%d%%", cBoost * 100)
end

function HUD.Refresh()
	local d = State.data
	incomeLabel.Text = "+" .. Formulas.Format(math.floor(d.income or 0)) .. " /s"

	-- Quests badge: claimable quests or login reward.
	local claimable = 0
	if d.daily then
		for _, q in d.daily.quests do
			if q.progress >= q.target and not q.claimed then
				claimable += 1
			end
		end
	end
	if d.login and d.login.claimedDay ~= d.today then
		claimable += 1
	end
	badges.Quests.Visible = claimable > 0
	badges.Quests.Text = tostring(claimable)

	-- Rebirth badge when affordable.
	if d.rebirths then
		badges.Rebirth.Visible = (d.sparkles or 0) >= Formulas.RebirthCost(d.rebirths)
	end
	HUD.RefreshChips()
end

return HUD
