# World Is Agent RimWorld Adapter

This directory contains the official RimWorld adapter for World Is Agent. It connects RimWorld 1.6 to a local WIA Runtime, projects eligible colonists as entities, and presents Runtime dialogue through the existing RimWorld UI integration.

The adapter version is recorded in `VERSION`. Its tested Protocol release is recorded in `protocol.version`. Version `0.1.0` is tested against `protocol-v1alpha2.0` and RimWorld `1.6.4871` on Windows x64.

The build targets .NET Framework 4.7.2 and uses `Grpc.Core`. RimWorld reference assemblies come from the pinned `Krafs.Rimworld.Ref` package, so building and testing do not require a game installation. The Protocol source and its Git repository are explicit inputs; the scripts verify every Protocol `.proto` file against the pinned tag before building.

## Get the pinned Protocol

Use a source checkout of `https://github.com/zlci7/world-is-agent.git` that contains the tag named by this directory's `protocol.version`. Tag publication is handled by the repository owner. Export the pinned files with:

```powershell
$adapter = 'C:\src\world-is-agent-adapters\rimworld'
$protocolRepository = 'C:\src\world-is-agent'
$pin = (Get-Content -Raw -LiteralPath "$adapter\protocol.version").Trim()
git -C $protocolRepository rev-parse --verify "refs/tags/$pin^{commit}"
$exportRoot = Join-Path $env:TEMP ('wia-protocol-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $exportRoot | Out-Null
$archive = Join-Path $exportRoot 'protocol.zip'
git -C $protocolRepository archive --format=zip --output=$archive "refs/tags/$pin" protocol
Expand-Archive -LiteralPath $archive -DestinationPath $exportRoot
$protocolDir = Join-Path $exportRoot 'protocol'
```

If the tag is absent, obtain it from the repository owner before building. Run the following commands from this game directory using the exported `$protocolDir`.

```powershell
./scripts/build-adapter.ps1 `
  -ProtocolDir $protocolDir `
  -ProtocolRepository C:\src\world-is-agent

./scripts/test-adapter.ps1 `
  -ProtocolDir $protocolDir `
  -ProtocolRepository C:\src\world-is-agent
```

`WIA_PROTOCOL_DIR` and `WIA_PROTOCOL_REPOSITORY` provide the same inputs through environment variables. The project has no parent-directory or sibling-repository fallback.

Run the standalone verification from any working directory. It copies this game directory and the Protocol export to private temporary locations, then runs the build, tests, release packaging, temporary installation, and negative dependency/version probes.

```powershell
./tests/check-standalone-build.ps1 `
  -ProtocolDir $protocolDir `
  -ProtocolRepository C:\src\world-is-agent `
  -SourceCommit <adapter-repository-commit>
```

Create a release archive after committing the adapter repository:

```powershell
./scripts/release-adapter.ps1 `
  -ProtocolDir $protocolDir `
  -ProtocolRepository C:\src\world-is-agent `
  -ReleaseTag rimworld-v0.1.0
```

The archive is `artifacts/wia-adapter-rimworld-v0.1.0.zip`. It contains `About`, `Patches`, managed assemblies, the Windows x64 native gRPC library, the license, and provenance with the adapter version, source commit, Protocol pin, and resolved Protocol commit. It excludes game assemblies, source, build caches, credentials, and machine configuration.

For installation, close RimWorld and provide either an explicit game directory or Mods directory. The installer validates all managed, native, metadata, and patch inputs before changing the target, refuses to install while the game is running, and stages the native library under `Native/grpc_csharp_ext.dll`.

```powershell
./scripts/install-rimworld-adapter.ps1 `
  -GamePath "C:\Games\RimWorld" `
  -ProtocolDir $protocolDir `
  -ProtocolRepository C:\src\world-is-agent
```

The installed mod directory remains `Mods/WiaRimWorld`; its package identity, entry DLL, assembly name, namespace, patches, supported game versions, transport, and game behavior are unchanged. Start the WIA Runtime with the RimWorld game profile selected and Ready, then enable **World Is Agent (RimWorld)** in the game's mod list. The adapter reconnects to `127.0.0.1:50051` while the Runtime is unavailable.

Real-game connection, dialogue, switching, and mismatch acceptance remain manual product checks. Automated tests do not claim those results.
