--!strict
-- BLOXIA Framework Manager

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Lync = require(ReplicatedStorage.Packages.Lync)

local Framework = {}

function Framework.AddServices(folder: Instance)
	for _, child in folder:GetChildren() do
		if child:IsA("ModuleScript") then
			local module = require(child)
			if module and module.Name and module._bloxiaInit then
				module:_bloxiaInit()
			end
		end
	end
end

function Framework.AddControllers(folder: Instance)
	for _, child in folder:GetChildren() do
		if child:IsA("ModuleScript") then
			local module = require(child)
			if module and module.Name and module._bloxiaInit then
				module:_bloxiaInit()
			end
		end
	end
end

function Framework.AddComponents(_folder: Instance)
end

function Framework.AddSystems(_folder: Instance)
end

function Framework.GetService(name: string)
	return require(ReplicatedStorage.Shared.Bloxia)._services[name]
end

function Framework.GetController(name: string)
	return require(ReplicatedStorage.Shared.Bloxia)._controllers[name]
end

function Framework.Start(config: { Network: { stats: boolean?, globalRateLimit: { maxPerSecond: number }? } }?): { andThen: (self, (()->())->any) -> any, catch: (self, (any)->()) -> any }
	local promise = {}
	local resolved = false
	local rejected = false
	local rejectValue = nil
	local thenCallbacks: { (()->()) } = {}
	local catchCallbacks: { (any)->() } = {}

	local Bloxia = require(ReplicatedStorage.Shared.Bloxia)

	if config and config.Network then
		if config.Network.stats then
			Lync.configure({ stats = true })
		end
		if config.Network.globalRateLimit then
			Lync.configure({
				globalRateLimit = {
					maxPerSecond = config.Network.globalRateLimit.maxPerSecond,
				},
			})
		end
	end

	Lync.start()

	local ok, err = pcall(function()
		if RunService:IsServer() then
			for _, service in Bloxia._services do
				service:_bloxiaStart()
			end

			Players.PlayerAdded:Connect(function(player)
				for _, service in Bloxia._services do
					task.spawn(function()
						pcall(function() service:PlayerAdded(player) end)
					end)
				end
			end)

			Players.PlayerRemoving:Connect(function(player)
				for _, service in Bloxia._services do
					task.spawn(function()
						pcall(function() service:PlayerRemoving(player) end)
					end)
				end
			end)

			for _, player in Players:GetPlayers() do
				for _, service in Bloxia._services do
					pcall(function() service:PlayerAdded(player) end)
				end
			end
		else
			for _, controller in Bloxia._controllers do
				controller:_bloxiaStart()
			end
		end
	end)

	if ok then
		resolved = true
		for _, cb in thenCallbacks do
			task.spawn(cb)
		end
	else
		rejected = true
		rejectValue = err
		for _, cb in catchCallbacks do
			task.spawn(cb, err)
		end
	end

	function promise:andThen(_, cb: ()->())
		if resolved then
			task.spawn(cb)
		else
			table.insert(thenCallbacks, cb)
		end
		return promise
	end

	function promise:catch(_, cb: (any)->())
		if rejected then
			task.spawn(cb, rejectValue)
		else
			table.insert(catchCallbacks, cb)
		end
		return promise
	end

	return promise
end

return table.freeze(Framework)
