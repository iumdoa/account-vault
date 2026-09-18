# 开发进展记录

## 阶段 0：环境、工程和桌面可行性

- **当前阶段**：阶段 0：环境、工程和桌面可行性（已完成验收）
- **本次完成**：
  1. 搭建并验证了宿主机开发环境：Flutter 3.47.4 stable、Clang 22.1.8、GTK3、CMake、Ninja、Unzip，`flutter doctor -v` Linux toolchain 全部通过。
  2. 在 `app/` 初始化了 Flutter 原生工程 (`--platforms=linux,android --org dev.local`)。
  3. 确认并固定了 Linux `app-id` 为 `dev.local.account_vault`。
  4. 改造了 Linux C++ runner (`app/linux/runner/my_application.cc`)：
     - 实现 GApplication D-Bus 单实例机制 (`G_APPLICATION_HANDLES_COMMAND_LINE`)；
     - 实现命令行参数转发：支持 `--show`、`--hide`、`--quit`；
     - 捕获窗口关闭事件 (`delete-event`)，点击关闭按钮默认隐藏窗口而保持后台进程常驻；
     - 建立了 Flutter 与原生 GTK runner 的 `FlMethodChannel` 通信 (`dev.local.account_vault/window`)，支持 Esc 隐藏和退出；
     - 原生集成 niri IPC 聚焦：通过安全参数执行 `niri msg action focus-window --id <ID>` 确保跨工作区/跨图层准确聚焦窗口并自动聚焦 Flutter 搜索框。
  5. 实现了桌面集成与快捷键：
     - 部署启动脚本 `~/.local/bin/account-vault`；
     - 部署 Desktop 文件 `~/.local/share/applications/account-vault.desktop`；
     - 在 `~/.config/niri/config.kdl` 中配置了浮动窗口规则（`680x460` 居中）与全局快捷键 `Super+Alt+P`，经 `niri validate` 验证通过。
- **修改文件**：
  - `app/linux/runner/my_application.cc`
  - `app/lib/main.dart`
  - `app/test/widget_test.dart`
  - `packaging/account-vault.desktop`
  - `packaging/niri-bind-sample.kdl`
  - `~/.local/bin/account-vault`
  - `~/.config/niri/config.kdl`
  - `docs/environment.md`
  - `docs/progress.md`
- **实际验证命令和结果**：
  - `dart format --output=none --set-exit-if-changed lib test`: 全部格式化通过
  - `flutter analyze`: `No issues found!`
  - `flutter test`: 单元/Widget 测试全部通过
  - `flutter build linux --release`: 成功构建独立 release bundle
  - 启动运行并查询 niri 窗口属性：
    ```json
    {
      "id": 51,
      "title": "Account Vault",
      "app_id": "dev.local.account_vault",
      "is_focused": true,
      "is_floating": true,
      "layout": { "tile_size": [680.0, 460.0], "window_size": [680, 460] }
    }
    ```
  - **单实例与快速唤起测试**：连续 20 次执行 `account-vault --show`，耗时 < 1 秒，始终保持唯一进程 PID，无多实例竞争；
  - **隐藏与常驻测试**：执行 `account-vault --hide`，窗口立即从合成器解绑消失，`account_vault` 进程持续在后台运行；随后执行 `account-vault --show` 立即重新展现并恢复焦点，连续循环 20 次保持正常；
  - **优雅退出测试**：执行 `account-vault --quit`，后台进程正常接收信号干净退出，退出码为 0，无资源悬挂。
- **手工验收环境和结果**：
  - Arch Linux + niri 26.04 + Wayland 环境下，浮动窗口、尺寸约束、`Super+Alt+P` 快捷键触发均完全生效。
- **尚未验证的内容**：
  - 阶段 1：账号记录模型与纯搜索函数（包含标签、分组、分词与稳定排序）。
  - 阶段 1：快捷面板完整交互（列表上下键导航、Enter 复制密码、Ctrl+Enter 复制账号、中文输入法防误触）。
- **已知问题/最小复现**：
  - 无阻断问题。阶段 0 设定的所有桌面可行性标准全部达标。
- **下一步**：
  - 推进 **阶段 1：模型、搜索与假数据面板**。
