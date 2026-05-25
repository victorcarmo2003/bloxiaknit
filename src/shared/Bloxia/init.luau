--!strict
-- BLOXIA Framework Entry Point

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lync = require(ReplicatedStorage.Packages.Lync)
local jecs = require(ReplicatedStorage.Packages.jecs)

local Framework = require(script.Framework)
local Net = require(script.Net)
local ECS = require(script.ECS)

local Bloxia = {}

Bloxia._services = {}
Bloxia._controllers = {}

local function resolveNetSchemas()
	if RunService:IsServer() then
		local schemaFolder = script.Net.Schemas
		local schemas = {}
		for _, child in schemaFolder:GetChildren() do
			if child:IsA("ModuleScript") then
				local name = child.Name:match("^(.*)Net$")
				if name then
					schemas[name] = require(child)
				end
			end
		end
		return schemas
	else
		local schemaFolder = script.Net.Schemas
		local schemas = {}
		for _, child in schemaFolder:GetChildren() do
			if child:IsA("ModuleScript") then
				local name = child.Name:match("^(.*)Net$")
				if name then
					schemas[name] = require(child)
				end
			end
		end
		return schemas
	end
end

local function resolveDependency(name, kind)
	if kind == "Service" then
		return Bloxia._services[name]
	elseif kind == "Controller" then
		return Bloxia._controllers[name]
	end
	return nil
end

function Bloxia.Service(config: { Name: string, DependsOn: { string }? }): { Name: string }
	local self = {}
	self.Name = config.Name
	self.DependsOn = config.DependsOn or {}
	self._initDone = false
	self._startDone = false

	function self:_resolveNet()
		self.Net = resolveNetSchemas()
	end

	function self:_resolveDeps()
		for _, depName in self.DependsOn do
			local dep = resolveDependency(depName, "Service")
			if dep then
				self[depName] = dep
			end
		end
	end

	function self:Init() end
	function self:Start() end
	function self:PlayerAdded(_player: Player) end
	function self:PlayerRemoving(_player: Player) end

	function self:_bloxiaInit()
		self:_resolveNet()
		self:_resolveDeps()
		self:Init()
		self._initDone = true
	end

	function self:_bloxiaStart()
		if not self._initDone then
			self:_bloxiaInit()
		end
		self:Start()
		self._startDone = true
	end

	Bloxia._services[self.Name] = self

	return self
end

function Bloxia.Controller(config: { Name: string, DependsOn: { string }? }): { Name: string }
	local self = {}
	self.Name = config.Name
	self.DependsOn = config.DependsOn or {}
	self._initDone = false
	self._startDone = false

	function self:_resolveNet()
		self.Net = resolveNetSchemas()
	end

	function self:_resolveDeps()
		for _, depName in self.DependsOn do
			local dep = resolveDependency(depName, "Controller")
			if dep then
				self[depName] = dep
			end
		end
	end

	function self:Init() end
	function self:Start() end

	function self:_bloxiaInit()
		self:_resolveNet()
		self:_resolveDeps()
		self:Init()
		self._initDone = true
	end

	function self:_bloxiaStart()
		if not self._initDone then
			self:_bloxiaInit()
		end
		self:Start()
		self._startDone = true
	end

	Bloxia._controllers[self.Name] = self

	return self
end

Bloxia.Framework = Framework
Bloxia.Net = Net
Bloxia.ECS = ECS

return table.freeze(Bloxia)
