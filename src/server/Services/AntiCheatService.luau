--!nonstrict
-- AntiCheatService.luau
-- Lightweight server-side movement sanity checks. Economy exploits are
-- impossible by design (every purchase/collect/upgrade is validated on the
-- server), so this only guards against speed/teleport hacks that would let
-- someone snipe every rare Cloudling. It rubber-bands instead of kicking to
-- avoid punishing laggy mobile players.

local Players = game:GetService("Players")

local AntiCheatService = {}

local S: any
local lastPos: { [Player]: Vector3 } = {}
local strikes: { [Player]: number } = {}
local graceUntil: { [Player]: number } = {}

local CHECK_INTERVAL = 0.5
local TOLERANCE = 1.6 -- multiplier over allowed walk speed
local FLAT_ALLOWANCE = 12 -- studs per check for knockback / lag spikes

function AntiCheatService:Init(services)
	S = services
end

-- Call before legitimate teleports.
function AntiCheatService:Grace(player: Player, seconds: number)
	graceUntil[player] = os.clock() + seconds
	lastPos[player] = nil
end

function AntiCheatService:Start()
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			self:Grace(player, 3)
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastPos[player] = nil
		strikes[player] = nil
		graceUntil[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(CHECK_INTERVAL)
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if root and humanoid and humanoid.Health > 0 then
					local pos = root.Position
					local prev = lastPos[player]
					if prev and os.clock() > (graceUntil[player] or 0) then
						local flat = Vector3.new(pos.X - prev.X, 0, pos.Z - prev.Z).Magnitude
						local allowed = humanoid.WalkSpeed * CHECK_INTERVAL * TOLERANCE + FLAT_ALLOWANCE
						if flat > allowed then
							strikes[player] = (strikes[player] or 0) + 1
							if strikes[player] >= 3 then
								warn(string.format("[AntiCheat] %s moved %.0f studs in %.1fs; rubber-banding", player.Name, flat, CHECK_INTERVAL))
								root.CFrame = CFrame.new(prev + Vector3.new(0, 2, 0))
								strikes[player] = 0
								continue
							end
						else
							strikes[player] = math.max(0, (strikes[player] or 0) - 1)
						end
					end
					lastPos[player] = pos
				end
			end
		end
	end)
	local _ = S
end

return AntiCheatService
