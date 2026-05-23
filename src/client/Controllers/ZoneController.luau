--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bloxia = require(ReplicatedStorage.Shared.Bloxia)

local ZoneController = Bloxia.Controller({
	Name = "ZoneController",
})

function ZoneController:Init(): ()
	local Lync = Bloxia.Net.raw()
	local zoneNet = self.Net.Zone

	self._scope = Lync.scope()
	self._scope:on(zoneNet.PlayerZoneChanged, function(payload, _sender, _timestamp)
		print("[BLOXIA] Zone changed", payload.zoneId, payload.inside)
	end)
end

return ZoneController
