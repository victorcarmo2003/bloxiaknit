--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local ProfileStore = require(ServerScriptService.ServerPackages.ProfileStore)
local Bloxia = require(ReplicatedStorage.Shared.Bloxia)

local ProfileTemplate = require(script.Parent.Parent.Data.ProfileTemplate)

local PlayerStore = ProfileStore.New("BLOXIA_PlayerData_v1", ProfileTemplate)
local ActivePlayerStore = if RunService:IsStudio() then PlayerStore.Mock else PlayerStore
local profiles: { [Player]: any } = {}

local PlayerDataService = Bloxia.Service({
	Name = "PlayerDataService",
})

local function getProfileKey(player: Player): string
	return `Player_{player.UserId}`
end

local function toSummary(data: any): { level: number, xp: number, coins: number }
	return {
		level = data.Level or 1,
		xp = data.Experience or 0,
		coins = data.Coins or 0,
	}
end

function PlayerDataService:GetProfile(player: Player): any?
	return profiles[player]
end

function PlayerDataService:GetData(player: Player): any?
	local profile = profiles[player]
	return if profile then profile.Data else nil
end

function PlayerDataService:GetSummary(player: Player): { level: number, xp: number, coins: number }
	local data = self:GetData(player)

	if data == nil then
		return toSummary(ProfileTemplate)
	end

	return toSummary(data)
end

function PlayerDataService:_loadProfile(player: Player): ()
	if profiles[player] ~= nil then
		return
	end

	local profile = ActivePlayerStore:StartSessionAsync(getProfileKey(player), {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if profile == nil then
		player:Kick("Data failed to load. Please rejoin.")
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()

	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil

		if player.Parent == Players then
			player:Kick("Your data session moved to another server. Please rejoin.")
		end
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	profiles[player] = profile
	Bloxia.Net.get().Player.DataReady:send(toSummary(profile.Data), player)
end

function PlayerDataService:_releaseProfile(player: Player): ()
	local profile = profiles[player]

	if profile == nil then
		return
	end

	profiles[player] = nil
	profile:EndSession()
end

function PlayerDataService:Init(): ()
	local playerNet = self.Net.Player

	playerNet.GetDataSummary:handle(function(_data: nil, player: Player)
		return self:GetSummary(player)
	end)

	playerNet.Ping:handle(function(_data: nil, _player: Player?)
		return os.clock()
	end)
end

function PlayerDataService:Start(): ()
	Players.PlayerAdded:Connect(function(player)
		self:_loadProfile(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:_releaseProfile(player)
	end)

	for _, player in Players:GetPlayers() do
		task.spawn(function()
			self:_loadProfile(player)
		end)
	end
end

return PlayerDataService
