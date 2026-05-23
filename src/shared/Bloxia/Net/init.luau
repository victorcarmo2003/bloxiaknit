--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lync = require(ReplicatedStorage.Packages.Lync)
local Registry = require(script.Registry)

local definitions: any? = nil

local Net = {}

function Net.configure(options: any): ()
	Lync.configure(options)
end

function Net.defineAll(): any
	if definitions ~= nil then
		return definitions
	end

	definitions = Registry.define(Lync)
	return definitions
end

function Net.get(): any
	return Net.defineAll()
end

function Net.start(): any
	Net.defineAll()

	if not Lync.isStarted() then
		Lync.start()
	end

	return definitions
end

function Net.raw(): any
	return Lync
end

return table.freeze(Net)
