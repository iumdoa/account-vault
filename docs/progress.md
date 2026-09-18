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
- **实际验证命令和结果**：
  - `dart format`、`flutter analyze` (0 issue)、`flutter test` 全部通过；
  - `flutter build linux --release` 构建成功；
  - 实测连续 20 次唤起保持单 PID，连续 20 次隐藏/展现循环正常，优雅退出正常。

---

## 阶段 1：模型、搜索与假数据面板

- **当前阶段**：阶段 1：模型、搜索与假数据面板（已完成验收）
- **本次完成**：
  1. **领域模型与集中校验**：
     - 实现 `VaultEntry` 模型，保证账号与密码原文逐字节精确保留（不 trim、不大小写转换、不截断）；
     - 实现 `VaultEntryValidator`，对标题非空及各字段长度上限（标题 256、账号/密码/地址 4096、备注 64KiB、标签 32 个各 64 字符）进行严格校验；
     - 实现 RFC 4122 v4 安全随机 UUID 生成服务 `UuidService`。
  2. **纯搜索服务**：
     - 实现 `EntrySearchService.search` 纯函数；
     - 遵循规格：空格分词、全词匹配、大小写不敏感、中文子串、IP/域名片段匹配；
     - 绝不搜索密码字段；
     - 完全匹配与前缀匹配优先，稳定结合更新时间倒序与 ID 进行确定性排序。
  3. **假数据仓库**：
     - 实现 `MockVaultRepository`，内置 20 条覆盖“网络设备”、“开发工具”、“云计算”、“数据存储”、“日常办公”分类的虚构凭据。
  4. **应用状态与剪贴板调度**：
     - 实现 `VaultSessionController`，处理实时搜索、键盘上下导航、选中项管理、数据增删改与系统剪贴板复制；
     - 复制密码成功后反馈并默认隐藏快捷面板，复制账号后保持面板以便连续操作。
  5. **UI 交互与键盘流**：
     - 实现 `QuickPanelView` 快捷面板：自动聚焦搜索框、方向键切换、Enter 复制密码、Ctrl+Enter 复制账号、Esc 隐藏；
     - **中文输入法防误触**：检查 `searchController.value.composing.isValid`，处于汉字组词状态时 Enter 优先用于选词上屏，绝不触发误复制；
     - 实现 `ManagementView` 完整管理页面：同一窗口内快速切换，支持分组筛选、编辑新增表单（`EntryFormDialog`）、密码显隐切换与删除二次确认；
     - 醒目标记“阶段 1 内存模式：内置 20 条覆盖设备、网站与应用的虚构凭据，修改不持久化到硬盘”。
- **修改文件**：
  - `app/lib/domain/models/vault_entry.dart`
  - `app/lib/domain/services/entry_search_service.dart`
  - `app/lib/domain/services/uuid_service.dart`
  - `app/lib/domain/repositories/vault_repository.dart`
  - `app/lib/infrastructure/mock/mock_vault_repository.dart`
  - `app/lib/application/vault_session_controller.dart`
  - `app/lib/presentation/widgets/quick_panel_view.dart`
  - `app/lib/presentation/widgets/management_view.dart`
  - `app/lib/presentation/widgets/entry_form_dialog.dart`
  - `app/lib/main.dart`
  - `app/test/domain_test.dart`
  - `app/test/widget_test.dart`
  - `app/test/search_benchmark_test.dart`
  - `docs/progress.md`
- **实际验证命令和结果**：
  - `dart format --output=none --set-exit-if-changed lib test`: 全部通过；
  - `flutter analyze`: `No issues found! (ran in 3.1s)`；
  - `flutter test`: 14 个测试全数通过（包含 UUID 随机性、模型校验、精确保留、搜索规则全分支、快捷面板与管理界面完整流程）；
  - **1000 条合成记录性能基准**：
    - 中文子串搜索 ("交换机 25"): **2.3 ms** (规范要求: < 100 ms)
    - IP 片段搜索 ("192.168.2"): **1.08 ms**
    - 多词分词搜索 ("admin_500 cisco"): **1.09 ms**
    - 空查询全量稳定排序: **0.35 ms**
  - 实机桌面构建与运行：`flutter build linux --release` 成功构建，并在 niri 环境中验证了浮动显示、快速呼出与后台常驻。
- **手工验收环境和结果**：
  - 中文输入法选词正常，Enter 无误复制；
  - 复制账号/密码后在外部终端与文本编辑器中粘贴完全一致；
  - 管理页面新建、编辑、删除正常运作。
- **尚未验证的内容**：
  - 阶段 2：Argon2id KDF 派生密钥与 AES-256-GCM 文件认证加解密；
  - 阶段 2：工作 Isolate、串行保存队列与原子文件替换。
- **已知问题/最小复现**：
  - 无。阶段 1 所有完成标准均通过自动化与基准测试检验。
- **下一步**：
  - 推进 **阶段 2：加密格式和可靠文件仓库**。
