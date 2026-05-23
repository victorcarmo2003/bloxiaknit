--!strict

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local ECS = require(script.Parent.Parent.ECS)
local Net = require(script.Parent.Parent.Net)

type ModuleDef = {
	Name: string,
	DependsOn: { string }?,
	Init: ((self: any) -> ())?,
	Start: ((self: any) -> ())?,
	Stop: ((self: any) -> ())?,
	Destroy: ((self: any) -> ())?,
	_bloxia: any?,
	_bloxiaStarted: boolean?,
	_bloxiaInitDone: boolean?,
	[any]: any,
}

type ComponentDef = ModuleDef & {
	Tag: string?,
	Ancestors: { Instance }?,
	Construct: ((self: any, instance: Instance) -> ())?,
}

type SystemDef = ModuleDef & {
	WorldName: string?,
	Phase: string?,
	Update: ((self: any, deltaTime: number) -> ())?,
}

local IS_SERVER = RunService:IsServer()

local Framework = {}

local services: { [string]: any } = {}
local controllers: { [string]: any } = {}
local components: { [string]: ComponentDef } = {}
local systems: { [string]: SystemDef } = {}
local componentInstances: { [string]: { [Instance]: any } } = {}
local componentConnections: { any } = {}
local systemConnections: { any } = {}
local moduleMetadata: { [string]: { name: string, kind: string, dependsOn: { string } } } = {}

local loaded = false
local started = false
local startPromise: any? = nil

local function copyArray(source: { any }?): { any }
	local result = {}

	if source == nil then
		return result
	end

	for _, value in source do
		table.insert(result, value)
	end

	return result
end

local function makeResolvedPromise(success: boolean, result: any): any
	local promise = {}

	function promise:andThen(callback: (any) -> any): any
		if success then
			local ok, nextResult = pcall(callback, result)
			return makeResolvedPromise(ok, nextResult)
		end

		return self
	end

	function promise:catch(callback: (any) -> any): any
		if not success then
			local ok, nextResult = pcall(callback, result)
			return makeResolvedPromise(ok, nextResult)
		end

		return self
	end

	function promise:await(): (boolean, any)
		return success, result
	end

	return promise
end

local function makePromise(executor: () -> any): any
	local ok, result = pcall(executor)
	return makeResolvedPromise(ok, result)
end

local function getRegistry(kind: string): { [string]: any }
	if kind == "Service" then
		return services
	elseif kind == "Controller" then
		return controllers
	elseif kind == "Component" then
		return components
	elseif kind == "System" then
		return systems
	end

	error(`Unknown Bloxia module kind "{kind}"`, 3)
end

local function getModuleByName(name: string): any
	return services[name] or controllers[name] or components[name] or systems[name]
end

local function assertName(definition: ModuleDef): ()
	assert(type(definition.Name) == "string" and definition.Name ~= "", "Bloxia modules require a Name")
end

local function register(definition: ModuleDef, kind: string): any
	if started then
		error(`Cannot register Bloxia {kind} "{definition.Name}" after Framework.Start()`, 3)
	end

	assertName(definition)

	local registry = getRegistry(kind)
	if registry[definition.Name] ~= nil then
		error(`Duplicate Bloxia {kind} "{definition.Name}"`, 3)
	end

	local dependsOn = copyArray(definition.DependsOn)
	definition.DependsOn = dependsOn
	definition._bloxia = table.freeze({
		name = definition.Name,
		kind = kind,
		dependsOn = table.freeze(dependsOn),
	})

	registry[definition.Name] = definition
	moduleMetadata[definition.Name] = {
		name = definition.Name,
		kind = kind,
		dependsOn = dependsOn,
	}

	return definition
end

local function validateComponentDependencies(definition: ComponentDef): ()
	for _, dependencyName in definition.DependsOn or {} do
		local dependency = getModuleByName(dependencyName)

		if dependency == nil then
			error(`{definition.Name} depends on missing Bloxia module "{dependencyName}"`, 3)
		end
	end
end

local function requireChildren(parent: Instance, deep: boolean): ()
	for _, child in parent:GetChildren() do
		if child:IsA("ModuleScript") then
			require(child)
		elseif deep and child:IsA("Folder") then
			requireChildren(child, true)
		end
	end
end

local function injectRuntime(module: any): ()
	module.Framework = Framework
	module.Net = Net.get()
	module.ECS = ECS
	module.ECSComponents = ECS.components(module.WorldName)
	module.Services = services
	module.Controllers = controllers
	module.Components = components
	module.Systems = systems

	if module._bloxia ~= nil and module._bloxia.kind == "System" then
		module.World = ECS.world(module.WorldName)
		module.Jecs = ECS.raw()
	end
end

local function resolveDependencies(module: ModuleDef, stack: { [string]: boolean }): ()
	if module._bloxiaInitDone then
		return
	end

	if stack[module.Name] then
		error(`Circular Bloxia dependency detected at "{module.Name}"`, 3)
	end

	stack[module.Name] = true

	for _, dependencyName in module.DependsOn or {} do
		local dependency = getModuleByName(dependencyName)

		if dependency == nil then
			error(`{module.Name} depends on missing Bloxia module "{dependencyName}"`, 3)
		end

		resolveDependencies(dependency, stack)
	end

	injectRuntime(module)

	if module.Init ~= nil then
		module:Init()
	end

	module._bloxiaInitDone = true
	stack[module.Name] = nil
end

local function initRegistry(registry: { [string]: any }): ()
	for _, module in registry do
		resolveDependencies(module, {})
	end
end

local function startRegistry(registry: { [string]: any }): ()
	for _, module in registry do
		local function startModule(target: ModuleDef, stack: { [string]: boolean }): ()
			if target._bloxiaStarted then
				return
			end

			if stack[target.Name] then
				error(`Circular Bloxia start dependency detected at "{target.Name}"`, 3)
			end

			stack[target.Name] = true

			for _, dependencyName in target.DependsOn or {} do
				local dependency = getModuleByName(dependencyName)

				if dependency == nil then
					error(`{target.Name} depends on missing Bloxia module "{dependencyName}"`, 3)
				end

				startModule(dependency, stack)
			end

			if target.Start ~= nil then
				target:Start()
			end

			target._bloxiaStarted = true
			stack[target.Name] = nil
		end

		startModule(module, {})
	end
end

local function shouldTrackComponent(definition: ComponentDef, instance: Instance): boolean
	local ancestors = definition.Ancestors

	if ancestors == nil or #ancestors == 0 then
		return true
	end

	for _, ancestor in ancestors do
		if instance:IsDescendantOf(ancestor) then
			return true
		end
	end

	return false
end

local function createComponentInstance(definition: ComponentDef, instance: Instance): ()
	if not shouldTrackComponent(definition, instance) then
		return
	end

	local byInstance = componentInstances[definition.Name]
	if byInstance == nil then
		byInstance = {}
		componentInstances[definition.Name] = byInstance
	end

	if byInstance[instance] ~= nil then
		return
	end

	local component = {}
	for key, value in definition do
		component[key] = value
	end

	component.Instance = instance
	component.Framework = Framework
	component.Net = Net.get()
	component.ECS = ECS
	component.ECSComponents = ECS.components()
	component.Services = services
	component.Controllers = controllers
	component.Components = components
	component.Systems = systems

	byInstance[instance] = component

	if component.Construct ~= nil then
		component:Construct(instance)
	end

	if component.Init ~= nil then
		component:Init()
	end

	if started and component.Start ~= nil then
		component:Start()
		component._bloxiaStarted = true
	end
end

local function destroyComponentInstance(definition: ComponentDef, instance: Instance): ()
	local byInstance = componentInstances[definition.Name]
	local component = if byInstance then byInstance[instance] else nil

	if component == nil then
		return
	end

	if component.Stop ~= nil and component._bloxiaStarted then
		component:Stop()
	end

	if component.Destroy ~= nil then
		component:Destroy()
	end

	byInstance[instance] = nil
end

local function startComponentObserver(definition: ComponentDef): ()
	local tag = definition.Tag or definition.Name

	for _, instance in CollectionService:GetTagged(tag) do
		createComponentInstance(definition, instance)
	end

	table.insert(componentConnections, CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance)
		createComponentInstance(definition, instance)
	end))

	table.insert(componentConnections, CollectionService:GetInstanceRemovedSignal(tag):Connect(function(instance)
		destroyComponentInstance(definition, instance)
	end))
end

local function startComponents(): ()
	for _, definition in components do
		validateComponentDependencies(definition)
		startComponentObserver(definition)

		local byInstance = componentInstances[definition.Name]
		if byInstance ~= nil then
			for _, component in byInstance do
				if not component._bloxiaStarted and component.Start ~= nil then
					component:Start()
					component._bloxiaStarted = true
				end
			end
		end
	end
end

local function startSystemLoops(): ()
	for _, system in systems do
		if system.Update ~= nil then
			local phase = system.Phase or "Heartbeat"
			local connection

			if phase == "RenderStepped" and not IS_SERVER then
				connection = RunService.RenderStepped:Connect(function(deltaTime)
					system:Update(deltaTime)
				end)
			elseif phase == "Stepped" then
				connection = RunService.Stepped:Connect(function(_, deltaTime)
					system:Update(deltaTime)
				end)
			else
				connection = RunService.Heartbeat:Connect(function(deltaTime)
					system:Update(deltaTime)
				end)
			end

			table.insert(systemConnections, connection)
		end
	end
end

function Framework.Service(definition: ModuleDef): any
	return register(definition, "Service")
end

function Framework.Controller(definition: ModuleDef): any
	return register(definition, "Controller")
end

function Framework.Component(definition: ComponentDef): any
	return register(definition, "Component")
end

function Framework.System(definition: SystemDef): any
	return register(definition, "System")
end

Framework.CreateService = Framework.Service
Framework.CreateController = Framework.Controller
Framework.CreateComponent = Framework.Component
Framework.CreateSystem = Framework.System

function Framework.AddServices(parent: Instance): ()
	requireChildren(parent, false)
end

function Framework.AddServicesDeep(parent: Instance): ()
	requireChildren(parent, true)
end

function Framework.AddControllers(parent: Instance): ()
	requireChildren(parent, false)
end

function Framework.AddControllersDeep(parent: Instance): ()
	requireChildren(parent, true)
end

function Framework.AddComponents(parent: Instance): ()
	requireChildren(parent, false)
end

function Framework.AddComponentsDeep(parent: Instance): ()
	requireChildren(parent, true)
end

function Framework.AddSystems(parent: Instance): ()
	requireChildren(parent, false)
end

function Framework.AddSystemsDeep(parent: Instance): ()
	requireChildren(parent, true)
end

local function doStart(options: any?): any
	if started then
		return Framework
	end

	local startOptions = options or {}

	if startOptions.Network ~= false then
		local lync = Net.raw()

		if startOptions.Network ~= nil and not lync.isStarted() then
			Net.configure(startOptions.Network)
		end

		Net.defineAll()
		Net.start()
	end

	if IS_SERVER then
		initRegistry(services)
		startRegistry(services)
	else
		initRegistry(controllers)
		startRegistry(controllers)
	end

	started = true
	loaded = true
	startComponents()
	initRegistry(systems)
	startRegistry(systems)
	startSystemLoops()

	return Framework
end

function Framework.Start(options: any?): any
	startPromise = makePromise(function()
		return doStart(options)
	end)

	return startPromise
end

function Framework.OnStart(): any
	if startPromise ~= nil then
		return startPromise
	end

	return makeResolvedPromise(started, if started then Framework else "Bloxia.Framework has not started")
end

function Framework.Stop(): ()
	for _, connection in systemConnections do
		connection:Disconnect()
	end
	table.clear(systemConnections)

	for _, system in systems do
		if system.Stop ~= nil and system._bloxiaStarted then
			system:Stop()
		end
		system._bloxiaStarted = false
	end

	for _, connection in componentConnections do
		connection:Disconnect()
	end
	table.clear(componentConnections)

	for _, byInstance in componentInstances do
		for _, component in byInstance do
			if component.Stop ~= nil and component._bloxiaStarted then
				component:Stop()
			end
		end
	end

	local registry = if IS_SERVER then services else controllers
	for _, module in registry do
		if module.Stop ~= nil and module._bloxiaStarted then
			module:Stop()
		end
		module._bloxiaStarted = false
	end

	started = false
end

function Framework.GetService(name: string): any
	return assert(services[name], `Could not find Bloxia service "{name}"`)
end

function Framework.GetController(name: string): any
	return assert(controllers[name], `Could not find Bloxia controller "{name}"`)
end

function Framework.GetComponent(name: string): any
	return assert(components[name], `Could not find Bloxia component "{name}"`)
end

function Framework.GetSystem(name: string): any
	return assert(systems[name], `Could not find Bloxia system "{name}"`)
end

function Framework.GetServices(): any
	return services
end

function Framework.GetControllers(): any
	return controllers
end

function Framework.GetComponents(): any
	return components
end

function Framework.GetSystems(): any
	return systems
end

function Framework.GetComponentInstances(name: string): any
	return componentInstances[name] or {}
end

function Framework.GetModuleMetadata(): any
	local snapshot = {}

	for name, metadata in moduleMetadata do
		snapshot[name] = table.freeze({
			name = metadata.name,
			kind = metadata.kind,
			dependsOn = table.freeze(copyArray(metadata.dependsOn)),
		})
	end

	return table.freeze(snapshot)
end

function Framework.IsStarted(): boolean
	return started
end

function Framework.IsLoaded(): boolean
	return loaded
end

return table.freeze(Framework)
