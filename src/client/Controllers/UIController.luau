--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Bloxia = require(ReplicatedStorage.Shared.Bloxia)

local App = require(script.Parent.Parent.UI.App)

local UIController = Bloxia.Controller({
	Name = "UIController",
})

function UIController:Start(): ()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local scope = Fusion.scoped(Fusion)

	self._scope = scope
	self._root = App.mount(scope, playerGui)
end

function UIController:Stop(): ()
	if self._root then
		self._root:Destroy()
		self._root = nil
	end

	if self._scope then
		Fusion.doCleanup(self._scope)
		self._scope = nil
	end
end

return UIController
