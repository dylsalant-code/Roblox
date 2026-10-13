--!nonstrict
-- UI.luau
-- Tiny UI kit: instance builder, themed buttons, panels with pop animations,
-- and a global UIScale so the same layout fits phones, tablets, PCs and TVs.
-- Layout is authored for a 1100x650 "virtual" screen and scaled to fit.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local UI = {}

UI.Font = Enum.Font.FredokaOne
UI.Colors = {
	Text = Color3.fromRGB(70, 45, 110),
	Light = Color3.fromRGB(252, 250, 255),
	Panel = Color3.fromRGB(248, 244, 255),
	Stroke = Color3.fromRGB(70, 45, 110),
	Green = Color3.fromRGB(90, 210, 120),
	Yellow = Color3.fromRGB(255, 205, 70),
	Pink = Color3.fromRGB(255, 120, 170),
	Blue = Color3.fromRGB(90, 170, 255),
	Purple = Color3.fromRGB(150, 110, 255),
	Grey = Color3.fromRGB(170, 165, 185),
	Red = Color3.fromRGB(255, 95, 95),
	Orange = Color3.fromRGB(255, 150, 70),
}

local player = Players.LocalPlayer
local screen: ScreenGui
local scale: UIScale
local panels: { [string]: { frame: Frame, onOpen: (() -> ())? } } = {}
local openPanel: string? = nil
local clickSound: (() -> ())? = nil

function UI.SetClickSound(fn: () -> ())
	clickSound = fn
end

function UI.New(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	local parent = nil
	if props then
		for k, v in props do
			if k == "Parent" then
				parent = v
			else
				(inst :: any)[k] = v
			end
		end
	end
	if children then
		for _, c in children do
			c.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function UI.Corner(radius: number?): UICorner
	return UI.New("UICorner", { CornerRadius = UDim.new(0, radius or 14) })
end

function UI.Stroke(thickness: number?, color: Color3?): UIStroke
	return UI.New("UIStroke", {
		Thickness = thickness or 3,
		Color = color or UI.Colors.Stroke,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function UI.TextStroke(thickness: number?): UIStroke
	return UI.New("UIStroke", { Thickness = thickness or 2, Color = UI.Colors.Stroke })
end

function UI.Darker(c: Color3, f: number?): Color3
	return c:Lerp(Color3.new(0, 0, 0), f or 0.35)
end

function UI.Label(props: { [string]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		Font = UI.Font,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
	}
	for k, v in props do
		if k ~= "Stroke" and k ~= "StrokeThickness" then
			defaults[k] = v
		end
	end
	local label = UI.New("TextLabel", defaults)
	if props.TextColor3 == nil or props.Stroke then
		UI.TextStroke(props.StrokeThickness).Parent = label
	end
	return label
end

-- Bouncy feedback on press.
local function attachPress(button: GuiButton)
	local s = UI.New("UIScale", { Parent = button })
	button.MouseEnter:Connect(function()
		TweenService:Create(s, TweenInfo.new(0.12), { Scale = 1.05 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(s, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)
	button.MouseButton1Down:Connect(function()
		TweenService:Create(s, TweenInfo.new(0.06), { Scale = 0.92 }):Play()
	end)
	button.MouseButton1Up:Connect(function()
		TweenService:Create(s, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end)
end

export type ButtonProps = {
	Text: string,
	Color: Color3?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Parent: Instance?,
	LayoutOrder: number?,
	OnClick: (() -> ())?,
	Name: string?,
}

function UI.Button(p: ButtonProps): TextButton
	local color = p.Color or UI.Colors.Green
	local b = UI.New("TextButton", {
		Name = p.Name or "Button",
		Size = p.Size or UDim2.fromOffset(160, 50),
		Position = p.Position or UDim2.new(),
		AnchorPoint = p.AnchorPoint or Vector2.zero,
		BackgroundColor3 = color,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = p.LayoutOrder or 0,
	}, {
		UI.Corner(12),
		UI.Stroke(3, UI.Darker(color, 0.45)),
		UI.New("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(215, 215, 215)),
		}),
	})
	local label = UI.Label({
		Name = "Label",
		Text = p.Text,
		Size = UDim2.new(1, -12, 1, -10),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = b,
	})
	label.ZIndex = b.ZIndex + 1
	attachPress(b)
	if p.OnClick then
		local cb = p.OnClick
		b.Activated:Connect(function()
			if clickSound then
				clickSound()
			end
			cb()
		end)
	end
	if p.Parent then
		b.Parent = p.Parent
	end
	return b
end

function UI.SetButton(b: TextButton, text: string, color: Color3?)
	local label = b:FindFirstChild("Label") :: TextLabel?
	if label then
		label.Text = text
	end
	if color then
		b.BackgroundColor3 = color
		local stroke = b:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = UI.Darker(color, 0.45)
		end
	end
end

-- Progress bar: returns (container, setFn(fraction, text?)).
function UI.ProgressBar(props: { [string]: any }, color: Color3): (Frame, (number, string?) -> ())
	local bar = UI.New("Frame", props, { UI.Corner(10), UI.Stroke(2) })
	bar.BackgroundColor3 = Color3.fromRGB(225, 220, 240)
	local fill = UI.New("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = color,
		Parent = bar,
	}, { UI.Corner(10) })
	local text = UI.Label({ Size = UDim2.fromScale(1, 0.85), Position = UDim2.fromScale(0, 0.075), Text = "", Parent = bar })
	text.ZIndex = 3
	return bar, function(f: number, t: string?)
		f = math.clamp(f, 0, 1)
		TweenService:Create(fill, TweenInfo.new(0.25), { Size = UDim2.fromScale(f, 1) }):Play()
		text.Text = t or ""
	end
end

-- Screen + scaling ---------------------------------------------------------------
function UI.Init(): ScreenGui
	screen = UI.New("ScreenGui", {
		Name = "CloudlingUI",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	scale = UI.New("UIScale", { Parent = screen })
	local camera = workspace.CurrentCamera
	local function rescale()
		local vp = camera.ViewportSize
		scale.Scale = math.clamp(math.min(vp.X / 1100, vp.Y / 650), 0.5, 1.4)
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	rescale()
	return screen
end

function UI.Screen(): ScreenGui
	return screen
end

-- Size of the virtual canvas (after scaling) — use for full-screen elements.
function UI.VirtualSize(): Vector2
	local vp = workspace.CurrentCamera.ViewportSize
	return vp / scale.Scale
end

-- Panels -----------------------------------------------------------------------------
-- Creates a centered modal panel. Returns the content frame.
function UI.Panel(name: string, title: string, color: Color3, size: Vector2?, onOpen: (() -> ())?): Frame
	local sz = size or Vector2.new(760, 500)
	local frame = UI.New("Frame", {
		Name = name .. "Panel",
		Size = UDim2.fromOffset(sz.X, sz.Y),
		Position = UDim2.fromScale(0.5, 0.52),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = UI.Colors.Panel,
		Visible = false,
		ZIndex = 20,
		Parent = screen,
	}, {
		UI.Corner(22),
		UI.Stroke(4),
		UI.New("UIScale", { Name = "PopScale" }),
	})
	local header = UI.New("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 64),
		BackgroundColor3 = color,
		ZIndex = 21,
		Parent = frame,
	}, {
		UI.Corner(22),
		UI.New("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200)) }),
	})
	-- Square off the header's bottom corners.
	UI.New("Frame", {
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.new(0, 0, 1, -22),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = 21,
		Parent = header,
	})
	local t = UI.Label({ Text = title, Size = UDim2.new(1, -140, 0, 46), Position = UDim2.fromOffset(20, 9), TextXAlignment = Enum.TextXAlignment.Left, Parent = header })
	t.ZIndex = 22
	local close = UI.Button({
		Text = "✕",
		Color = UI.Colors.Red,
		Size = UDim2.fromOffset(50, 50),
		Position = UDim2.new(1, -8, 0, -8),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = frame,
		OnClick = function()
			UI.ClosePanel()
		end,
	})
	close.ZIndex = 30
	local content = UI.New("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -32, 1, -84),
		Position = UDim2.fromOffset(16, 74),
		ZIndex = 21,
		Parent = frame,
	})
	panels[name] = { frame = frame, onOpen = onOpen }
	return content
end

function UI.OpenPanel(name: string)
	if openPanel == name then
		UI.ClosePanel()
		return
	end
	UI.ClosePanel()
	local p = panels[name]
	if not p then
		return
	end
	openPanel = name
	if p.onOpen then
		p.onOpen()
	end
	local pop = p.frame:FindFirstChild("PopScale") :: UIScale
	pop.Scale = 0.7
	p.frame.Visible = true
	TweenService:Create(pop, TweenInfo.new(0.28, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

function UI.ClosePanel()
	if openPanel then
		local p = panels[openPanel]
		openPanel = nil
		if p then
			p.frame.Visible = false
		end
	end
end

function UI.IsOpen(name: string): boolean
	return openPanel == name
end

-- Simple tab bar. `tabs` = { {key, text, color} }. Returns a select function.
function UI.Tabs(parent: Instance, tabs: { { key: string, text: string, color: Color3 } }, onSelect: (string) -> ()): (string) -> ()
	local bar = UI.New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44), Parent = parent }, {
		UI.New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local buttons: { [string]: TextButton } = {}
	local function select(key: string)
		for k, b in buttons do
			b.BackgroundTransparency = if k == key then 0 else 0.45
		end
		onSelect(key)
	end
	for i, tab in tabs do
		buttons[tab.key] = UI.Button({
			Text = tab.text,
			Color = tab.color,
			Size = UDim2.fromOffset(170, 42),
			LayoutOrder = i,
			Parent = bar,
			OnClick = function()
				select(tab.key)
			end,
		})
		buttons[tab.key].ZIndex = 22
	end
	return select
end

function UI.Scroller(props: { [string]: any }, cell: Vector2?, padding: number?): ScrollingFrame
	local defaults = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = UI.Colors.Purple,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 22,
	}
	for k, v in props do
		defaults[k] = v
	end
	local s = UI.New("ScrollingFrame", defaults)
	if cell then
		UI.New("UIGridLayout", {
			CellSize = UDim2.fromOffset(cell.X, cell.Y),
			CellPadding = UDim2.fromOffset(padding or 10, padding or 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Parent = s,
		})
	else
		UI.New("UIListLayout", { Padding = UDim.new(0, padding or 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = s })
	end
	UI.New("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 12), Parent = s })
	return s
end

-- Card container with rounded border.
function UI.Card(props: { [string]: any }, color: Color3?): Frame
	local defaults = { BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 22 }
	for k, v in props do
		defaults[k] = v
	end
	return UI.New("Frame", defaults, { UI.Corner(16), UI.Stroke(3, color or UI.Colors.Stroke) })
end

return UI
