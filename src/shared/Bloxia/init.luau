--!strict

local Net = require(script.Net)
local ECS = require(script.ECS)
local Framework = require(script.Framework)

local Bloxia = {
	Net = Net,
	ECS = ECS,
	Framework = Framework,
	Service = Framework.Service,
	Controller = Framework.Controller,
	Component = Framework.Component,
	System = Framework.System,
}

return table.freeze(Bloxia)
