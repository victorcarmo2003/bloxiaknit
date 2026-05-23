--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bloxia = require(ReplicatedStorage.Shared.Bloxia)

local __NAME__Controller = Bloxia.Controller({
	Name = "__NAME__Controller",
})

function __NAME__Controller:Init(): ()
	self._net = self.Net
end

function __NAME__Controller:Start(): ()
end

return __NAME__Controller
