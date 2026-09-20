# Source Provenance

The official adapters originate from `world-is-agent` commit `19545e4934c680b1ac8bf393414e4cab8a07f201`.

| Source path | Adapter repository path |
| --- | --- |
| `adapters/stardew/` | `stardew-valley/` |
| `adapters/rimworld/` | `rimworld/` |
| `scripts/install-stardew-adapter.ps1` | `stardew-valley/scripts/install-stardew-adapter.ps1` |
| `scripts/install-rimworld-adapter.ps1` | `rimworld/scripts/install-rimworld-adapter.ps1` |
| `LICENSE` | `LICENSE`, `stardew-valley/LICENSE`, `rimworld/LICENSE` |

The source repository retains its Git history. This repository starts an independent history with the imported source and self-contained build, test, installation, and packaging entry points. The migration preserves Mod identifiers, namespaces, assembly names, installation directories, and Protocol contents.

Runtime-owned Game Profiles remain in `world-is-agent/runtime/config/games/`. Each Adapter records its tested Protocol tag in `protocol.version`; the migration baseline is `protocol-v1alpha2.0`, resolved to `950d417fcc64517d8d59c334a4cf96ec224bd61a` in the source repository.
