--!strict
-- ZoneNet: ZoneService network contracts

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lync = require(ReplicatedStorage.Packages.Lync)

local ZoneNet = {}

ZoneNet.PlayerZoneChanged = Lync.packet("PlayerZoneChanged", Lync.struct({
	zoneId = Lync.string,
	inside = Lync.bool,
}), { unreliable = true })

ZoneNet.ZoneEntered = Lync.packet("ZoneEntered", Lync.struct({
	zoneId = Lync.string,
}), { unreliable = true })

ZoneNet.ZoneExited = Lync.packet("ZoneExited", Lync.struct({
	zoneId = Lync.string,
}), { unreliable = true })

return table.freeze(ZoneNet)
