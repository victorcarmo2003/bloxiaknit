# BLOXIA Framework

`Bloxia.Framework` is the public lifecycle API for game modules. It is a native BLOXIA runtime; gameplay code should not import Knit.

## Decision Map

- Use `Service` for server authority, public feature APIs, persistence, economy and anti-cheat.
- Use `Controller` for client input, camera, UI orchestration, prediction and presentation.
- Use `Component` for behavior attached to tagged Roblox instances.
- Use `System` for Jecs simulation over many entities or data rows.
- Use `NetSchema` for every client/server contract.
- Use plain utilities for stateless reusable helpers.

## Public API

```luau
local Bloxia = require(ReplicatedStorage.Shared.Bloxia)

local InventoryService = Bloxia.Service({
	Name = "InventoryService",
	DependsOn = {
		"PlayerDataService",
	},
})

function InventoryService:Init(): ()
end

function InventoryService:Start(): ()
end

return InventoryService
```

Controllers use the same shape:

```luau
local InventoryController = Bloxia.Controller({
	Name = "InventoryController",
})

function InventoryController:Init(): ()
end

function InventoryController:Start(): ()
end

return InventoryController
```

Components are tag-based instance modules:

```luau
local DoorComponent = Bloxia.Component({
	Name = "DoorComponent",
	Tag = "Door",
})

function DoorComponent:Construct(instance: Instance): ()
	self.Instance = instance
end

function DoorComponent:Start(): ()
end

return DoorComponent
```

Systems are Jecs update loops for data-oriented simulation:

```luau
local MovementSystem = Bloxia.System({
	Name = "MovementSystem",
	Phase = "Heartbeat",
})

function MovementSystem:Update(deltaTime: number): ()
	for entity, position, velocity in self.World:query(self.ECSComponents.Position, self.ECSComponents.Velocity) do
		self.World:set(entity, self.ECSComponents.Position, position + velocity * deltaTime)
	end
end

return MovementSystem
```

## Lifecycle

- `Init` runs during framework initialization.
- `Start` runs after all modules have initialized.
- `Update` runs every frame for Systems that define it.
- `DependsOn` injects dependencies into `self.Services` or `self.Controllers`.
- Client controllers should depend on other controllers only; use `Bloxia.Net` for server communication.
- `self.Net` is injected and points to `Bloxia.Net.get()`.
- `self.ECS`, `self.World` and `self.ECSComponents` are injected into Systems.
- `self.Framework` is injected and points to `Bloxia.Framework`.
- Components receive `self.Instance` and run once per tagged instance.
- Component `Start` may run after boot when an instance receives its tag.

## Rules

- Do not import Knit.
- Do not expose gameplay remotes through services.
- Use `Bloxia.Net` for every gameplay packet, query and group.
- Components must be small instance behavior units, not global systems.
- Components must not define Lync schemas, mutate ProfileStore data, or own server authority from the client.
- Components belong in `src/server/Components` or `src/client/Components`.
- Use Components for Roblox instance binding; use Systems/Jecs for large data-oriented simulation.
- Systems belong in `src/server/Systems` or `src/client/Systems`.
- ECS component IDs belong in `src/shared/Bloxia/ECS/Components` and must be registered in `src/shared/Bloxia/ECS/Registry.luau`.
- Systems should not create Lync contracts, mutate ProfileStore directly, or create Roblox instances every frame.
- Services may depend only on server Services.
- Controllers may depend only on client Controllers.
- Server Components and Systems may depend only on server Services.
- Client Components and Systems may depend only on client Controllers.
