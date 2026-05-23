--!strict

local App = {}

function App.mount(scope: any, target: Instance): ScreenGui
	local root = scope:New("ScreenGui")({
		Name = "BloxiaDebugGui",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		Parent = target,
	})

	scope:New("TextLabel")({
		Name = "Status",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(220, 32),
		BackgroundTransparency = 0.25,
		BackgroundColor3 = Color3.fromRGB(18, 20, 24),
		BorderSizePixel = 0,
		Font = Enum.Font.FredokaOne,
		Text = "BLOXIA runtime online",
		TextColor3 = Color3.fromRGB(238, 241, 245),
		TextSize = 14,
		Parent = root,
	})

	return root
end

return table.freeze(App)
