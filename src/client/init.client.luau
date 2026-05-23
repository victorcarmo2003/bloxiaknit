--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bloxia = require(ReplicatedStorage.Shared.Bloxia)

Bloxia.Framework.AddControllers(script.Controllers)

local components = script:FindFirstChild("Components")
if components then
	Bloxia.Framework.AddComponents(components)
end

local systems = script:FindFirstChild("Systems")
if systems then
	Bloxia.Framework.AddSystems(systems)
end

Bloxia.Framework.Start({
	Network = {
		stats = true,
	},
})
	:andThen(function()
		print("[BLOXIA] Client runtime started")
	end)
	:catch(warn)
