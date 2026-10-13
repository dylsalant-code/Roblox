--!nonstrict
-- Sound.luau
-- Plays UI/gameplay sounds and background music, honoring player settings.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Sounds = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Sounds"))
local State = require(script.Parent.State)

local Sound = {}

local cache: { [string]: Sound } = {}
local music: Sound? = nil

local function get(name: string): Sound?
	local id = (Sounds :: any)[name]
	if not id or id == "" then
		return nil
	end
	if not cache[name] then
		local s = Instance.new("Sound")
		s.Name = name
		s.SoundId = id
		s.Volume = 0.5
		s.Parent = SoundService
		cache[name] = s
	end
	return cache[name]
end

function Sound.Play(name: string, volume: number?, pitch: number?)
	local settings = State.data.settings
	if settings and settings.sfx == false then
		return
	end
	local s = get(name)
	if s then
		s.Volume = volume or 0.5
		s.PlaybackSpeed = pitch or 1
		SoundService:PlayLocalSound(s)
	end
end

function Sound.UpdateMusic()
	local settings = State.data.settings
	local enabled = not settings or settings.music ~= false
	local weather = workspace:GetAttribute("Weather")
	local wanted = if weather and weather ~= "" and Sounds.WeatherMusic ~= "" then Sounds.WeatherMusic else Sounds.Music
	if not music and wanted ~= "" then
		local m = Instance.new("Sound")
		music = m
		m.Name = "Music"
		m.Looped = true
		m.Volume = 0.25
		m.Parent = SoundService
	end
	if music then
		if music.SoundId ~= wanted then
			music.SoundId = wanted
		end
		if enabled and wanted ~= "" then
			if not music.IsPlaying then
				music:Play()
			end
		else
			music:Stop()
		end
	end
end

function Sound.Init()
	State.Changed:Connect(function(full)
		if full then
			Sound.UpdateMusic()
		end
	end)
	workspace:GetAttributeChangedSignal("Weather"):Connect(Sound.UpdateMusic)
end

return Sound
