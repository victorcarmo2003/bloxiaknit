--!strict

local PlayerNet = {
	name = "Player",
}

local function createSummaryCodec(Lync: any): any
	return Lync.struct({
		level = Lync.int(0, 1000),
		xp = Lync.int(0, 100000000),
		coins = Lync.int(0, 100000000),
	})
end

function PlayerNet.define(Lync: any): any
	local summaryCodec = createSummaryCodec(Lync)

	return table.freeze({
		DataReady = Lync.packet("Player.DataReady", summaryCodec),
		GetDataSummary = Lync.query("Player.GetDataSummary", Lync.nothing, summaryCodec, {
			timeout = 5,
			rateLimit = {
				maxPerSecond = 2,
			},
		}),
		Ping = Lync.query("Player.Ping", Lync.nothing, Lync.f64, {
			timeout = 3,
			rateLimit = {
				maxPerSecond = 5,
			},
		}),
	})
end

return table.freeze(PlayerNet)
