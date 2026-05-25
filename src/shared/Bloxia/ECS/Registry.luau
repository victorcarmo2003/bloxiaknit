--!strict
-- BLOXIA ECS Component Registry

local Registry = {}

Registry.orderedComponents = {
	require(script.Parent.Components.TowerComponents),
	require(script.Parent.Components.EnemyComponents),
}

return table.freeze(Registry)
