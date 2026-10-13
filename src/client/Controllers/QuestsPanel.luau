--!nonstrict
-- QuestsPanel.luau
-- Daily quests, achievements and the 7-day login streak in one tabbed panel.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Formulas = require(Shared.Formulas)
local QuestData = require(Shared.QuestData)
local UI = require(script.Parent.UI)
local State = require(script.Parent.State)

local QuestsPanel = {}

local body: Frame
local tab = "Daily"

local function questDef(id: string): QuestData.QuestDef?
	for _, d in QuestData.Pool do
		if d.id == id then
			return d
		end
	end
	return nil
end

local function clear()
	for _, c in body:GetChildren() do
		c:Destroy()
	end
end

local function renderDaily()
	local daily = State.data.daily
	if not daily then
		return
	end
	local list = UI.Scroller({ Size = UDim2.new(1, 0, 1, -40), Parent = body }, nil, 10)
	for i, q in daily.quests do
		local def = questDef(q.id)
		if def then
			local done = q.progress >= q.target
			local card = UI.Card({ Size = UDim2.new(1, -8, 0, 96), LayoutOrder = i, Parent = list }, if done then UI.Colors.Green else UI.Colors.Stroke)
			UI.Label({
				Text = string.format(def.text, Formulas.Format(q.target)),
				Size = UDim2.new(1, -220, 0, 34),
				Position = UDim2.fromOffset(14, 8),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = UI.Colors.Text,
				Parent = card,
			})
			local _, setBar = UI.ProgressBar({ Size = UDim2.new(1, -220, 0, 30), Position = UDim2.fromOffset(14, 52), Parent = card }, UI.Colors.Green)
			setBar(q.progress / q.target, Formulas.Format(math.floor(q.progress)) .. " / " .. Formulas.Format(q.target))
			local text, color
			if q.claimed then
				text, color = "Claimed ✓", UI.Colors.Grey
			elseif done then
				text, color = "Claim ✨" .. Formulas.Format(q.reward), UI.Colors.Green
			else
				text, color = "✨" .. Formulas.Format(q.reward), UI.Colors.Blue
			end
			UI.Button({
				Text = text,
				Color = color,
				Size = UDim2.fromOffset(190, 56),
				Position = UDim2.new(1, -12, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				Parent = card,
				OnClick = function()
					if done and not q.claimed then
						State.Send("ClaimQuest", { index = i })
					end
				end,
			})
		end
	end
	local secondsLeft = (Formulas.DayNumber(State.Now()) + 1) * 86400 - State.Now()
	UI.Label({
		Text = "🌟 Finish all 3 for a big bonus!  New quests in " .. Formulas.FormatTime(secondsLeft),
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.new(0, 0, 1, -32),
		TextColor3 = UI.Colors.Text,
		Parent = body,
	})
end

local function renderAchievements()
	local list = UI.Scroller({ Size = UDim2.fromScale(1, 1), Parent = body }, Vector2.new(250, 110), 10)
	local unlocked = State.data.achievements or {}
	for i, a in QuestData.Achievements do
		local has = unlocked[a.id] == true
		local card = UI.Card({ LayoutOrder = (if has then 1000 else 0) + i, Parent = list }, if has then UI.Colors.Yellow else UI.Colors.Grey)
		card.BackgroundColor3 = if has then Color3.fromRGB(255, 248, 220) else Color3.fromRGB(240, 238, 245)
		UI.Label({ Text = (if has then "🏆 " else "🔒 ") .. a.name, Size = UDim2.new(1, -14, 0, 28), Position = UDim2.fromOffset(7, 6), TextColor3 = UI.Colors.Text, Parent = card })
		UI.Label({ Text = a.description, Size = UDim2.new(1, -14, 0, 36), Position = UDim2.fromOffset(7, 36), TextColor3 = UI.Colors.Text, Font = Enum.Font.GothamMedium, TextWrapped = true, Parent = card })
		UI.Label({ Text = "Reward ✨" .. Formulas.Format(a.reward), Size = UDim2.new(1, -14, 0, 22), Position = UDim2.fromOffset(7, 78), TextColor3 = Color3.fromRGB(200, 140, 0), Parent = card })
	end
end

local function renderLogin()
	local login = State.data.login
	if not login then
		return
	end
	local row = UI.New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 150), Position = UDim2.fromOffset(0, 20), Parent = body }, {
		UI.New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 8) }),
	})
	local claimedToday = login.claimedDay == State.data.today
	local current = ((login.streak - 1) % #QuestData.LoginRewards) + 1
	for day, r in QuestData.LoginRewards do
		local isCurrent = day == current
		local past = day < current or (isCurrent and claimedToday)
		local color = if isCurrent and not claimedToday then UI.Colors.Green elseif past then UI.Colors.Grey else UI.Colors.Blue
		local card = UI.Card({ Size = UDim2.fromOffset(100, 140), LayoutOrder = day, Parent = row }, color)
		UI.Label({ Text = "Day " .. day, Size = UDim2.new(1, -8, 0, 26), Position = UDim2.fromOffset(4, 6), TextColor3 = UI.Colors.Text, Parent = card })
		UI.Label({ Text = if past then "✅" elseif day == 7 then "🎁" else "✨", Size = UDim2.new(1, 0, 0, 50), Position = UDim2.fromOffset(0, 36), Parent = card })
		UI.Label({
			Text = if r.boostMinutes then "Big + 2x Boost" else (string.format("%d min income", r.seconds // 60)),
			Size = UDim2.new(1, -8, 0, 40),
			Position = UDim2.fromOffset(4, 92),
			TextColor3 = UI.Colors.Text,
			Font = Enum.Font.GothamMedium,
			TextWrapped = true,
			Parent = card,
		})
	end
	UI.Label({
		Text = "🔥 Login streak: " .. login.streak .. " day" .. (if login.streak == 1 then "" else "s") .. "  —  come back every day for bigger rewards!",
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.fromOffset(0, 190),
		TextColor3 = UI.Colors.Text,
		Parent = body,
	})
	UI.Button({
		Text = if claimedToday then "See you tomorrow! ☁" else "Claim Day " .. current .. " Reward!",
		Color = if claimedToday then UI.Colors.Grey else UI.Colors.Green,
		Size = UDim2.fromOffset(320, 64),
		Position = UDim2.new(0.5, 0, 0, 240),
		AnchorPoint = Vector2.new(0.5, 0),
		Parent = body,
		OnClick = function()
			if not claimedToday then
				State.Send("ClaimLogin")
			end
		end,
	})
end

function QuestsPanel.Render()
	if not body then
		return
	end
	clear()
	if tab == "Daily" then
		renderDaily()
	elseif tab == "Achievements" then
		renderAchievements()
	else
		renderLogin()
	end
end

function QuestsPanel.ShowTab(key: string)
	tab = key
	QuestsPanel.Render()
end

local selectTab: ((string) -> ())? = nil

function QuestsPanel.OpenOn(key: string)
	if selectTab then
		selectTab(key)
	end
	if not UI.IsOpen("Quests") then
		UI.OpenPanel("Quests")
	end
end

function QuestsPanel.Init()
	local content = UI.Panel("Quests", "📜 Quests & Rewards", UI.Colors.Green, Vector2.new(820, 520), function()
		QuestsPanel.Render()
	end)
	local select = UI.Tabs(content, {
		{ key = "Daily", text = "📅 Daily", color = UI.Colors.Green },
		{ key = "Login", text = "🔥 Streak", color = UI.Colors.Orange },
		{ key = "Achievements", text = "🏆 Trophies", color = UI.Colors.Yellow },
	}, QuestsPanel.ShowTab)
	selectTab = select
	body = UI.New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -54), Position = UDim2.fromOffset(0, 54), Parent = content })
	select("Daily")
	State.Changed:Connect(function(full)
		if full and UI.IsOpen("Quests") then
			QuestsPanel.Render()
		end
	end)
end

return QuestsPanel
