# World Is Agent Adapters

本仓库包含 **World Is Agent（WIA）** 的官方游戏 Adapter。每个 Adapter 负责把游戏事件、环境观察和能力转换为 WIA Protocol，并在游戏主线程执行 Runtime 返回的游戏动作。

| 游戏 | 目录 | 构建要求 | 通信方式 |
| --- | --- | --- | --- |
| Stardew Valley | [stardew-valley](stardew-valley/README.md) | .NET SDK、游戏与 SMAPI 引用、固定版本的 Protocol 源码 | net6.0、Grpc.Net.Client |
| RimWorld | [rimworld](rimworld/README.md) | .NET SDK、固定版本的 NuGet 引用程序集和 Protocol 源码 | net472、Grpc.Core、Windows x64 原生库 |

[world-is-agent](https://github.com/zlci7/world-is-agent) 仓库负责 Runtime、Web 控制台、Protocol、Game Profile、Prompt 和 Definitions；本仓库负责 Adapter、游戏资产、测试以及构建、安装和打包脚本。每个游戏目录都可以根据自身声明的依赖独立工作，不依赖另一个游戏，也不依赖仓库根目录的辅助脚本。

## 运行方式

1. 按照对应游戏目录中的说明构建并安装 Adapter。
2. 启动 WIA Runtime，在 Web 控制台中选择对应游戏；根据需要配置模型，并等待状态变为 **Ready**。
3. 启用 Adapter 后启动游戏并加载存档。

Runtime 默认监听 `127.0.0.1:50051`。Web 控制台不配置游戏安装目录；游戏路径只在构建和安装 Adapter 时使用。

Runtime 0.2.0 同一时间加载一个 Game Profile。**Switch game（切换游戏）** 会在当前进程中应用新的选择，取消正在执行的回合并保留已有历史记录。**Model settings（模型设置）** 可以修改服务商、模型、API Key 和可选的 Base URL。其它游戏的 Adapter 会收到 `game_mismatch`；Stardew Adapter 0.1.1 和 RimWorld Adapter 0.1.0 会持续重试，直到 Runtime 选择了对应游戏。

## 版本与协议

每个游戏分别维护自己的 `VERSION` 和 `protocol.version`：

- `VERSION` 决定程序集信息版本、Hello 上报版本，以及适用的 Mod Manifest 版本。
- `protocol.version` 指定已经验证的 Protocol tag；构建和打包时必须显式提供对应的 Protocol 目录。

| 游戏 | Release tag | 压缩包 |
| --- | --- | --- |
| Stardew Valley | `stardew-valley-v<version>` | `wia-adapter-stardew-valley-v<version>.zip` |
| RimWorld | `rimworld-v<version>` | `wia-adapter-rimworld-v<version>.zip` |

发布某个游戏的 tag 不会同时发布另一个游戏。发布包会记录 Adapter 版本、源码 commit、Protocol pin 和实际解析出的 Protocol commit。游戏程序集、凭据、本地配置和构建缓存不会进入 Git 仓库。

## 构建与验证

每个游戏目录都提供独立的构建、测试、安装和打包入口。仓库根目录的可选检查用于确认 Adapter 源码没有依赖 Runtime 内部实现：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/check-architecture.ps1
```

具体命令和游戏依赖参见：

- [Stardew Valley Adapter](stardew-valley/README.md)
- [RimWorld Adapter](rimworld/README.md)

## 当前状态

Stardew Valley 与 RimWorld 的基础实机闭环已经通过。正式发布前仍需使用 Runtime 0.2.0 和 Stardew Adapter 0.1.1 完成一次聚焦实机验收：在回合执行期间切换游戏、确认历史记录保留、切回 Stardew Valley 并在自动重连后完成对话，然后修改模型并再次完成对话。当前构建为本地验收产物，tag 和 GitHub Release 在验收通过后创建。

## 许可证与代码来源

本项目使用 [MIT License](LICENSE)。每个游戏目录都包含一份许可证，便于独立分发。源码迁移记录参见 [docs/migration.md](docs/migration.md)。
