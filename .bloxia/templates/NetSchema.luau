--!strict

local __NAME__Net = {
	name = "__NAME__",
}

function __NAME__Net.define(Lync: any): any
	return table.freeze({
		-- Example = Lync.packet("__NAME__.Example", Lync.struct({ value = Lync.string(64) })),
	})
end

return table.freeze(__NAME__Net)
