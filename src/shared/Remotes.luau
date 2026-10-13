--!nonstrict
-- Remotes.luau
-- Single source of truth for networking. The server creates every remote on
-- boot; clients wait for them. Names never appear as string literals elsewhere.
--
--   StateSync  (S->C)  player state snapshot (only the fields that changed)
--   Notify     (S->C)  toast { text, kind }
--   Announce   (S->All) big banner (rare catches, weather, milestones)
--   Effect     (S->C)  cosmetic one-shots (catch flight, collect pop, level up)
--   Action     (C->S)  every player intent: { action = string, ... }
--   Tutorial   (S->C)  tutorial step updates

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = { "StateSync", "Notify", "Announce", "Effect", "Action", "Tutorial" }
local FOLDER_NAME = "Remotes"

local Remotes = {}

local function folder(): Folder
	if RunService:IsServer() then
		local f = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if not f then
			f = Instance.new("Folder")
			f.Name = FOLDER_NAME
			f.Parent = ReplicatedStorage
		end
		return f :: Folder
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

function Remotes.Get(name: string): RemoteEvent
	assert(table.find(NAMES, name), "Unknown remote " .. name)
	local f = folder()
	if RunService:IsServer() then
		local r = f:FindFirstChild(name)
		if not r then
			r = Instance.new("RemoteEvent")
			r.Name = name
			r.Parent = f
		end
		return r :: RemoteEvent
	end
	return f:WaitForChild(name) :: RemoteEvent
end

function Remotes.CreateAll()
	for _, n in NAMES do
		Remotes.Get(n)
	end
end

return Remotes
