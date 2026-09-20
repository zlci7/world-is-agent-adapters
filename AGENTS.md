# World Is Agent Adapters

- Work directly on `main`. Make local commits only when the user has authorized them; the user handles pushes, GitHub repositories, tags, and releases.
- Use Chinese in conversation and English in public documentation.
- Each game directory owns its source, assets, dependencies, tests, build, install, and packaging scripts. Its entry points work without another game directory or repository-root helpers.
- Runtime, Console, Game Profiles, prompts, definitions, and Protocol belong to `world-is-agent`. Adapters depend on explicit versioned Protocol sources, never Runtime internals or an assumed sibling checkout.
- `VERSION` is each Adapter's version source. `protocol.version` names its tested Protocol tag. Resolve and verify pinned Protocol content for standalone and packaging validation.
- Use `<game_id>-v<version>` tags and `wia-adapter-<game_id>-v<version>.zip` archives. Assembly informational version, Hello version, and applicable Mod version must agree.
- Keep Stardew `net6.0 + Grpc.Net.Client` and RimWorld `net472 + Grpc.Core` independent. Do not introduce shared game behavior, transport, or speculative frameworks.
- Preserve Mod IDs, namespaces, assembly names, entry DLLs, install directories, game commands, and protocol contents. Game API access and actions remain on the game thread.
- Optional third-party Mods remain optional. Validate external text before passing it to game APIs.
- Preserve licenses and required third-party notices. Do not package game DLLs, caches, credentials, or machine-specific configuration.
- Verify path containment before recursive filesystem operations. Preserve unrelated files and existing projects. Tests install only into explicit temporary targets unless the user requests actual installation.
- Run focused tests and affected regressions, then `git diff --check`. Record automated and real-game validation separately; final Phase10.4/10.5 game acceptance belongs to the user.
