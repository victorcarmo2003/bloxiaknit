--!strict
-- BLOXIA Net Wrapper

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lync = require(ReplicatedStorage.Packages.Lync)

local Net = {}

function Net.raw()
	return Lync
end

return table.freeze(Net)
