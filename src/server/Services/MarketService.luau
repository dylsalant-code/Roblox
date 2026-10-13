--!nonstrict
-- MarketService.luau
-- Game pass verification + developer product receipts.
--
-- Receipt handling follows Roblox's guidance:
--  * idempotent: each PurchaseId is recorded in the player's save, so a
--    retried receipt is acknowledged without granting twice;
--  * we only return PurchaseGranted after the grant is persisted;
--  * if the player isn't loaded we return NotProcessedYet and Roblox retries.
--
-- Studio testing: while an ID in Products.luau is still 0, the client shop
-- sends a "TestPurchase" action and (in Studio only) we grant for free.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local Products = require(Shared.Products)
local Remotes = require(Shared.Remotes)

local MarketService = {}

local S: any
local owned: { [Player]: { [string]: boolean } } = {}
local effectRemote: RemoteEvent

local MAX_RECEIPTS = 60

function MarketService:Init(services)
	S = services
	effectRemote = Remotes.Get("Effect")
end

function MarketService:HasPass(player: Player, key: string): boolean
	local o = owned[player]
	return o ~= nil and o[key] == true
end

function MarketService:GetPasses(player: Player): { [string]: boolean }
	return owned[player] or {}
end

-- Applies a pass's live effects (speed, VIP crown, trail flags).
function MarketService:ApplyPassEffects(player: Player)
	player:SetAttribute("VIP", self:HasPass(player, "VIP"))
	player:SetAttribute("RainbowTrail", self:HasPass(player, "RainbowTrail"))
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local base = game:GetService("StarterPlayer").CharacterWalkSpeed
		humanoid.WalkSpeed = if self:HasPass(player, "CloudSneakers") then base * 1.3 else base
	end
end

function MarketService:GrantPass(player: Player, key: string)
	owned[player] = owned[player] or {}
	if owned[player][key] then
		return
	end
	owned[player][key] = true
	self:ApplyPassEffects(player)
	if key == "BiggerIsland" then
		S.PlotService:RefreshAllPedestals(player)
	end
	S.PlotService:RefreshLabels(player)
	S.DataService:MarkDirty(player, true)
	local pass = Products.Pass(key)
	if pass then
		S.ProgressService:Notify(player, pass.icon .. " " .. pass.name .. " unlocked! Thank you for supporting the game! 💖", "success")
	end
end

function MarketService:LoadPasses(player: Player)
	owned[player] = {}
	for _, pass in Products.Passes do
		if pass.id ~= 0 then
			local ok, has = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.id)
			if ok and has then
				owned[player][pass.key] = true
			end
		end
	end
	self:ApplyPassEffects(player)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid", 5)
		self:ApplyPassEffects(player)
	end)
end

function MarketService:Unload(player: Player)
	owned[player] = nil
end

-- Developer product effects. Returns true when granted.
function MarketService:GrantProduct(player: Player, key: string): boolean
	local product = Products.Product(key)
	local data = S.DataService:Get(player)
	if not product or not data then
		return false
	end
	if product.category == "Sparkles" then
		local amount = Formulas.ScaledReward(S.PlotService:GetIncome(player, true), product.seconds :: number, product.minimum :: number)
		S.DataService:AddSparkles(player, amount, false)
		effectRemote:FireClient(player, "Reward", { amount = amount })
		S.ProgressService:Notify(player, product.icon .. " +" .. Formulas.Format(amount) .. " Sparkles! Thank you! 💖", "success")
	elseif key == "Boost30" then
		data.boostUntil = math.max(data.boostUntil, os.time()) + 30 * 60
		S.ProgressService:Notify(player, "⚡ 2x Boost active for 30 more minutes!", "success")
	elseif key == "SummonRainbow" then
		S.WeatherService:StartWeather("RainbowStorm", nil, player)
	elseif key == "SummonStarfall" then
		S.WeatherService:StartWeather("Starfall", nil, player)
	else
		return false
	end
	S.DataService:MarkDirty(player, true)
	return true
end

local function recordReceipt(data: any, purchaseId: string)
	data.receipts[purchaseId] = os.time()
	-- Keep the list bounded: drop the oldest entries.
	local count = 0
	local oldestId, oldestTime = nil, math.huge
	for id, t in data.receipts do
		count += 1
		if t < oldestTime then
			oldestId, oldestTime = id, t
		end
	end
	if count > MAX_RECEIPTS and oldestId then
		data.receipts[oldestId] = nil
	end
end

local function processReceipt(receipt: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = S.DataService:Get(player)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(receipt.PurchaseId)
	if data.receipts[purchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local product = Products.ProductById(receipt.ProductId)
	if not product then
		warn("[MarketService] Unknown product id", receipt.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local ok, granted = pcall(MarketService.GrantProduct, MarketService, player, product.key)
	if not ok or not granted then
		warn("[MarketService] Grant failed", product.key, granted)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	recordReceipt(data, purchaseId)
	data.stats.robuxSpent += receipt.CurrencySpent or 0
	if not S.DataService:Save(player) then
		-- The grant is already in memory with the receipt recorded, so a retry
		-- in this session is a no-op; returning NotProcessedYet lets Roblox
		-- retry after a rejoin if this save truly never landed.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- Studio-only free purchases for unconfigured IDs.
function MarketService:TestPurchase(player: Player, kind: string, key: string): (boolean, string?)
	if not (RunService:IsStudio() and Config.AllowStudioTestPurchases) then
		return false
	end
	if kind == "pass" then
		local pass = Products.Pass(key)
		if pass and pass.id == 0 then
			self:GrantPass(player, key)
			return true, "[Studio] Test-granted " .. pass.name
		end
	elseif kind == "product" then
		local product = Products.Product(key)
		if product and product.id == 0 and self:GrantProduct(player, key) then
			return true, "[Studio] Test-granted " .. product.name
		end
	end
	return false
end

function MarketService:Start()
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		local pass = Products.PassById(passId)
		if pass then
			self:GrantPass(player, pass.key)
		end
	end)
end

return MarketService
