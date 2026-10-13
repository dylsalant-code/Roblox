--!nonstrict
-- WeatherService.luau
-- Server-wide weather events (free, on a timer) and seasonal events (by
-- date). State is replicated through workspace attributes so every client
-- can render skies/particles without extra remotes:
--   Weather (string key or ""), WeatherEnds (unix time),
--   SeasonalEvent (id or ""), SeasonalEventName (string)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local CloudlingData = require(Shared.CloudlingData)
local Remotes = require(Shared.Remotes)

local WeatherService = {}

local current: string? = nil
local endsAt = 0
local nextAt = 0
local seasonal: string? = nil
local announceRemote: RemoteEvent
local rng = Random.new()

function WeatherService:Init(_services)
	announceRemote = Remotes.Get("Announce")
	workspace:SetAttribute("Weather", "")
	workspace:SetAttribute("WeatherEnds", 0)
end

function WeatherService:GetWeather(): string?
	return current
end

function WeatherService:GetWeatherDef(): any
	return current and CloudlingData.Weather[current]
end

function WeatherService:GetSeasonalEvent(): string?
	return seasonal
end

-- Starts (or extends) a weather event. `byPlayer` is credited publicly when
-- it was summoned with a developer product.
function WeatherService:StartWeather(key: string, duration: number?, byPlayer: Player?)
	local def = CloudlingData.Weather[key]
	if not def then
		return
	end
	local now = os.time()
	if current == key and endsAt > now then
		endsAt += duration or Config.WeatherDuration
	else
		current = key
		endsAt = now + (duration or Config.WeatherDuration)
	end
	workspace:SetAttribute("Weather", key)
	workspace:SetAttribute("WeatherEnds", endsAt)
	local text = if byPlayer
		then string.format("%s %s summoned a %s for everyone! %s", def.icon, byPlayer.DisplayName, def.name, def.icon)
		else string.format("%s A %s has begun! %s", def.icon, def.name, def.icon)
	announceRemote:FireAllClients({ text = text, color = def.color, kind = "weather" })
end

local function computeSeasonal(): (string?, string?)
	local t = os.date("!*t") :: any
	local today = t.month * 100 + t.day
	for _, e in Config.SeasonalEvents do
		local s = e.startMonth * 100 + e.startDay
		local f = e.endMonth * 100 + e.endDay
		local live = if s <= f then today >= s and today <= f else today >= s or today <= f
		if live then
			return e.id, e.name
		end
	end
	return nil, nil
end

function WeatherService:Start()
	nextAt = os.time() + rng:NextInteger(60, 120) -- first event comes quickly
	task.spawn(function()
		while true do
			local id, name = computeSeasonal()
			if id ~= seasonal then
				seasonal = id
				workspace:SetAttribute("SeasonalEvent", id or "")
				workspace:SetAttribute("SeasonalEventName", name or "")
			end

			local now = os.time()
			if current and now >= endsAt then
				local def = CloudlingData.Weather[current]
				current = nil
				workspace:SetAttribute("Weather", "")
				announceRemote:FireAllClients({ text = def.name .. " has ended. Next one soon! ☁", color = Color3.fromRGB(200, 210, 255), kind = "info" })
				nextAt = now + rng:NextInteger(Config.WeatherMinGap, Config.WeatherMaxGap)
			elseif not current and now >= nextAt then
				local keys = CloudlingData.WeatherOrder
				self:StartWeather(keys[rng:NextInteger(1, #keys)])
			end
			task.wait(1)
		end
	end)
end

return WeatherService
