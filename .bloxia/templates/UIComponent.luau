--!strict

local __NAME__ = {}

function __NAME__.mount(scope: any, target: Instance): Instance
	local frame = scope:New("Frame")({
		Name = "__NAME__",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = target,
	})

	return frame
end

return table.freeze(__NAME__)
