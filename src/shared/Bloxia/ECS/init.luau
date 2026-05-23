--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local jecs = require(ReplicatedStorage.Packages.jecs)
local Registry = require(script.Registry)

local ECS = {}

local worlds: { [string]: any } = {}
local componentRegistries: { [string]: { [string]: any } } = {}

local function defaultWorldName(): string
	return if RunService:IsServer() then "Server" else "Client"
end

function ECS.raw(): any
	return jecs
end

function ECS.world(name: string?): any
	local worldName = name or defaultWorldName()
	local world = worlds[worldName]

	if world == nil then
		world = jecs.World.new()
		worlds[worldName] = world
		componentRegistries[worldName] = {}
		Registry.define(ECS, worldName)
	end

	return world
end

function ECS.components(name: string?): { [string]: any }
	local worldName = name or defaultWorldName()

	if componentRegistries[worldName] == nil then
		ECS.world(worldName)
	end

	return componentRegistries[worldName]
end

function ECS.component(componentName: string, worldName: string?): any
	assert(type(componentName) == "string" and componentName ~= "", "ECS.component requires a component name")

	local registry = ECS.components(worldName)
	local existing = registry[componentName]

	if existing ~= nil then
		return existing
	end

	local world = ECS.world(worldName)
	local component = world:component()

	registry[componentName] = component

	if jecs.Name ~= nil then
		world:set(component, jecs.Name, componentName)
	end

	return component
end

function ECS.tag(tagName: string, worldName: string?): any
	assert(type(tagName) == "string" and tagName ~= "", "ECS.tag requires a tag name")

	local registry = ECS.components(worldName)
	local existing = registry[tagName]

	if existing ~= nil then
		return existing
	end

	local world = ECS.world(worldName)
	local tag = world:entity()

	registry[tagName] = tag

	if jecs.Name ~= nil then
		world:set(tag, jecs.Name, tagName)
	end

	return tag
end

function ECS.resetWorld(name: string?): ()
	local worldName = name or defaultWorldName()
	worlds[worldName] = nil
	componentRegistries[worldName] = nil
end

function ECS.getWorlds(): { [string]: any }
	return worlds
end

return table.freeze(ECS)
