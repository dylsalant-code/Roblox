--!nonstrict
-- Notify.luau
-- Toast notifications (personal) and announcement banners (server-wide).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local UI = require(script.Parent.UI)
local Sound = require(script.Parent.Sound)

local Notify = {}

local toastHolder: Frame
local bannerQueue: { any } = {}
local bannerBusy = false
local banner: Frame
local bannerLabel: TextLabel

local KIND_COLORS = {
	info = UI.Colors.Blue,
	success = UI.Colors.Green,
	error = UI.Colors.Red,
	achievement = UI.Colors.Yellow,
}

function Notify.Toast(text: string, kind: string?)
	local color = KIND_COLORS[kind or "info"] or UI.Colors.Blue
	local toast = UI.New("Frame", {
		Size = UDim2.fromOffset(460, 44),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.05,
		Parent = toastHolder,
	}, { UI.Corner(14), UI.Stroke(3, UI.Darker(color, 0.5)), UI.New("UIScale", { Scale = 0.5 }) })
	UI.Label({ Text = text, Size = UDim2.new(1, -20, 1, -10), Position = UDim2.fromOffset(10, 5), Parent = toast })
	local s = toast:FindFirstChildOfClass("UIScale") :: UIScale
	TweenService:Create(s, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	if kind == "error" then
		Sound.Play("Error", 0.4, 0.7)
	elseif kind == "achievement" then
		Sound.Play("Announce", 0.6, 1.3)
	end
	task.delay(3.5, function()
		TweenService:Create(s, TweenInfo.new(0.2), { Scale = 0 }):Play()
		task.wait(0.22)
		toast:Destroy()
	end)
	-- Keep at most 4 toasts on screen.
	local children = {}
	for _, c in toastHolder:GetChildren() do
		if c:IsA("Frame") then
			table.insert(children, c)
		end
	end
	if #children > 4 then
		children[1]:Destroy()
	end
end

local function nextBanner()
	if bannerBusy or #bannerQueue == 0 then
		return
	end
	bannerBusy = true
	local msg = table.remove(bannerQueue, 1)
	bannerLabel.Text = msg.text
	banner.BackgroundColor3 = msg.color or UI.Colors.Purple
	local stroke = banner:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = UI.Darker(banner.BackgroundColor3, 0.5)
	end
	banner.Visible = true
	banner.Position = UDim2.new(0.5, 0, 0, -80)
	Sound.Play("Announce", 0.5, if msg.kind == "spawn" then 0.8 else 1.1)
	TweenService:Create(banner, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 0, 92) }):Play()
	task.delay(3.6, function()
		TweenService:Create(banner, TweenInfo.new(0.3), { Position = UDim2.new(0.5, 0, 0, -80) }):Play()
		task.wait(0.35)
		banner.Visible = false
		bannerBusy = false
		nextBanner()
	end)
end

function Notify.Announce(msg: { text: string, color: Color3?, kind: string? })
	if #bannerQueue < 5 then
		table.insert(bannerQueue, msg)
	end
	nextBanner()
end

function Notify.Init(screen: ScreenGui)
	toastHolder = UI.New("Frame", {
		Name = "Toasts",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(460, 220),
		Position = UDim2.new(0.5, 0, 1, -120),
		AnchorPoint = Vector2.new(0.5, 1),
		Parent = screen,
	}, {
		UI.New("UIListLayout", {
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 6),
		}),
	})
	banner = UI.New("Frame", {
		Name = "Banner",
		Size = UDim2.fromOffset(640, 58),
		AnchorPoint = Vector2.new(0.5, 0),
		Visible = false,
		BackgroundColor3 = UI.Colors.Purple,
		ZIndex = 40,
		Parent = screen,
	}, { UI.Corner(18), UI.Stroke(4) })
	bannerLabel = UI.Label({ Text = "", Size = UDim2.new(1, -24, 1, -12), Position = UDim2.fromOffset(12, 6), Parent = banner })

	Remotes.Get("Notify").OnClientEvent:Connect(function(msg)
		Notify.Toast(msg.text, msg.kind)
	end)
	Remotes.Get("Announce").OnClientEvent:Connect(Notify.Announce)
end

return Notify
