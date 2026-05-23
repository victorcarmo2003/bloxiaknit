--!strict

local orderedSchemas = {
	require(script.Parent.Schemas.PlayerNet),
	require(script.Parent.Schemas.ZoneNet),
}

local Registry = {}

function Registry.define(Lync: any): any
	local net = {}

	for _, schema in orderedSchemas do
		net[schema.name] = schema.define(Lync)
	end

	return table.freeze(net)
end

return table.freeze(Registry)
