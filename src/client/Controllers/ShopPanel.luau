--!nonstrict
-- ShopPanel.luau
-- Transparent, optional shop. Every card states exactly what you get and the
-- Robux price; Roblox's own purchase dialog always confirms before charging.
-- No timers, no fake discounts, no random rewards.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Formulas = require(Shared.Formulas)
local Products = require(Shared.Products)
local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Notify = require(script.Parent.Notify)

local ShopPanel = {}

local player = Players.LocalPlayer
local grid: ScrollingFrame
local currentTab = "Passes"
local cards: { [string]: { button: TextButton, detail: TextLabel? } } = {}

local function buy(kind: string, item: any)
	if item.id == 0 then
		if RunService:IsStudio() then
			State.Send("TestPurchase", { kind = kind, key = item.key })
		else
			Notify.Toast("This item isn't available yet — check back soon!", "info")
		end
		return
	end
	if kind == "pass" then
		MarketplaceService:PromptGamePassPurchase(player, item.id)
	else
		MarketplaceService:PromptProductPurchase(player, item.id)
	end
end

local function sparklePackAmount(item: any): number
	local mult = State.data.multipliers
	local base = (State.data.income or 0)
	-- Server uses income without temporary boosts; mirror that here.
	if mult and mult.total > 0 then
		base = base / mult.total * mult.rebirth
	end
	return Formulas.ScaledReward(base, item.seconds, item.minimum)
end

local function makeCard(kind: string, item: any, order: number)
	local color = if kind == "pass" then UI.Colors.Purple elseif item.category == "Sparkles" then UI.Colors.Yellow else UI.Colors.Blue
	local card = UI.Card({ LayoutOrder = order, Parent = grid }, UI.Darker(color, 0.3))
	UI.New("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), color:Lerp(Color3.new(1, 1, 1), 0.6)), Parent = card })
	UI.Label({ Text = item.icon, Size = UDim2.fromOffset(70, 60), Position = UDim2.new(0.5, 0, 0, 8), AnchorPoint = Vector2.new(0.5, 0), Parent = card })
	UI.Label({ Text = item.name, Size = UDim2.new(1, -16, 0, 28), Position = UDim2.fromOffset(8, 70), Parent = card })
	UI.Label({
		Text = item.description,
		Size = UDim2.new(1, -20, 0, 62),
		Position = UDim2.fromOffset(10, 100),
		TextColor3 = UI.Colors.Text,
		TextScaled = true,
		TextWrapped = true,
		Font = Enum.Font.GothamMedium,
		Parent = card,
	})
	local detail: TextLabel? = nil
	if item.category == "Sparkles" then
		detail = UI.Label({ Text = "", Size = UDim2.new(1, -16, 0, 22), Position = UDim2.fromOffset(8, 164), TextColor3 = Color3.fromRGB(200, 140, 0), Parent = card })
	end
	local button = UI.Button({
		Text = "R$ " .. item.price,
		Color = UI.Colors.Green,
		Size = UDim2.new(1, -24, 0, 42),
		Position = UDim2.new(0.5, 0, 1, -10),
		AnchorPoint = Vector2.new(0.5, 1),
		Parent = card,
		OnClick = function()
			if kind == "pass" and State.data.passes and State.data.passes[item.key] then
				return
			end
			buy(kind, item)
		end,
	})
	cards[item.key] = { button = button, detail = detail }
end

local function rebuild()
	for _, c in grid:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	cards = {}
	if currentTab == "Passes" then
		for i, pass in Products.Passes do
			makeCard("pass", pass, i)
		end
	else
		for i, product in Products.Products do
			if product.category == currentTab then
				makeCard("product", product, i)
			end
		end
	end
	ShopPanel.Refresh()
end

function ShopPanel.Refresh()
	local passes = State.data.passes or {}
	for key, c in cards do
		local pass = Products.Pass(key)
		if pass then
			if passes[key] then
				UI.SetButton(c.button, "OWNED ✓", UI.Colors.Grey)
			else
				UI.SetButton(c.button, "R$ " .. pass.price, UI.Colors.Green)
			end
		end
		local product = Products.Product(key)
		if product and c.detail then
			c.detail.Text = "You get: ✨" .. Formulas.Format(sparklePackAmount(product))
		end
	end
end

function ShopPanel.Init()
	local content = UI.Panel("Shop", "🛒 Cloud Shop", UI.Colors.Yellow, Vector2.new(820, 540), function()
		rebuild()
	end)
	local select = UI.Tabs(content, {
		{ key = "Passes", text = "⭐ Passes", color = UI.Colors.Purple },
		{ key = "Sparkles", text = "✨ Sparkles", color = UI.Colors.Yellow },
		{ key = "Boosts", text = "⚡ Boosts", color = UI.Colors.Blue },
	}, function(key)
		currentTab = key
		if grid then
			rebuild()
		end
	end)
	grid = UI.Scroller({ Size = UDim2.new(1, 0, 1, -90), Position = UDim2.fromOffset(0, 52), Parent = content }, Vector2.new(236, 250), 12)
	UI.Label({
		Text = "💖 Everything is optional — every Cloudling, area and weather can be earned for free by playing. Purchases support development!",
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.new(0, 0, 1, -30),
		TextColor3 = UI.Colors.Text,
		Font = Enum.Font.GothamMedium,
		TextWrapped = true,
		Parent = content,
	})
	select("Passes")
	State.Changed:Connect(function(full)
		if full and UI.IsOpen("Shop") then
			ShopPanel.Refresh()
		end
	end)
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(_, _, purchased)
		if purchased then
			State.Send("Sync")
		end
	end)
end

return ShopPanel
