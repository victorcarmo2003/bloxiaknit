# BLOXIA AI Instructions

These instructions are for agents generating or integrating code in this project.

## Before Writing Code

1. Read `metadata.json`.
2. Read `bloxia.config.json`.
3. Read `.bloxia/framework.md`.
4. Inspect existing Services, Controllers and Net Schemas.
5. For reusable systems, search the BLOXIA library registry before generating from scratch.
6. Prefer installing a compatible reviewed library over inventing a new implementation.

## Code Rules

- Decision map: Service owns server authority/API/persistence; Controller owns client input/UI/presentation; Component owns tagged Instance behavior; System owns Jecs data simulation; NetSchema owns communication; Utility owns pure reusable helpers.
- Server gameplay belongs in `src/server/Services`.
- Client gameplay belongs in `src/client/Controllers`.
- Instance-bound behavior belongs in `src/server/Components` or `src/client/Components`.
- Data-oriented simulation belongs in `src/server/Systems` or `src/client/Systems`.
- ECS component IDs belong in `src/shared/Bloxia/ECS/Components`.
- UI belongs in `src/client/UI`.
- Network contracts belong in `src/shared/Bloxia/Net/Schemas`.
- Register new schema modules in `src/shared/Bloxia/Net/Registry.luau`.
- Register new ECS component modules in `src/shared/Bloxia/ECS/Registry.luau`.
- Use `Bloxia.Service`, `Bloxia.Controller`, `Bloxia.Component` and `Bloxia.System`; do not import Knit.
- Do not create networking inside services, controllers, components or systems.
- Do not create ad hoc `RemoteEvent` or `RemoteFunction` instances.
- Prefer explicit Lync codecs over `Lync.auto`.
- Ask before installing libraries that alter persistence, monetization, permissions or public APIs.

## Dependency Rules

- Services may depend only on server Services.
- Controllers may depend only on client Controllers.
- Server Components and Systems may depend only on server Services.
- Client Components and Systems may depend only on client Controllers.
- Use `Bloxia.Net` instead of `DependsOn` for server/client communication.

## Component Rules

- Components are for behavior attached to tagged Roblox instances.
- Components must declare `Name` and should declare `Tag`.
- Components may read services through `self.Services`, but should not become service replacements.
- Client components may read controllers, but must use `Bloxia.Net` for server communication.
- Components must not create Lync packets, queries or groups.
- Components must not write ProfileStore data directly.
- Client components must not own server authority.

## ECS Rules

- Use Jecs through `Bloxia.ECS`; do not require `Packages.jecs` from feature code.
- Use Systems for frame/update simulation over many entities.
- Use Components for Roblox tagged instances, not for pure ECS data.
- Declare ECS component IDs through `tools/bloxia.ps1 make ecs <Name>` or files under `src/shared/Bloxia/ECS/Components`.
- Systems may read Services/Controllers through injected runtime tables, but should not replace them.
- Server Systems own authoritative simulation; Client Systems may predict, present or interpolate.
- Systems must not define Lync schemas, write ProfileStore directly, or allocate large tables/Instances every frame.

## Integration Rule

Every installed library must include or produce:

- A clear public API.
- A list of files changed or created.
- Any required config parameters.
- Any required schema/data migration notes.
- A validation result.

Run `tools/bloxia.ps1 validate` after changing architecture, installing a library, or generating a feature pack.
