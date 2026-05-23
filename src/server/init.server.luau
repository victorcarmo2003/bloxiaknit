--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bloxia = require(ReplicatedStorage.Shared.Bloxia)

Bloxia.Framework.AddServices(script.Services)

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
		globalRateLimit = {
			maxPerSecond = 120,
		},
	},
})
	:andThen(function()
		print("[BLOXIA] Server runtime started")
	end)
	:catch(warn)
