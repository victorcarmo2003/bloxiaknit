--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bloxia = require(ReplicatedStorage.Shared.Bloxia)

local __NAME__System = Bloxia.System({
	Name = "__NAME__System",
	Phase = "Heartbeat",
})

function __NAME__System:Init(): ()
	self.ECSComponents = Bloxia.ECS.components()
end

function __NAME__System:Start(): ()
end

function __NAME__System:Update(deltaTime: number): ()
	local _dt = deltaTime
end

return __NAME__System
