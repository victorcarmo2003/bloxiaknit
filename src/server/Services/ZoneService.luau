--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local QuickZone = require(ReplicatedStorage.Packages.QuickZone)
local Bloxia = require(ReplicatedStorage.Shared.Bloxia)

local ZoneService = Bloxia.Service({
	Name = "ZoneService",
})

function ZoneService:Init(): ()
	self._net = self.Net.Zone
	self._lyncGroup = self._net.ActivePlayers
	self._zones = {}
end

function ZoneService:Start(): ()
	QuickZone:configure({
		enabled = true,
		autoSyncRate = 10,
		frameBudget = 0.5,
	})

	Players.PlayerAdded:Connect(function(player)
		self._lyncGroup:add(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self._lyncGroup:remove(player)
	end)

	for _, player in Players:GetPlayers() do
		self._lyncGroup:add(player)
	end
end

function ZoneService:CreateBoxZone(zoneId: string, cframe: CFrame, size: Vector3, isDynamic: boolean?): any
	local zone = QuickZone.Zone.new({
		cframe = cframe,
		size = size,
		shape = "Block",
		isDynamic = isDynamic == true,
		metadata = {
			zoneId = zoneId,
		},
	})

	self._zones[zoneId] = zone
	return zone
end

function ZoneService:NotifyPlayerZone(player: Player, zoneId: string, inside: boolean): ()
	self._net.PlayerZoneChanged:send({
		zoneId = zoneId,
		inside = inside,
	}, player)
end

return ZoneService
