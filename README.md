# World Is Agent Adapters

Official game adapters for World Is Agent (WIA). Each adapter translates game events, observations, and capabilities into the WIA Protocol and executes game actions on the game's main thread.

| Game | Directory | Build requirements | Transport |
| --- | --- | --- | --- |
| Stardew Valley | [stardew-valley](stardew-valley/README.md) | .NET SDK, game and SMAPI references, pinned Protocol sources | net6.0, Grpc.Net.Client |
| RimWorld | [rimworld](rimworld/README.md) | .NET SDK, pinned NuGet reference assemblies, pinned Protocol sources | net472, Grpc.Core, Windows x64 native library |

The `world-is-agent` repository owns the Runtime, browser console, Protocol, Game Profiles, prompts, and definitions. This repository owns the adapters, their game assets, tests, and build, install, and packaging scripts. Each game directory works independently with its declared dependencies; it does not require the other game or repository-root scripts.

## Run

1. Build and install the desired adapter using its game guide.
2. Start the WIA Runtime and choose the matching game in the console. Configure a model if required and wait for **Ready**.
3. Start the game with its adapter enabled and load a save.

The default Runtime endpoint is `127.0.0.1:50051`. The console does not configure game installation paths. One Runtime process serves one selected Game Profile; choosing another game takes effect after restarting the Runtime. An adapter for another game is rejected with `game_mismatch`.

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

Final Stardew and RimWorld acceptance is shared with Phase10.4: connect, complete dialogue, switch in both directions after restart, and reject a mismatched game. GitHub repository publication, tags, and release uploads are owner actions.

## License And Provenance

[MIT License](LICENSE). Each game directory includes a copy for independent distribution. Source migration provenance is recorded in [docs/migration.md](docs/migration.md).
