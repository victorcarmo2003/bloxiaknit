--!strict
-- PlayerNet: Player-specific network contracts

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lync = require(ReplicatedStorage.Packages.Lync)

local PlayerNet = {}

PlayerNet.PlayerData = Lync.query("PlayerData", Lync.auto, Lync.auto)

PlayerNet.PlayerJoined = Lync.packet("PlayerJoined", Lync.nothing, { unreliable = false })

return table.freeze(PlayerNet)
