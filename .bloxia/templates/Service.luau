--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bloxia = require(ReplicatedStorage.Shared.Bloxia)

local __NAME__Service = Bloxia.Service({
	Name = "__NAME__Service",
})

function __NAME__Service:Init(): ()
	self._net = self.Net
end

function __NAME__Service:Start(): ()
end

return __NAME__Service
