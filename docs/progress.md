# 开发进展记录

## 阶段 0：环境、工程和桌面可行性

- **当前阶段**：阶段 0：环境、工程和桌面可行性
- **本次完成**：
  1. 检查了宿主机操作系统环境（Arch Linux、niri 26.04、Wayland）。
  2. 检查了基础开发包状态（gtk3、cmake、ninja、pkgconf、base-devel 已就绪）。
  3. 确定了 Flutter SDK 安装方案（下载官方 stable 3.47.4 至 `~/development/flutter`）。
  4. 初始化了 `docs/environment.md`。
- **修改文件**：
  - `docs/environment.md`
  - `docs/progress.md`
- **实际验证命令和结果**：
  - `niri --version`: niri 26.04 (8ed0da4)
  - `echo $WAYLAND_DISPLAY`: wayland-1
  - `pacman -Q gtk3 cmake ninja pkgconf base-devel git curl xz`: 均已安装就绪
  - `pacman -Q clang unzip`: 提示未安装
- **手工验收环境和结果**：
  - niri 运行正常，当前窗口与会话信息可正常通过 `niri msg windows` 读取。
- **尚未验证的内容**：
  - Flutter SDK 完整提取与 `flutter doctor -v` 验证。
  - `clang` 与 `unzip` 补齐安装后的 Linux toolchain 状态。
  - `flutter create` 工程创建及空项目在 niri 下的运行、app-id 捕获。
  - `--show` 单实例唤起与搜索框自动聚焦。
- **已知问题/最小复现**：
  - 宿主机尚未安装 `clang` 与 `unzip`，系统构建 Linux Flutter 应用需要 `clang` 编译器。安装需要 pacman 权限。
- **下一步**：
  - 完成 Flutter SDK 下载与解压。
  - 确认 `clang` 与 `unzip` 安装。
  - 创建 `app/` 目录下的 Flutter 项目并进行 Linux 运行验证。
