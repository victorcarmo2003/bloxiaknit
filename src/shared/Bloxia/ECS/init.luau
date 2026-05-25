--!strict
-- BLOXIA ECS Wrapper

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jecs = require(ReplicatedStorage.Packages.jecs)

local ECS = {}

-- Component and tag preregistration functions (module-level, not world-bound)
ECS.component = jecs.component :: () -> any
ECS.tag = jecs.tag :: () -> any

-- Query class reference
ECS.Query = jecs.Query

-- World creation
ECS.World = jecs.World

-- Precreate the shared world
local world = jecs.World.new()
ECS.world = world

return table.freeze(ECS)
