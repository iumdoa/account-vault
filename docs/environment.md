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
- `gcc / g++`: 已安装 (base-devel)
- `clang`: 待安装（Flutter Linux 桌面编译需要）
- `unzip`: 待安装（Flutter 工具链环境检查需要）

## 3. Flutter / Dart SDK
- **SDK 安装路径**：`/home/iumdoa/development/flutter`
- **版本**：Flutter 3.47.4 stable (下载提取中)
- **Dart 版本**：随 Flutter SDK 自带

## 4. 目标运行模式
- **Linux**：原生 Wayland (GTK3 / Flutter Engine)，目标 app-id 待运行后确认
- **快捷键**：niri 快捷键绑定调用 `account-vault --show`
- **单实例机制**：GApplication / 本地 IPC + 文件锁
