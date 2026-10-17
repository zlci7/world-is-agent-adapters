# Stardew Valley Adapter

This directory contains the World Is Agent SMAPI adapter for Stardew Valley. It owns the Stardew-specific observation, capability, UI, action, installation, and package implementation. Runtime profiles and Protocol definitions remain in the `world-is-agent` repository.

The adapter version is read from `VERSION`. Its tested Protocol release is read from `protocol.version`. The current release contract is:

```text
Adapter version: 0.1.2
Protocol tag:    protocol-v1alpha2.0
Release tag:     stardew-valley-v0.1.2
Package:         wia-adapter-stardew-valley-v0.1.2.zip
```

The build requires three explicit dependencies:

- `GamePath`: a Stardew Valley installation containing the game and SMAPI build assemblies.
- `ProtocolRepository`: a Git checkout that can resolve the tag in `protocol.version`.
- `ProtocolDir`: an exported Protocol directory whose `proto` files exactly match that tag.

No script searches parent or sibling directories for these dependencies.

## Context and native quests

The 0.1.2 source build adds exact relationship status, bounded world progress and selected current-NPC event flags. Missing facts remain unknown. Held-item interactions and native quest reporting pass through to the game; ordinary conversation uses WIA. Dwarf dialogue keeps the game's language prerequisite.

The single-player objective pilot reads one accepted native Willy fishing quest. Its instance reference and last observed result are stored in the game save through quest/player `modData`. Completion requires the native `completed` flag; disappearance is reported as unavailable, and reward collection is not inferred. Only Willy receives this objective context. General fish conditions come from `Data/Fish` and do not prove that a specific location can spawn that fish.

This pilot does not create quests, change native requirements or issue rewards. Background native-API probes and unit tests are separate from live-game acceptance. Validate gifting, item delivery, fishing reporting, save/load, Runtime restart and rollback on a disposable save before using it as an accepted gameplay feature. Unavailable Runtime connections leave native interactions available.

## Get the pinned Protocol

Use a Protocol source checkout that contains the tag named by this directory's `protocol.version`. A fresh checkout can be obtained from `https://github.com/zlci7/world-is-agent.git`; tag publication is handled by the repository owner. Export the pinned files rather than using an arbitrary checkout's current Protocol:

```powershell
$adapter = 'D:\src\world-is-agent-adapters\stardew-valley'
$protocolRepository = 'D:\src\world-is-agent'
$pin = (Get-Content -Raw -LiteralPath "$adapter\protocol.version").Trim()
git -C $protocolRepository rev-parse --verify "refs/tags/$pin^{commit}"
$exportRoot = Join-Path $env:TEMP ('wia-protocol-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $exportRoot | Out-Null
$archive = Join-Path $exportRoot 'protocol.zip'
git -C $protocolRepository archive --format=zip --output=$archive "refs/tags/$pin" protocol
Expand-Archive -LiteralPath $archive -DestinationPath $exportRoot
$protocol = Join-Path $exportRoot 'protocol'
```

The tag must resolve before building. If it is absent, obtain the pinned tag from the repository owner. Use the exported `$protocol` path with the commands below.

## Build and test

Run the entry points from any working directory:

```powershell
$adapter = "D:\src\world-is-agent-adapters\stardew-valley"
$game = "D:\SteamLibrary\steamapps\common\Stardew Valley"
$protocolRepository = "D:\src\world-is-agent"

& "$adapter\scripts\build-adapter.ps1" `
  -GamePath $game `
  -ProtocolRepository $protocolRepository `
  -ProtocolDir $protocol

& "$adapter\scripts\test-adapter.ps1" `
  -GamePath $game `
  -ProtocolRepository $protocolRepository `
  -ProtocolDir $protocol
```

The standalone probe copies this game directory and the Protocol export to a temporary location, then exercises build, tests, packaging, temporary installation, dependency failures, content mismatch, tag mismatch, and a temporary adapter version bump:

```powershell
& "$adapter\tests\check-standalone-build.ps1" `
  -GamePath $game `
  -ProtocolRepository $protocolRepository `
  -ProtocolDir $protocol `
  -SourceCommit <full-adapter-repository-commit>
```

## Install

Install only while Stardew Valley and SMAPI are closed. The default target is `$game\Mods\GameAgentStardew`; tests should pass an isolated `-ModsPath`.

```powershell
& "$adapter\scripts\install-stardew-adapter.ps1" `
  -GamePath $game `
  -ProtocolRepository $protocolRepository `
  -ProtocolDir $protocol
```

## Package

Create a release archive after the adapter repository has a commit. For an exported source snapshot, pass the full commit from which that snapshot was produced through `-SourceCommit`.

```powershell
& "$adapter\scripts\release-adapter.ps1" `
  -GamePath $game `
  -ProtocolRepository $protocolRepository `
  -ProtocolDir $protocol `
  -ReleaseTag stardew-valley-v0.1.1 `
  -SourceCommit <full-adapter-repository-commit>
```

The archive contains the SMAPI mod directory, runtime dependencies, assets, license, and `provenance.json`. The provenance file records the source commit, adapter version, Protocol pin, resolved Protocol commit, and successful content verification. Game assemblies, build caches, credentials, and machine configuration are excluded.

## Runtime smoke test

Start a WIA Runtime configured for Stardew Valley and wait for it to become Ready. Launch Stardew through SMAPI, load a save, and confirm the log reports the Runtime connection and `CapabilityList sent`. Interacting with an NPC should then produce `GameEvent`, `EventAck`, `Observation`, `ActionRequest`, `ActionResult`, and `TurnCompletion` messages.

If the Runtime is unavailable, reconfiguring, or configured for another game, the adapter clears stale action and dialogue state and retries the connection after a bounded delay. Each retry performs a fresh Hello, capability discovery, and world binding. Once the Runtime is Ready for Stardew Valley, the adapter reconnects without restarting the game. The `gameagent_runtime_reconnect` command remains available for an immediate manual reconnect.
