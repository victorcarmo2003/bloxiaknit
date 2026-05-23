param(
	[Parameter(ValueFromRemainingArguments = $true)]
	[string[]] $CliArgs
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$BloxiaDir = Join-Path $ProjectRoot ".bloxia"
$ConfigPath = Join-Path $ProjectRoot "bloxia.config.json"

$script:ValidationErrors = New-Object System.Collections.Generic.List[string]
$script:ValidationWarnings = New-Object System.Collections.Generic.List[string]

function Write-Info($Message) {
	Write-Host "[BLOXIA] $Message"
}

function Write-Good($Message) {
	Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-WarnLine($Message) {
	Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-ErrorLine($Message) {
	Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Get-Config {
	if (-not (Test-Path -LiteralPath $ConfigPath)) {
		throw "Missing bloxia.config.json"
	}

	return Get-Content -Raw -LiteralPath $ConfigPath | ConvertFrom-Json
}

function Join-ProjectPath($RelativePath) {
	return Join-Path $ProjectRoot ($RelativePath -replace "/", "\")
}

function Get-ProjectRelativePath($FullPath) {
	$resolved = (Resolve-Path -LiteralPath $FullPath).Path
	$root = (Resolve-Path -LiteralPath $ProjectRoot).Path.TrimEnd("\")

	if ($resolved.StartsWith($root)) {
		return $resolved.Substring($root.Length + 1).Replace("\", "/")
	}

	return $resolved
}

function Test-PathUnderRoot($FullPath, $RootPath) {
	if (-not (Test-Path -LiteralPath $RootPath)) {
		return $false
	}

	$resolvedRoot = (Resolve-Path -LiteralPath $RootPath).Path.TrimEnd("\")
	return $FullPath.StartsWith($resolvedRoot)
}

function Add-ValidationError($Message) {
	$script:ValidationErrors.Add($Message) | Out-Null
}

function Add-ValidationWarning($Message) {
	$script:ValidationWarnings.Add($Message) | Out-Null
}

function Get-BloxiaModuleInfo($Text, $RelativePath) {
	$definitionMatch = [Regex]::Match($Text, 'Bloxia\.(Service|Controller|Component|System)\s*\(\s*\{')
	if (-not $definitionMatch.Success) {
		return $null
	}

	$nameMatch = [Regex]::Match($Text, 'Name\s*=\s*["'']([^"'']+)["'']')
	if (-not $nameMatch.Success) {
		Add-ValidationError "$RelativePath defines a Bloxia module without a Name"
		return $null
	}

	$dependsOn = New-Object System.Collections.Generic.List[string]
	$dependsMatch = [Regex]::Match($Text, 'DependsOn\s*=\s*\{([\s\S]*?)\}')
	if ($dependsMatch.Success) {
		foreach ($dependencyMatch in [Regex]::Matches($dependsMatch.Groups[1].Value, '["'']([^"'']+)["'']')) {
			$dependsOn.Add($dependencyMatch.Groups[1].Value) | Out-Null
		}
	}

	$realm = "shared"
	if ($RelativePath -like "src/server/*") {
		$realm = "server"
	} elseif ($RelativePath -like "src/client/*") {
		$realm = "client"
	}

	return [PSCustomObject]@{
		Name = $nameMatch.Groups[1].Value
		Kind = $definitionMatch.Groups[1].Value
		Realm = $realm
		Path = $RelativePath
		DependsOn = @($dependsOn)
	}
}

function Test-DependencyAllowed($Module, $Dependency) {
	if ($Module.Kind -eq "Service") {
		return $Dependency.Kind -eq "Service" -and $Dependency.Realm -eq "server"
	}

	if ($Module.Kind -eq "Controller") {
		return $Dependency.Kind -eq "Controller" -and $Dependency.Realm -eq "client"
	}

	if ($Module.Kind -eq "Component") {
		if ($Module.Realm -eq "server") {
			return $Dependency.Kind -eq "Service" -and $Dependency.Realm -eq "server"
		}

		if ($Module.Realm -eq "client") {
			return $Dependency.Kind -eq "Controller" -and $Dependency.Realm -eq "client"
		}
	}

	if ($Module.Kind -eq "System") {
		if ($Module.Realm -eq "server") {
			return $Dependency.Kind -eq "Service" -and $Dependency.Realm -eq "server"
		}

		if ($Module.Realm -eq "client") {
			return $Dependency.Kind -eq "Controller" -and $Dependency.Realm -eq "client"
		}
	}

	return $false
}

function Get-RealmFlag($Options, $DefaultRealm) {
	if ($Options -contains "--server") {
		return "server"
	}

	if ($Options -contains "--client") {
		return "client"
	}

	return $DefaultRealm
}

function Test-JsonFile($RelativePath) {
	$path = Join-ProjectPath $RelativePath

	if (-not (Test-Path -LiteralPath $path)) {
		Add-ValidationError "Missing $RelativePath"
		return
	}

	try {
		Get-Content -Raw -LiteralPath $path | ConvertFrom-Json | Out-Null
		Write-Good "$RelativePath parses"
	} catch {
		Add-ValidationError "$RelativePath is invalid JSON: $($_.Exception.Message)"
	}
}

function Test-RojoProject {
	$rojo = Get-Command rojo -ErrorAction SilentlyContinue

	if ($null -eq $rojo) {
		Add-ValidationWarning "rojo is not available on PATH; skipped sourcemap validation"
		return
	}

	Push-Location $ProjectRoot
	try {
		& rojo sourcemap default.project.json | Out-Null

		if ($LASTEXITCODE -eq 0) {
			Write-Good "Rojo sourcemap validates"
		} else {
			Add-ValidationError "rojo sourcemap failed"
		}
	} finally {
		Pop-Location
	}
}

function Get-SourceFiles {
	Get-ChildItem -LiteralPath (Join-Path $ProjectRoot "src") -Recurse -Include *.lua,*.luau -File
}

function Test-NetworkRules {
	$config = Get-Config
	$servicesRoot = Join-ProjectPath $config.paths.services
	$controllersRoot = Join-ProjectPath $config.paths.controllers
	$netSchemaRoot = Join-ProjectPath $config.paths.netSchemas
	$serverComponentsRoot = Join-ProjectPath $config.paths.serverComponents
	$clientComponentsRoot = Join-ProjectPath $config.paths.clientComponents
	$serverSystemsRoot = Join-ProjectPath $config.paths.serverSystems
	$clientSystemsRoot = Join-ProjectPath $config.paths.clientSystems
	$ecsComponentsRoot = Join-ProjectPath $config.paths.ecsComponents
	$registryPath = Join-Path $ProjectRoot "src/shared/Bloxia/Net/Registry.luau"
	$registryText = if (Test-Path -LiteralPath $registryPath) { Get-Content -Raw -LiteralPath $registryPath } else { "" }
	$ecsRegistryPath = Join-Path $ProjectRoot "src/shared/Bloxia/ECS/Registry.luau"
	$ecsRegistryText = if (Test-Path -LiteralPath $ecsRegistryPath) { Get-Content -Raw -LiteralPath $ecsRegistryPath } else { "" }
	$moduleInfos = New-Object System.Collections.Generic.List[object]
	$moduleByName = @{}
	$sourceFiles = @(Get-SourceFiles)

	foreach ($file in $sourceFiles) {
		$relative = Get-ProjectRelativePath $file.FullName
		$text = Get-Content -Raw -LiteralPath $file.FullName
		$isNetSchema = Test-PathUnderRoot $file.FullName $netSchemaRoot
		$isServicePath = Test-PathUnderRoot $file.FullName $servicesRoot
		$isControllerPath = Test-PathUnderRoot $file.FullName $controllersRoot
		$isComponentPath = (Test-PathUnderRoot $file.FullName $serverComponentsRoot) -or (Test-PathUnderRoot $file.FullName $clientComponentsRoot)
		$isSystemPath = (Test-PathUnderRoot $file.FullName $serverSystemsRoot) -or (Test-PathUnderRoot $file.FullName $clientSystemsRoot)
		$isEcsComponentPath = Test-PathUnderRoot $file.FullName $ecsComponentsRoot
		$isEcsRuntimePath = Test-PathUnderRoot $file.FullName (Join-ProjectPath "src/shared/Bloxia/ECS")

		if ($text -match 'Instance\.new\(\s*["''](?:RemoteEvent|RemoteFunction|UnreliableRemoteEvent)["'']') {
			Add-ValidationError "$relative creates a gameplay remote directly; use Lync NetSchemas"
		}

		if ($text -match 'function\s+\w+\.Client:|function\s+\w+\.Client\.') {
			Add-ValidationError "$relative defines legacy Service.Client networking; use Lync NetSchemas instead"
		}

		if (-not $isNetSchema -and $text -match '\bLync\.(packet|query|group)\s*\(') {
			Add-ValidationError "$relative defines Lync contracts outside Net/Schemas"
		}

		if ($text -match 'Packages\.Knit|\bKnit\.') {
			Add-ValidationError "$relative uses Knit directly; Bloxia.Framework is now the runtime"
		}

		if (-not $isEcsRuntimePath -and $text -match 'Packages\.jecs') {
			Add-ValidationError "$relative requires jecs directly; use Bloxia.ECS instead"
		}

		if (-not $isComponentPath -and $text -match 'Bloxia\.Component\s*\(') {
			Add-ValidationError "$relative defines a Bloxia component outside src/server/Components or src/client/Components"
		}

		if (-not $isServicePath -and $text -match 'Bloxia\.Service\s*\(') {
			Add-ValidationError "$relative defines a Bloxia service outside src/server/Services"
		}

		if (-not $isControllerPath -and $text -match 'Bloxia\.Controller\s*\(') {
			Add-ValidationError "$relative defines a Bloxia controller outside src/client/Controllers"
		}

		if (-not $isSystemPath -and $text -match 'Bloxia\.System\s*\(') {
			Add-ValidationError "$relative defines a Bloxia system outside src/server/Systems or src/client/Systems"
		}

		if (-not $isEcsComponentPath -and $text -match 'Bloxia\.ECS\.(component|tag)\s*\(') {
			Add-ValidationError "$relative defines ECS component IDs outside src/shared/Bloxia/ECS/Components"
		}

		if ($relative -like "src/client/*" -and $text -match 'ProfileStore|DataStoreService') {
			Add-ValidationError "$relative references persistence from client code"
		}

		$moduleInfo = Get-BloxiaModuleInfo $text $relative
		if ($null -ne $moduleInfo) {
			$moduleInfos.Add($moduleInfo) | Out-Null

			if ($moduleByName.ContainsKey($moduleInfo.Name)) {
				Add-ValidationError "$relative duplicates Bloxia module name '$($moduleInfo.Name)' already used by $($moduleByName[$moduleInfo.Name].Path)"
			} else {
				$moduleByName[$moduleInfo.Name] = $moduleInfo
			}
		}
	}

	foreach ($moduleInfo in $moduleInfos) {
		foreach ($dependencyName in $moduleInfo.DependsOn) {
			if (-not $moduleByName.ContainsKey($dependencyName)) {
				Add-ValidationError "$($moduleInfo.Path) depends on missing Bloxia module '$dependencyName'"
				continue
			}

			$dependency = $moduleByName[$dependencyName]
			if (-not (Test-DependencyAllowed $moduleInfo $dependency)) {
				Add-ValidationError "$($moduleInfo.Path) has invalid DependsOn '$dependencyName' ($($dependency.Kind)/$($dependency.Realm)); keep dependencies inside the correct layer"
			}
		}
	}

	if (-not (Test-Path -LiteralPath $registryPath)) {
		Add-ValidationError "Missing src/shared/Bloxia/Net/Registry.luau"
		return
	}

	foreach ($schema in Get-ChildItem -LiteralPath $netSchemaRoot -Filter *.luau -File) {
		$name = [System.IO.Path]::GetFileNameWithoutExtension($schema.Name)

		if ($registryText -notmatch [Regex]::Escape("Schemas.$name")) {
			Add-ValidationError "$($schema.Name) exists but is not registered in Net/Registry.luau"
		}
	}

	if (-not (Test-Path -LiteralPath $ecsRegistryPath)) {
		Add-ValidationError "Missing src/shared/Bloxia/ECS/Registry.luau"
		return
	}

	if (Test-Path -LiteralPath $ecsComponentsRoot) {
		foreach ($component in Get-ChildItem -LiteralPath $ecsComponentsRoot -Filter *.luau -File) {
			$name = [System.IO.Path]::GetFileNameWithoutExtension($component.Name)

			if ($ecsRegistryText -notmatch [Regex]::Escape("Components.$name")) {
				Add-ValidationError "$($component.Name) exists but is not registered in Bloxia/ECS/Registry.luau"
			}
		}
	}
}

function Invoke-Validate {
	Write-Info "Validating BLOXIA project"

	Test-JsonFile "metadata.json"
	Test-JsonFile "bloxia.config.json"
	Test-RojoProject
	Test-NetworkRules

	foreach ($warning in $script:ValidationWarnings) {
		Write-WarnLine $warning
	}

	foreach ($errorMessage in $script:ValidationErrors) {
		Write-ErrorLine $errorMessage
	}

	if ($script:ValidationErrors.Count -gt 0) {
		Write-ErrorLine "Validation failed with $($script:ValidationErrors.Count) error(s)"
		exit 1
	}

	Write-Good "Validation passed"
}

function Normalize-ModuleName($Name, $Suffix) {
	if ([string]::IsNullOrWhiteSpace($Name)) {
		throw "Missing module name"
	}

	$clean = ($Name -replace "[^A-Za-z0-9_]", "")

	if ([string]::IsNullOrWhiteSpace($clean)) {
		throw "Module name must contain letters or numbers"
	}

	if ($clean.EndsWith($Suffix)) {
		return $clean.Substring(0, $clean.Length - $Suffix.Length)
	}

	return $clean
}

function New-FromTemplate($TemplateName, $TargetPath, $Name) {
	$templatePath = Join-Path $BloxiaDir "templates/$TemplateName"

	if (-not (Test-Path -LiteralPath $templatePath)) {
		throw "Missing template $TemplateName"
	}

	if (Test-Path -LiteralPath $TargetPath) {
		throw "Target already exists: $(Get-ProjectRelativePath $TargetPath)"
	}

	$parent = Split-Path -Parent $TargetPath
	New-Item -ItemType Directory -Force -Path $parent | Out-Null

	$content = Get-Content -Raw -LiteralPath $templatePath
	$content = $content.Replace("__NAME__", $Name)
	Set-Content -LiteralPath $TargetPath -Value $content -NoNewline

	Write-Good "Created $(Get-ProjectRelativePath $TargetPath)"
}

function Register-NetSchema($SchemaName) {
	$registryPath = Join-Path $ProjectRoot "src/shared/Bloxia/Net/Registry.luau"
	$text = Get-Content -Raw -LiteralPath $registryPath
	$needle = "Schemas.$SchemaName"

	if ($text.Contains($needle)) {
		return
	}

	$lines = New-Object System.Collections.Generic.List[string]
	(Get-Content -LiteralPath $registryPath) | ForEach-Object { $lines.Add($_) | Out-Null }

	$insertAt = -1
	for ($i = 0; $i -lt $lines.Count; $i++) {
		if ($lines[$i].Trim() -eq "}") {
			$insertAt = $i
			break
		}
	}

	if ($insertAt -lt 0) {
		throw "Could not locate orderedSchemas close brace in Registry.luau"
	}

	$lines.Insert($insertAt, "`trequire(script.Parent.Schemas.$SchemaName),")
	Set-Content -LiteralPath $registryPath -Value $lines

	Write-Good "Registered $SchemaName in Net/Registry.luau"
}

function Register-EcsComponent($ComponentName) {
	$registryPath = Join-Path $ProjectRoot "src/shared/Bloxia/ECS/Registry.luau"
	$text = Get-Content -Raw -LiteralPath $registryPath
	$needle = "Components.$ComponentName"

	if ($text.Contains($needle)) {
		return
	}

	$lines = New-Object System.Collections.Generic.List[string]
	(Get-Content -LiteralPath $registryPath) | ForEach-Object { $lines.Add($_) | Out-Null }

	$insertAt = -1
	for ($i = 0; $i -lt $lines.Count; $i++) {
		if ($lines[$i].Trim() -eq "}") {
			$insertAt = $i
			break
		}
	}

	if ($insertAt -lt 0) {
		throw "Could not locate orderedComponents close brace in ECS/Registry.luau"
	}

	$lines.Insert($insertAt, "`trequire(script.Components.$ComponentName),")
	Set-Content -LiteralPath $registryPath -Value $lines

	Write-Good "Registered $ComponentName in Bloxia/ECS/Registry.luau"
}

function Invoke-Make($Kind, $Name, $Options) {
	$config = Get-Config

	switch ($Kind) {
		"service" {
			$base = Normalize-ModuleName $Name "Service"
			New-FromTemplate "Service.luau" (Join-ProjectPath "$($config.paths.services)/${base}Service.luau") $base
		}
		"controller" {
			$base = Normalize-ModuleName $Name "Controller"
			New-FromTemplate "Controller.luau" (Join-ProjectPath "$($config.paths.controllers)/${base}Controller.luau") $base
		}
		"net" {
			$base = Normalize-ModuleName $Name "Net"
			$schemaName = "${base}Net"
			New-FromTemplate "NetSchema.luau" (Join-ProjectPath "$($config.paths.netSchemas)/$schemaName.luau") $base
			Register-NetSchema $schemaName
		}
		"ecs" {
			$base = Normalize-ModuleName $Name ""
			New-FromTemplate "ECSComponent.luau" (Join-ProjectPath "$($config.paths.ecsComponents)/$base.luau") $base
			Register-EcsComponent $base
		}
		"ui" {
			$base = Normalize-ModuleName $Name ""
			New-FromTemplate "UIComponent.luau" (Join-ProjectPath "$($config.paths.ui)/Components/$base.luau") $base
		}
		"component" {
			$base = Normalize-ModuleName $Name "Component"
			$realm = Get-RealmFlag $Options "client"
			$targetRoot = if ($realm -eq "server") { $config.paths.serverComponents } else { $config.paths.clientComponents }
			New-FromTemplate "Component.luau" (Join-ProjectPath "$targetRoot/${base}Component.luau") $base
		}
		"system" {
			$base = Normalize-ModuleName $Name "System"
			$realm = Get-RealmFlag $Options "server"
			$targetRoot = if ($realm -eq "client") { $config.paths.clientSystems } else { $config.paths.serverSystems }
			New-FromTemplate "System.luau" (Join-ProjectPath "$targetRoot/${base}System.luau") $base
		}
		"data" {
			$base = Normalize-ModuleName $Name "Data"
			New-FromTemplate "DataModule.luau" (Join-ProjectPath "$($config.paths.data)/${base}Data.luau") $base
		}
		default {
			throw "Unknown make kind '$Kind'. Use service, controller, net, ecs, component, system, ui or data."
		}
	}
}

function Get-RegistryAuth {
	$config = Get-Config
	$urlEnv = $config.cloudRegistry.urlEnv
	$keyEnv = $config.cloudRegistry.anonKeyEnv
	$url = [Environment]::GetEnvironmentVariable($urlEnv)
	$key = [Environment]::GetEnvironmentVariable($keyEnv)

	if ([string]::IsNullOrWhiteSpace($url) -or [string]::IsNullOrWhiteSpace($key)) {
		throw "Missing registry env vars $urlEnv and/or $keyEnv"
	}

	return @{
		Url = $url.TrimEnd("/")
		Key = $key
	}
}

function Invoke-CloudSearch($Query) {
	if ([string]::IsNullOrWhiteSpace($Query)) {
		throw "Missing search query"
	}

	$auth = Get-RegistryAuth
	$escaped = [Uri]::EscapeDataString($Query)
	$endpoint = "$($auth.Url)/rest/v1/libraries?select=id,name,summary,tags,review_status&or=(name.ilike.*$escaped*,summary.ilike.*$escaped*)"
	$headers = @{
		apikey = $auth.Key
		Authorization = "Bearer $($auth.Key)"
	}

	Invoke-RestMethod -Method Get -Uri $endpoint -Headers $headers | ConvertTo-Json -Depth 10
}

function Invoke-CloudInstall($LibraryId, [bool] $DryRun) {
	if ([string]::IsNullOrWhiteSpace($LibraryId)) {
		throw "Missing library id"
	}

	$auth = Get-RegistryAuth
	$escaped = [Uri]::EscapeDataString($LibraryId)
	$endpoint = "$($auth.Url)/rest/v1/library_versions?select=*,libraries(id,name)&library_id=eq.$escaped&order=created_at.desc&limit=1"
	$headers = @{
		apikey = $auth.Key
		Authorization = "Bearer $($auth.Key)"
	}

	$result = Invoke-RestMethod -Method Get -Uri $endpoint -Headers $headers

	if ($DryRun) {
		$result | ConvertTo-Json -Depth 20
		return
	}

	Write-WarnLine "Cloud install fetched metadata only. Native IDE installer should verify artifacts, ask for config, write files, then run tools/bloxia.ps1 validate."
	$result | ConvertTo-Json -Depth 20
}

function Show-Help {
	Write-Host @"
BLOXIA CLI

Usage:
  tools/bloxia.ps1 validate
  tools/bloxia.ps1 make service Inventory
  tools/bloxia.ps1 make controller Inventory
  tools/bloxia.ps1 make net Inventory
  tools/bloxia.ps1 make ecs Health
  tools/bloxia.ps1 make component Door --client
  tools/bloxia.ps1 make component Pickup --server
  tools/bloxia.ps1 make system Movement --server
  tools/bloxia.ps1 make system CameraSway --client
  tools/bloxia.ps1 make ui InventoryPanel
  tools/bloxia.ps1 make data Inventory
  tools/bloxia.ps1 cloud search "flight system"
  tools/bloxia.ps1 cloud install bloxia.flight.basic --dry-run

Cloud commands use BLOXIA_SUPABASE_URL and BLOXIA_SUPABASE_ANON_KEY by default.
"@
}

if ($CliArgs.Count -eq 0) {
	Show-Help
	exit 0
}

$command = $CliArgs[0].ToLowerInvariant()

try {
	switch ($command) {
		"validate" {
			Invoke-Validate
		}
		"make" {
			if ($CliArgs.Count -lt 3) {
				throw "Usage: tools/bloxia.ps1 make <service|controller|net|ecs|component|system|ui|data> <Name>"
			}
			$options = if ($CliArgs.Count -gt 3) { $CliArgs[3..($CliArgs.Count - 1)] } else { @() }
			Invoke-Make $CliArgs[1].ToLowerInvariant() $CliArgs[2] $options
		}
		"cloud" {
			if ($CliArgs.Count -lt 3) {
				throw "Usage: tools/bloxia.ps1 cloud <search|install> <query|id>"
			}

			$cloudCommand = $CliArgs[1].ToLowerInvariant()
			if ($cloudCommand -eq "search") {
				Invoke-CloudSearch $CliArgs[2]
			} elseif ($cloudCommand -eq "install") {
				$dryRun = $CliArgs -contains "--dry-run"
				Invoke-CloudInstall $CliArgs[2] $dryRun
			} else {
				throw "Unknown cloud command '$cloudCommand'"
			}
		}
		"help" {
			Show-Help
		}
		default {
			throw "Unknown command '$command'"
		}
	}
} catch {
	Write-ErrorLine $_.Exception.Message
	exit 1
}
