--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bloxia = require(ReplicatedStorage.Shared.Bloxia)

local __NAME__Component = Bloxia.Component({
	Name = "__NAME__Component",
	Tag = "__NAME__",
})

function __NAME__Component:Construct(instance: Instance): ()
	self.Instance = instance
end

function __NAME__Component:Init(): ()
end

function __NAME__Component:Start(): ()
end

function __NAME__Component:Destroy(): ()
end

return __NAME__Component
