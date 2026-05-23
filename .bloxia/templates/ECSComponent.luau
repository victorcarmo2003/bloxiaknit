--!strict

return function(ECS: any, worldName: string, components: { [string]: any }): any
	components.__NAME__ = ECS.component("__NAME__", worldName)
	return components.__NAME__
end
