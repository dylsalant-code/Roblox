--!nonstrict
-- Main.client.luau
-- Client bootstrap: builds the UI and starts every controller.

local Players = game:GetService("Players")

local Controllers = script.Parent:WaitForChild("Controllers")
local UI = require(Controllers.UI)
local State = require(Controllers.State)
local Sound = require(Controllers.Sound)
local Notify = require(Controllers.Notify)
local HUD = require(Controllers.HUD)
local ShopPanel = require(Controllers.ShopPanel)
local IndexPanel = require(Controllers.IndexPanel)
local QuestsPanel = require(Controllers.QuestsPanel)
local MiscPanels = require(Controllers.MiscPanels)
local Pedestals = require(Controllers.Pedestals)
local Stream = require(Controllers.Stream)
local Effects = require(Controllers.Effects)
local Tutorial = require(Controllers.Tutorial)

local screen = UI.Init()
UI.SetClickSound(function()
	Sound.Play("Click", 0.35)
end)

Sound.Init()
Notify.Init(screen)
HUD.Init(screen, UI.OpenPanel)
ShopPanel.Init()
IndexPanel.Init()
QuestsPanel.Init()
MiscPanels.Init()
Pedestals.Init()
Stream.Init()
Effects.Init()
Tutorial.Init(screen)
State.Init() -- last: requests the first full snapshot

-- Friendly daily-reward popup once onboarding is finished.
local shownLogin = false
local function maybeShowLogin()
	local d = State.data
	if shownLogin or not d.login or d.tutorial ~= 99 then
		return
	end
	if d.login.claimedDay ~= d.today then
		shownLogin = true
		task.delay(2, function()
			QuestsPanel.OpenOn("Login")
		end)
	end
end
State.Changed:Connect(function(full)
	if full then
		maybeShowLogin()
	end
end)

print("☁ Catch a Cloudling client ready for", Players.LocalPlayer.Name)
