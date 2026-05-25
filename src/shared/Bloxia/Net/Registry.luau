--!strict
-- BLOXIA Net Schema Registry
-- All schemas are loaded automatically by the framework.

local Registry = {}

Registry.orderedSchemas = {
	require(script.Parent.Schemas.PlayerNet),
	require(script.Parent.Schemas.ZoneNet),
	require(script.Parent.Schemas.TDNet),
}

return table.freeze(Registry)
