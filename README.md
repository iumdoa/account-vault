# Account Vault

<p align="center">
  <strong>极速、轻量、纯本地加密的 Linux 桌面账号密码管理器</strong>
  <br>
  <em>针对 Wayland 与 niri 动态平铺合成器深度定制适配</em>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-blue.svg" alt="License: GPL-3.0"></a>
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-%3E%3D3.16-02569B.svg?logo=flutter" alt="Flutter"></a>
  <img src="https://img.shields.io/badge/Platform-Linux%20(Wayland%20%7C%20X11)-orange.svg" alt="Platform Linux">
  <img src="https://img.shields.io/badge/Compositor-niri%20%7C%20Wayland-brightgreen.svg" alt="niri / Wayland">
  <a href="SECURITY.md"><img src="https://img.shields.io/badge/Security-Argon2id%20%2B%20AES--256--GCM-success.svg" alt="Security"></a>
</p>

---

## 🌟 核心特性

- 🔒 **零云端、无网络依赖 (Zero-Cloud & Zero-Network)**
  - 纯本地运行，不声明网络权限，无任何第三方分析统计，彻底杜绝云端泄露与服务宕机风险。
- 🛡️ **现代密码学保障 (Modern Cryptography)**
  - **密钥派生 (KDF)**：基于抗 GPU/ASIC 暴力的 **Argon2id**（64 MiB 内存代价、3 轮迭代）。
  - **认证加密**：采用业界标准的 **AES-256-GCM**，每次加密生成唯一 96-bit 随机 IV，结合 AAD 绑定文件格式版本防重放与篡改。
  - **安全事务落盘**：写入临时文件 -> fsync 强制物理落盘 -> 解密预校验成功后原子替换主库，自动保留上一份有效快照（`.previous.avlt`）。
- 🔐 **管理后台二次验证与防暴力破解**
  - **二次鉴权**：进入账号库完整管理后台需二次验证主密码，防止他人借用电脑时越权查看或篡改全量凭证。
  - **防暴力破解**：配备密码试错频率限制机制，连续 3 次失败后自动触发指数退避冷却（5s / 10s / 30s / 60s），阻断脚本自动化破解。
- 🗂️ **细粒度分组安全锁定与隔离 (Group-level Lock Isolation)**
  - **分组独立上锁**：支持对敏感分组（如“个人”、“财务”）设置保护锁定，受保护分组配置同样随数据库全程加密。
  - **搜索与列表彻底隔离**：未解锁的受保护分组在快捷面板中完全不可见，模糊搜索绝不匹配展示，杜绝凭据泄露。
  - **随用即解，离开即锁**：点击受保护标签可单独输入主密码临时解锁查看；切换分组或隐藏面板时自动即时重新上锁。
- ⚡ **Wayland / niri 深度定制与极速呼出**
  - 基于 GTK/GApplication 与 D-Bus 会话总线实现单实例常驻。
  - 支持全局快捷键（默认 `Super+Alt+P`）毫秒级唤醒 680×460 居中浮动快捷面板，操作完成后 `Esc` 即刻隐藏。
- ⌨️ **全键盘流极速操作**
  - 支持名称、账号、网址/IP 片段、标签的高性能模糊搜索（千条记录毫秒级检索）。
  - 支持上下键快速切换、长按滚动、一键分别复制账号与密码；内置中文输入法（IME）组字状态拦截，绝无误复制。
- 📦 **安全加密备份与整库恢复**
  - 支持将整个账号库导出为加密的独立备份文件（`.avlt`），支持使用当前主密码或自定义临时密码加密。
  - 支持整库校验导入与快照灾备。

---

## 🖥️ 快速开始

### 方式一：下载预编译发布包 (推荐)

1. 从 [Releases 页面](../../releases) 下载最新版的 `account-vault-vX.Y.Z-linux-x86_64.tar.gz`。
2. 解压并安装到本地路径（如 `~/.local/opt/account-vault`）：
   ```bash
   mkdir -p ~/.local/opt ~/.local/bin
   tar -xzf account-vault-*-linux-x86_64.tar.gz -C ~/.local/opt/
   ln -sf ~/.local/opt/account-vault-*/account_vault ~/.local/bin/account-vault
   ```
3. 安装桌面快捷图标：
   ```bash
   mkdir -p ~/.local/share/applications
   cp packaging/account-vault.desktop ~/.local/share/applications/
   ```

### 方式二：从源码编译构建

确保系统已安装 Flutter SDK（3.x+）及 Linux 桌面编译工具链（`clang`, `cmake`, `ninja`, `pkg-config`, `libgtk-3-dev`）：

```bash
# 克隆仓库
git clone https://github.com/<your-username>/account-vault.git
cd account-vault/app

# 安装依赖
flutter pub get

# 执行静态检查与完整测试套件
flutter analyze
flutter test

# 构建 Linux Release 产物
flutter build linux --release
```
编译产物位于 `app/build/linux/x64/release/bundle/`。

---

## ⚙️ 桌面合成器集成配置 (以 niri 为例)

Account Vault 针对现代 Wayland 合成器（特别是 [niri](https://github.com/YaLTeR/niri)）进行了专门的窗口规则和呼出焦点优化。

在 `~/.config/niri/config.kdl` 中添加以下配置：

```kdl
// 1. 窗口浮动规则与初始尺寸
window-rule {
    match app-id=r#"^dev\.local\.account_vault$"#
    open-floating true
    default-column-width { fixed 680; }
    default-window-height { fixed 460; }
}

// 2. 全局唤醒快捷键绑定 (例如 Super+Alt+P)
binds {
    Super+Alt+P repeat=false {
        spawn "account-vault" "--show";
    }
}
```

*若使用 Sway、Hyprland 或 GNOME，配置方式类似：将 `account-vault --show` 绑定到全局快捷键，并将窗口 class/app-id `dev.local.account_vault` 设置为浮动居中。*

---

## 📖 技术文档与规范

本项目有着严谨的工程设计与加密存储规范，欢迎查阅详细文档：

- 📐 **架构与初始设计规格书**：[docs/design-spec-v1.md](docs/design-spec-v1.md)
- 🔐 **存储与加密封装格式 v1 规范**：[docs/format-v1.md](docs/format-v1.md)
- 🧪 **验收测试用例与验证规范**：[docs/manual-tests.md](docs/manual-tests.md)
- 💻 **开发与运行实测环境参数**：[docs/environment.md](docs/environment.md)
- 📈 **开发进度与迭代归档**：[docs/progress.md](docs/progress.md)

---

## 🗺️ 路线图 (Roadmap)

- [x] Linux 端单实例常驻与 D-Bus/GApplication 远程呼出
- [x] Argon2id 密钥派生与 AES-256-GCM 事务安全存储（原子备份轮转与 fsync 落盘）
- [x] 居中快捷搜索面板与全键盘流沉浸操作（IME 组字防误触）
- [x] 管理页面职责归拢与主密码二次鉴权验证
- [x] 防暴力破解指数退避冷却保护
- [x] 敏感分组独立安全锁定与多维隔离
- [x] 加密备份导出与整库导入恢复
- [x] 自定义全局快捷键与冲突 pre-check 校验
- [ ] 导出受保护的 CSV 明文备份 / CSV 批量导入
- [ ] 剪贴板安全自动超时清理（防止密码长期停留在剪贴板）
- [ ] Android 平台界面复用与数据库跨端导入互通

---

## 🤝 贡献与反馈

欢迎提交 Issue 和 Pull Request！
- 请在提交代码前阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。
- 发现安全漏洞请**不要**公开发布 Issue，请参阅 [SECURITY.md](SECURITY.md) 了解负责任的漏洞披露机制。

---

## 📄 开源许可证

本项目采用 **GNU General Public License v3.0 (GPL-3.0)** 开源。详见 [LICENSE](LICENSE) 文件。
