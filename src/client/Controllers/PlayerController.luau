--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bloxia = require(ReplicatedStorage.Shared.Bloxia)

local PlayerController = Bloxia.Controller({
	Name = "PlayerController",
})

function PlayerController:Init(): ()
	local Lync = Bloxia.Net.raw()
	local playerNet = self.Net.Player

	self._scope = Lync.scope()
	self._summary = nil

	self._scope:on(playerNet.DataReady, function(summary)
		self._summary = summary
		print("[BLOXIA] Player data ready", summary.level, summary.xp, summary.coins)
	end)
end

function PlayerController:Start(): ()
	local playerNet = self.Net.Player
	local summary = playerNet.GetDataSummary:request(nil)

	if summary ~= nil then
		self._summary = summary
		print("[BLOXIA] Player data summary", summary.level, summary.xp, summary.coins)
	end

	local serverClock = playerNet.Ping:request(nil)

	if serverClock ~= nil then
		print("[BLOXIA] Server clock", serverClock)
	end
end

return PlayerController
