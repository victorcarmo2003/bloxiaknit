--!strict

local orderedComponents = {
	-- Add ECS component modules here in stable order.
}

local Registry = {}

function Registry.define(ECS: any, worldName: string): any
	local components = ECS.components(worldName)

	for _, defineComponent in orderedComponents do
		defineComponent(ECS, worldName, components)
	end

	return components
end

return Registry
