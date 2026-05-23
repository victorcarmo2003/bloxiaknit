# BLOXIA Pluggable Library Registry

This document defines the intended workflow for reusable BLOXIA libraries stored in a cloud database such as Supabase.

## Goal

BLOXIA should avoid generating common systems from scratch when a compatible, reviewed library already exists. For requests like "make a flight system", the IDE should search the remote registry, compare candidates, ask for missing configuration, and integrate the best match into the current Roblox project.

## Library Types

- `Service`: server-authoritative gameplay logic.
- `Controller`: client behavior, local prediction, input, camera, feedback.
- `Component`: tag-based instance behavior modules.
- `System`: Jecs update-loop modules.
- `ECSComponent`: shared Jecs component ID declarations.
- `NetSchema`: Lync packets, queries, groups and codecs.
- `UIComponent`: Fusion UI modules.
- `DataModule`: ProfileStore templates, migrations and persistence helpers.
- `SharedUtility`: shared pure utilities.
- `AssetBundle`: models, sounds, animations or other Roblox assets.
- `FeaturePack`: a complete feature containing several of the above.

## Remote Registry Model

Each library entry should store:

- `id`: stable unique slug, for example `bloxia.flight.basic`.
- `name`: human-readable name.
- `version`: semantic version.
- `summary`: short description.
- `libraryType`: one of the library types above.
- `tags`: searchable terms like `flight`, `movement`, `character`, `mobile`.
- `dependencies`: Wally packages, BLOXIA modules, Roblox services and asset requirements.
- `publicApi`: exported methods, events, packets, queries and config fields.
- `compatibility`: supported BLOXIA runtime version, Roblox/Luau assumptions and required capabilities.
- `installPlan`: target files, required schema registration, config prompts and post-install steps.
- `source`: code payload, repo URL, storage bucket pointer or signed artifact URL.
- `review`: trust level, author, checksum and moderation status.

## Selection Flow

1. Parse the user request into a feature intent.
2. Search the registry by tags, summary and public API.
3. Filter by compatibility with the current project metadata.
4. Rank candidates by exact feature fit, trust level, version and dependency cost.
5. If one candidate is clearly compatible, show a concise install preview.
6. If several candidates fit, ask the user to choose.
7. If required config is missing, ask only for the needed parameters.
8. Install into the correct BLOXIA folders.
9. Register any `NetSchema` modules before `Bloxia.Net.start()`.
10. Run validation and report changed files.

The local validation command is:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/bloxia.ps1 validate
```

## Compatibility Checks

A candidate must be rejected or require confirmation when:

- It defines Lync packets/groups outside `src/shared/Bloxia/Net/Schemas`.
- It imports Knit directly.
- It uses ad hoc `RemoteEvent` or `RemoteFunction` for gameplay networking.
- It defines components outside `src/server/Components` or `src/client/Components`.
- It defines systems outside `src/server/Systems` or `src/client/Systems`.
- It defines ECS component IDs outside `src/shared/Bloxia/ECS/Components`.
- It makes a component own global state that should belong to a service.
- It makes a system own public API or persistence that should belong to a service.
- It writes server authority into a client controller.
- It requires dependencies missing from `wally.toml`.
- It modifies core runtime files without an explicit install step.
- Its public API does not satisfy the user's requested behavior.
- Its version is outside the supported BLOXIA runtime range.

## User Choice

Ask the user when:

- More than one compatible library fits the request.
- The library changes data schema or ProfileStore templates.
- The feature requires monetization, anti-cheat, permissions or moderation policy choices.
- Install parameters affect gameplay balance, for example speed, cooldowns, stamina or controls.

## Local Install Shape

Feature packs should install into predictable folders:

```txt
src/shared/Bloxia/Net/Schemas/<Feature>Net.luau
src/shared/Bloxia/ECS/Components/<Feature>.luau
src/shared/Bloxia/Features/<Feature>/
src/server/Services/<Feature>Service.luau
src/server/Components/<Feature>Component.luau
src/server/Systems/<Feature>System.luau
src/client/Controllers/<Feature>Controller.luau
src/client/Components/<Feature>Component.luau
src/client/Systems/<Feature>System.luau
src/client/UI/Components/<Feature>/
src/server/Data/<Feature>Data.luau
```

Only create the folders that the feature needs.

## Supabase Tables

Recommended first tables:

- `libraries`
- `library_versions`
- `library_dependencies`
- `library_public_api`
- `library_artifacts`
- `library_reviews`
- `install_events`

Keep immutable version rows. Publishing a new version should create a new row, not mutate code already installed by users.

## Local CLI Hooks

The template ships a PowerShell CLI at `tools/bloxia.ps1`.

- `validate`: checks JSON, Rojo sourcemap and BLOXIA architecture rules.
- `make service <Name>`: creates a Bloxia service from the official template.
- `make controller <Name>`: creates a Bloxia controller from the official template.
- `make net <Name>`: creates and registers a Lync NetSchema.
- `make ecs <Name>`: creates and registers a shared Jecs component ID.
- `make component <Name> --client|--server`: creates a tag-based Bloxia component.
- `make system <Name> --server|--client`: creates a Jecs system.
- `make ui <Name>`: creates a Fusion UI component.
- `make data <Name>`: creates a server data module.
- `cloud search <query>`: searches Supabase library metadata.
- `cloud install <id> --dry-run`: fetches the newest library version metadata for IDE review.

The full native cloud installer should live in the BLOXIA IDE, because it needs UI for candidate selection, user config and artifact trust prompts.
