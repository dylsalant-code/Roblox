--!nonstrict
-- State.luau
-- Client mirror of the player's server state. Read-only: every change goes
-- through State.Send(action, payload) and comes back as a StateSync.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Signal)

local State = {}

State.data = {} :: any
State.loaded = false
State.Changed = Signal.new() -- fires (full: boolean)
State.Loaded = Signal.new()
State.serverOffset = 0 -- server os.time() - client os.time()

local actionRemote: RemoteEvent

function State.Send(action: string, payload: { [string]: any }?)
	local p = payload or {}
	p.action = action
	actionRemote:FireServer(p)
end

-- Server clock estimate (for timers like boosts and weather).
function State.Now(): number
	return os.time() + State.serverOffset
end

function State.Init()
	actionRemote = Remotes.Get("Action")
	Remotes.Get("StateSync").OnClientEvent:Connect(function(snap)
		for k, v in snap do
			State.data[k] = v
		end
		if snap.serverTime then
			State.serverOffset = snap.serverTime - os.time()
		end
		local first = not State.loaded and snap.full
		if first then
			State.loaded = true
		end
		State.Changed:Fire(snap.full == true)
		if first then
			State.Loaded:Fire()
		end
	end)
	State.Send("Sync")
end

return State
