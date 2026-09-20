# World Is Agent Adapters

Official game adapters for World Is Agent (WIA). Each adapter translates game events, observations, and capabilities into the WIA Protocol and executes game actions on the game's main thread.

| Game | Directory | Build requirements | Transport |
| --- | --- | --- | --- |
| Stardew Valley | [stardew-valley](stardew-valley/README.md) | .NET SDK, game and SMAPI references, pinned Protocol sources | net6.0, Grpc.Net.Client |
| RimWorld | [rimworld](rimworld/README.md) | .NET SDK, pinned NuGet reference assemblies, pinned Protocol sources | net472, Grpc.Core, Windows x64 native library |

The [world-is-agent](https://github.com/zlci7/world-is-agent) repository owns the Runtime, browser console, Protocol, Game Profiles, prompts, and definitions. This repository owns the adapters, their game assets, tests, and build, install, and packaging scripts. Each game directory works independently with its declared dependencies; it does not require the other game or repository-root scripts.

## Run

1. Build and install the desired adapter using its game guide.
2. Start the WIA Runtime and choose the matching game in the console. Configure a model if required and wait for **Ready**.
3. Start the game with its adapter enabled and load a save.

The default Runtime endpoint is `127.0.0.1:50051`. The console does not configure game installation paths. Runtime 0.2.0 serves one selected Game Profile at a time. **Switch game** applies the selection in the running process and cancels current turns while retaining recorded history. **Model settings** changes the provider, model, API key and optional base URL. An adapter for another game receives `game_mismatch`; Stardew Adapter 0.1.1 and the current RimWorld adapter retry automatically until their game is selected.

## Versions And Protocol

Each game has its own `VERSION` and `protocol.version`. `VERSION` controls its assembly informational version, Hello version, and applicable Mod manifest version. `protocol.version` names the tested Protocol tag; build and packaging instructions use explicit Protocol locations.

| Game | Release tag | Archive |
| --- | --- | --- |
| Stardew Valley | `stardew-valley-v<version>` | `wia-adapter-stardew-valley-v<version>.zip` |
| RimWorld | `rimworld-v<version>` | `wia-adapter-rimworld-v<version>.zip` |

Publishing one game's tag does not release the other game. Packages record the Adapter version, source commit, Protocol pin, and resolved Protocol commit. Game assemblies, credentials, local configuration, and build caches are excluded.

## Validation

The game guides provide independent build, test, installation, and packaging entry points. The optional repository check verifies Adapter source does not depend on Runtime internals:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/check-architecture.ps1
```

The user reported the Phase10.4/10.5 real-game baseline passed. Focused live-settings acceptance uses Runtime 0.2.0 and Stardew Adapter 0.1.1: switch games during a turn, verify history remains, switch back and complete dialogue after automatic reconnection, then change the model and complete another dialogue. These builds are local acceptance artifacts; tags and release uploads follow owner acceptance.

## License And Provenance

[MIT License](LICENSE). Each game directory includes a copy for independent distribution. Source migration provenance is recorded in [docs/migration.md](docs/migration.md).
