--!strict

local ZoneNet = {
	name = "Zone",
}

function ZoneNet.define(Lync: any): any
	return table.freeze({
		ActivePlayers = Lync.group("Zone.ActivePlayers"),
		PlayerZoneChanged = Lync.packet("Zone.PlayerZoneChanged", Lync.struct({
			zoneId = Lync.string(64),
			inside = Lync.bool,
		}), {
			timestamp = "frame",
		}),
	})
end

return table.freeze(ZoneNet)
