# 实际开发和测试环境记录

## 1. 基础系统环境
- **操作系统**：Arch Linux (Rolling release, Linux 7.2.6-arch2-1 x86_64)
- **桌面合成器**：niri 26.04 (commit 8ed0da4)
- **显示协议**：Wayland (WAYLAND_DISPLAY: wayland-1)
- **CPU 架构**：x86_64
- **用户主目录**：`/home/iumdoa`
- **项目工作目录**：`/home/iumdoa/account-vault`

## 2. 编译工具链与系统包版本
- `gtk3`: 1:3.24.52-1
- `cmake`: 4.4.3-2
- `ninja`: 1.13.2-3
- `pkgconf`: 3.0.7-1
- `git`: 2.55.0-1
- `curl`: 8.22.0-1
- `xz`: 5.8.4-1
- `gcc / g++`: 14.x (base-devel)
- `clang / clang++`: 22.1.8
- `unzip`: 6.00
- `jq`: 1.7.1

## 3. Flutter / Dart SDK
- **SDK 安装路径**：`/home/iumdoa/development/flutter`
- **版本**：Flutter 3.47.4 stable (channel stable, revision 9584c6713b)
- **Dart 版本**：3.13.3 (stable) on linux_x64
- **DevTools**：2.60.0

## 4. 运行模式与平台集成实测参数
- **Linux 显示后端**：原生 Wayland (GTK3 / Flutter Impeller OpenGL ES)
- **Linux app-id**：`dev.local.account_vault`（已由 niri 实机查询确认为 `dev.local.account_vault`）
- **单实例机制**：GTK/GApplication 结合 D-Bus 会话总线，支持 `--show`、`--hide`、`--quit` 远程命令转发与毫秒级激活。
- **窗口尺寸与布局**：浮动居中 680x460 逻辑像素（由 niri window-rule 约束与 GTK 初始尺寸双重保障）。
- **Wayland 聚焦机制**：集成 `niri msg action focus-window --id <ID>` 跨工作区/跨图层安全聚焦。
- **桌面快捷键**：niri 快捷键 `Super+Alt+P` 执行 `/home/iumdoa/.local/bin/account-vault --show`。
