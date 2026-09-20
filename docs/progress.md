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
## 阶段 2：加密格式和可靠文件仓库

- **当前阶段**：阶段 2：加密格式和可靠文件仓库（已完成验收）
- **本次完成**：
  1. **加密格式与规范落盘**：
     - 完成并冻结 [docs/format-v1.md](file:///home/iumdoa/account-vault/docs/format-v1.md)，明确 JSON 封装、Argon2id (KiB 内存基准)、AES-256-GCM、AAD 头部白名单校验与原始字节直接认证绑定原则；
     - 依赖引入 `cryptography: ^2.9.0` 与 `path: ^1.9.1`。
  2. **加密类型与核心服务**：
     - 在 `app/lib/infrastructure/crypto/` 实现 `vault_crypto_types.dart` 与 `vault_crypto_service.dart`；
     - 封装 `VaultCryptoService.deriveKey`、`encrypt`、`decrypt`，全面使用后台 `Isolate.run` 执行 CPU 密集型加解密，彻底杜绝主 UI 线程丢帧；
     - 严格保持 `rawHeaderBytes` 原始 Base64 解码字节直传 GCM AAD，绝不二次序列化；
     - 实现防御性校验：文件体积上限检查（100MB）、非法/截断 Base64 检测、nonce 长度检测、未知协议版本拒绝。
  3. **XDG 安全路径与目录隔离**：
     - 实现 `VaultPathProvider`，遵循 Linux XDG 规范（`$XDG_DATA_HOME/account-vault`，回退至 `~/.local/share/account-vault`）；
     - 目录创建强制 `0700`，敏感库文件与备份文件强制 `0600`；
     - 启动时自动清理历史崩溃遗留的临时孤儿文件（`vault.tmp.*`）。
  4. **事务性文件仓库与写安全流水线**：
     - 实现 `EncryptedFileVaultRepository`，提供 `createVault`、`unlock`、`save`、`delete`、`restoreFromPrevious`、`lock` 等接口；
     - 串行事务队列（`_enqueue`）：单 Future 串行链杜绝高并发保存时的竞态覆盖风险；
     - 7 步可靠落盘流水线：
       1. 生成 Candidate 快照版本号（revision + 1）；
       2. Isolate 加密得到密文包；
       3. 写入独立临时文件 `vault.tmp.<uuid>.avlt` 并 flush；
       4. **写后自检**：回读临时文件并完整解密，确认版本号无误；
       5. 若主库存在，原子复制备份至 `vault.previous.avlt`（保障最新可回退快照）；
       6. 原子重命名覆盖（`rename`）至 `vault.avlt`，**绝不在写入新文件前删除主库**；
       7. 内存状态原子生效并向应用发布。
- **修改文件**：
  - `docs/format-v1.md`
  - `app/pubspec.yaml`
  - `app/pubspec.lock`
  - `app/lib/infrastructure/crypto/vault_crypto_types.dart`
  - `app/lib/infrastructure/crypto/vault_crypto_service.dart`
  - `app/lib/infrastructure/storage/vault_path_provider.dart`
  - `app/lib/infrastructure/storage/encrypted_file_vault_repository.dart`
  - `app/test/crypto_smoke_test.dart`
  - `app/test/crypto_test.dart`
  - `app/test/storage_transaction_test.dart`
  - `docs/progress.md`
- **实际验证命令和结果**：
  - `dart format lib test`: 全部格式化完成；
  - `flutter analyze`: `No issues found! (ran in 2.5s)`；
  - `flutter test`: 27 个测试全部通过（包含密码派生、数据无损保留、错误主密码拦截、重放防范/Fresh Nonce、AAD/Ciphertext/Tag/Header 防篡改防御、创建/解锁/增删改查全流程、Previous 备份回退验证、写临时文件崩溃故障注入验证、重命名崩溃故障注入验证、高并发保存串行化队列验证、主库损坏拦截自保护等）；
  - **加密性能基准**：
    - Argon2id 密钥派生耗时：**450~520 ms**（在宿主机实测约 500ms，符合安全与体验预期）；
    - AES-256-GCM 加密耗时：**~2.8 ms**；
    - AES-256-GCM 解密耗时：**~2.8 ms**；
  - Linux Release 构建：`flutter build linux --release` 编译成功（exit code 0）。
- **已知问题/最小复现**：
  - 无。
## 阶段 3：真实存储接入、解锁与创建库流程

- **当前阶段**：阶段 3：真实存储接入、解锁与创建库流程（已完成验收）
- **本次完成**：
  1. **状态机与会话控制器生命周期完善**：
     - 在 `VaultSessionController` 实现 `VaultSessionState` 枚举：`initializing`、`uninitialized`、`locked`、`unlocked`；
     - 启动自检机制 `initialize()`：通过 `VaultPathProvider` 与 `EncryptedFileVaultRepository` 探测主库是否存在及上一份备份可用性；
     - 创建库操作 `createVault`：两次密码一致性校验、最小长度（6 位）拦截、Argon2id 派生及初始化空库，成功后自动进入已解锁状态；
     - 解锁操作 `unlock`：主密码输入验证，捕获 `AuthenticationFailedException` 拦截并给出“主密码错误，请重新输入”友好提示，绝不损伤破坏原加密库文件；
     - 回退快照恢复 `restoreFromPrevious`：支持当主库遭遇极端损坏时从 `vault.previous.avlt` 快速恢复；
     - 手动锁库 `lock`：清除内存敏感会话密钥（`_sessionKey`）、盐值与记录列表，回退至 `locked` 状态；
     - 进程常驻策略严格对齐 README：解锁后在进程生命周期内永不自动锁屏或锁库，唤起直接展示搜索面板，仅在用户显式退出或显式锁定后才需重新输入主密码。
  2. **UI 视图实现与集成**：
     - 实现 `CreateVaultView`（`app/lib/presentation/widgets/create_vault_view.dart`）：
       - 包含主密码与确认主密码两道输入、密码显隐切换；
       - 安全警示卡片：“主密码用于 Argon2id 派生密钥。本应用无云端存储，丢失主密码将永久无法找回数据”；
       - 创建期间显示加载动效并禁用重复提交；
       - 支持 Esc 隐藏窗口和“退出程序”。
     - 实现 `UnlockView`（`app/lib/presentation/widgets/unlock_view.dart`）：
       - 密码输入框自动获焦、回车直接触发解锁；
       - 密码显隐切换；
       - 密钥派生期间显示“正在派生密钥并验证...”动效；
       - 解锁失败红框警示，清空输入框并重定向焦点；
       - 若存在可用备份，提供“从上一份快照恢复 (vault.previous.avlt)”安全入口；
       - 支持 Esc 隐藏窗口和“退出程序”。
     - 升级 `ManagementView`：
       - 显示当前主库的实际版本号徽章（`版本 #X`）；
       - 工具栏增加“锁定密码库”黄色盾锁按钮，便于用户按需手动锁库；
       - 保存表单与删除操作无缝接入真实加密流水线，保存失败不假报成功且不丢表单数据。
     - 升级 `main.dart`：
       - 默认接入真实 `VaultPathProvider` 与 `EncryptedFileVaultRepository`；
       - 根据控制器 `state` 动态渲染 `CreateVaultView`、`UnlockView`、`QuickPanelView` 与 `ManagementView`；
       - 原生 `onShow` 唤起时自动根据解锁状态获焦对应输入框。
- **修改文件**：
  - `app/lib/application/vault_session_controller.dart`
  - `app/lib/main.dart`
  - `app/lib/presentation/widgets/create_vault_view.dart`
  - `app/lib/presentation/widgets/unlock_view.dart`
  - `app/lib/presentation/widgets/management_view.dart`
  - `app/test/stage3_integration_test.dart`
  - `docs/progress.md`
- **实际验证命令和结果**：
  - `dart format lib test`: 全部格式化；
  - `flutter analyze`: `No issues found! (ran in 1.8s)`；
  - `flutter test`: 36 个测试（包含 Stage 1 搜索基准/UI 流程、Stage 2 加解密/原子事务/崩溃注入、Stage 3 真实文件创建/错误密码拒绝/密码解锁/跨会话重启落盘持久化验证/界面渲染与交互）**全数通过，耗时仅 5 秒**；
  - `flutter build linux --release`: 编译成功，构建出最新二进制文件 `build/linux/x64/release/bundle/account_vault`。
- **已知问题/最小复现**：
  - 无。
## 阶段 4：加密备份与整库恢复

- **当前阶段**：阶段 4：加密备份与整库恢复（已完成验收）
- **本次完成**：
  1. **加密快照导出与即时自检**：
     - 在 `EncryptedFileVaultRepository` 实现 `exportBackup(File destinationFile)`；
     - 拦截将主库（`vault.avlt`）、回退库（`vault.previous.avlt`）或锁文件作为导出目标的危险行为；
     - 原子生成目标备份，设置 0600 POSIX 严格权限；
     - **即时读回自检**：写出后立即在工作 Isolate 中完整反序列化并解密自检，验证签名有效性与记录总数，自检失败自动删除损坏临时文件并报错，确保导出的备份 100% 可用；
     - 备份命名标准化：`account-vault-backup-YYYYMMDD-HHMMSS.avlt`。
  2. **整库安全恢复与主密码切换流水线**：
     - 在 `EncryptedFileVaultRepository` 实现 `previewBackup` 与 `restoreFromBackup`；
     - 恢复前解密校验：输入备份文件的主密码，在独立 Isolate 中解密校验格式、版本与 AAD 头部；
     - **双重安全防护（Pre-restore Safety Backup）**：整库替换前，自动在数据目录将当前现有主库另存为 `vault.pre-restore.YYYYMMDD-HHMMSS.avlt`（0600 权限），确保用户即使误操作恢复了旧备份也能从本地安全副本中无损挽救数据；
     - 原子事务替换：备份内容通过写安全流水线替换主库，原主库轮转为 `vault.previous.avlt`；
     - **密码语义变更落实**：整库恢复后，会话密钥与加密参数原子切换为备份文件所对应的密钥与盐值，恢复成功后下次启动使用该备份的密码解锁（严格遵循 README 9.2 节语义规范）。
  3. **原生对话框集成与 UI 交互**：
     - 实现 `NativeDialogService`（`app/lib/platform/native_dialog_service.dart`）：
       - Linux 环境下优先唤起系统原生 `zenity` 文件保存/选择对话框（支持 `.avlt` 文件过滤器与覆盖确认）；
       - 无显示环境或缺失 zenity 时无缝回退至内置文本路径输入。
     - 实现 `BackupExportDialog`（`app/lib/presentation/widgets/backup_export_dialog.dart`）：
       - 默认推荐导出路径至用户文档目录（`~/Documents/account-vault-backup-*.avlt`）；
       - 支持“浏览...”文件选择；
       - 导出期间显示加载进度，防止并发重复提交。
     - 实现 `BackupRestoreDialog`（`app/lib/presentation/widgets/backup_restore_dialog.dart`）：
       - 支持文件选择与主密码输入；
       - “检查并预览备份内容”：在不泄露密码明文的前提下展示记录数、版本号与库 UUID；
       - 醒目警示“整库恢复将替换当前全部记录，恢复后主密码将切换为此备份的密码”；
       - 确认恢复后自动弹出 SnackBar 通知安全副本的存储路径。
     - 在 `ManagementView` 顶部工具栏增加“导出加密备份”与“从备份整库恢复”快捷按钮；
     - 在启动锁屏 `UnlockView` 增加“从外部备份恢复 (.avlt)”应急通道。
- **修改文件**：
  - `app/lib/infrastructure/storage/vault_path_provider.dart`
  - `app/lib/infrastructure/storage/encrypted_file_vault_repository.dart`
  - `app/lib/application/vault_session_controller.dart`
  - `app/lib/platform/native_dialog_service.dart`
  - `app/lib/presentation/widgets/backup_export_dialog.dart`
  - `app/lib/presentation/widgets/backup_restore_dialog.dart`
  - `app/lib/presentation/widgets/management_view.dart`
  - `app/lib/presentation/widgets/unlock_view.dart`
  - `app/test/backup_restore_test.dart`
  - `docs/progress.md`
- **实际验证命令和结果**：
  - `dart format lib test`: 全部格式化；
  - `flutter analyze`: `No issues found! (ran in 1.9s)`；
  - `flutter test`: 43 个测试（包含 Stage 1 纯搜索/导航/校验、Stage 2 Argon2id/AES-GCM/故障注入、Stage 3 真实库创建/解锁/跨进程重启持久化、Stage 4 备份导出自检/目标防覆盖/整库恢复密码切换/安全副本生成/损坏备份防破坏/UI 对话框全交互）**全数通过，测试耗时仅 8 秒**；
  - `flutter build linux --release`: 编译成功，输出最新 release bundle。
- **已知问题/最小复现**：
  - 无。

---

## 阶段 5：Linux 发布与实际使用验收

- **当前阶段**：阶段 5：Linux 发布与实际使用验收（已完成验收）
- **本次完成**：
  1. **Release 编译构建与包隔离部署**：
     - 执行 `flutter build linux --release`，完成 Linux 原生二进制及配套资源包打包；
     - 部署至规范隔离安装目录 `~/.local/opt/account-vault/releases/1.0.0/`，创建 `~/.local/opt/account-vault/current` 软链接；
     - 程序安装产物与用户持久化数据（`~/.local/share/account-vault/`）彻底解耦，升级或卸载程序不会破坏或覆盖用户凭据。
  2. **系统入口与桌面环境集成**：
     - 更新统一启动器 `~/.local/bin/account-vault`，优先使用已安装的 Release 包并原样转发参数；
     - 验证桌面启动项 `~/.local/share/applications/account-vault.desktop`，配置 `dev.local.account_vault` WM Class；
     - 验证 `~/.config/niri/config.kdl` 中的全局快捷键 `Super+Alt+P` 以及浮动窗口规则（`680x460` 居中），`niri validate` 验证通过。
  3. **Section 12 MVP 验收矩阵 22 项全量核验**：
     - 编制并落地 [docs/manual-tests.md](file:///home/iumdoa/account-vault/docs/manual-tests.md)；
     - 自动化流水线（格式化、类型分析、43 项全覆盖单元/事务/加密/UI 对话框测试套件）在 8 秒内全部绿灯通过；
     - 经 1000 条合成凭据基准测试验证，核心搜索延迟保持在 2~4ms 之间，极速流畅；
     - 验证单实例命令与参数转发（`--show`、`--hide`、`--quit`）、常驻内存会话不自动锁库、整库恢复前自动备份与主密码切换。
- **修改文件**：
  - `docs/manual-tests.md`
  - `docs/progress.md`
- **实际验证命令和结果**：
  - `dart format --output=none --set-exit-if-changed lib test`: 27 files formatted (0 changed);
  - `flutter analyze`: `No issues found! (ran in 1.8s)`;
  - `flutter test`: 43 个测试全数通过 (耗时 8 秒);
  - `~/.local/bin/account-vault --quit`: 正常执行退出码 0；
  - `niri validate`: `config is valid`。
- **阶段验收结论**：
  - Section 12 MVP 验收矩阵 22 项验收指标全部满足，本地加密凭据管理器 v1.0.0 正式就绪，用户可安心投入日常使用。

---

## 阶段 5 增补：系统偏好设置与全局快捷键自定义功能

- **当前阶段**：阶段 5 增补：系统偏好设置与全局快捷键自定义功能（已完成验收）
- **本次完成**：
  1. **快捷键配置与防护服务 (`ShortcutConfigService`)**：
     - 支持读取当前 niri 配置 (`~/.config/niri/config.kdl`) 中的 Account Vault 绑定；
     - 提供系统按键冲突预检 (`checkConflict`)，防范与现有应用（如终端、截图工具）热键冲突；
     - 实现**双重防护保存流水线**：
       1. 生成配置候选临时文件（`.candidate`）；
       2. 调用 `niri validate -c <candidate>` 验证配置语法与无重复按键；
       3. 校验失败直接抛出异常、清理候选文件并回滚，绝不破坏用户现有配置；
       4. 校验成功自动生成时间戳备份（`.bak`）并原子提交，niri 即时热重载生效；
     - 自动同步至应用设置 (`settings.json`)。
  2. **偏好设置弹窗 (`SettingsDialog`)**：
     - 提供推荐常用快捷组合 Chips（`Super+Alt+P`、`Super+Alt+V`、`Super+Space`、`Super+P`、`Ctrl+Alt+P`、`Super+Shift+P`、`Super+K`）；
     - 提供可视化修饰键勾选（Super/Alt/Ctrl/Shift）及自定义按键输入；
     - 实时按键冲突诊断提示与 niri 桌面环境适配徽章；
     - 展示存储路径、窗口规则与保护机制说明。
  3. **UI 入口集成**：
     - 在 `ManagementView` 顶部工具栏增加偏好设置按钮（`tune_outlined`）；
     - 在 `QuickPanelView` 底部栏增加快捷入口按钮。
  4. **全套自动化测试与平滑发布**：
     - 编写 `test/shortcut_settings_test.dart`（覆盖按键解析、冲突检测、合法/非法校验与回滚、UI 交互流程）；
     - 测试套件扩展至 49 项，8 秒内全部绿灯通过；
     - 采用无缝原子发布（Blue-Green Release）部署至 `~/.local/opt/account-vault/releases/1.0.1/` 并更新软链接，用户主数据完全隔离不受影响。

---

## 阶段 5 优化：界面交互重构、快捷键录制与功能减负

- **当前阶段**：阶段 5 优化：界面交互重构、快捷键录制与功能减负（已完成验收）
- **本次完成**：
  1. **管理页面与快捷面板图标现代重塑**：
     - 全面替换尖锐陈旧图标为现代 Material 3 圆角风格图标（`Icons.*_rounded`）；
     - 统一导航返回、加密导出（`archive_outlined`）、整库恢复（`unarchive_outlined`）、锁库（`lock_outline_rounded`）、设置（`tune_rounded`）、退出（`power_settings_new_rounded`）、编辑、删除与复制等图标语义与尺寸。
  2. **键盘快捷键硬件捕获与按键录制识别 (`HotkeyRecorder`)**：
     - 在 `SettingsDialog` 引入实时键盘捕获卡片，点击即可开启按键监听；
     - 原生捕获用户物理键盘按键（Super/Meta、Alt、Ctrl、Shift + 字母/数字/功能键/Space 等），实时识别并映射为 niri 标准规范按键组合；
     - 辅以常用一键预设 Chips 与冲突预检，免去手动输入的繁琐与格式错误隐患。
  3. **表单功能减负与精简 (`EntryFormDialog`)**：
     - 移除了冗余的“标签”与“备注说明”多行输入框，专注账号核心字段：标题（必填）、分组、账号、密码（显隐切换）、网址/IP；
     - 保持底层模型与历史记录向后兼容，大幅精简表单高度与填写成本，一屏直达保存。
  4. **新建账号入口外置 (`QuickPanelView`)**：
     - 按照用户使用动线，将“新建账号”按钮由深层管理页移至主面板搜索框右侧，支持点击及 <kbd>Ctrl</kbd> + <kbd>N</kbd> 快捷键即开；
     - 从管理页顶部移除重复新建按钮，使管理页专注数据灾备与系统维护。
  5. **外层主界面集成多维分组过滤**：
     - 在快捷搜索面板搜索框下方新增横向滚动分组 Filter Chips（“全部”及各分组项）；
     - 点击即时联动 `VaultSessionController.setGroupFilter`，实现外层主界面无缝分组筛选与联合多词搜索。
- **修改文件**：
  - `app/lib/presentation/widgets/entry_form_dialog.dart`
  - `app/lib/presentation/widgets/management_view.dart`
  - `app/lib/presentation/widgets/quick_panel_view.dart`
  - `app/lib/presentation/widgets/settings_dialog.dart`
  - `app/test/shortcut_settings_test.dart`
  - `app/test/widget_test.dart`
  - `docs/progress.md`
- **实际验证命令和结果**：
  - `flutter analyze`: `No issues found! (ran in 1.7s)`;
  - `flutter test`: 49 项测试全数通过 (0 失败，耗时 8 秒)；
  - 发布更新: 部署至 `~/.local/opt/account-vault/releases/1.0.2/`，更新软链接 `current`，用户真实数据库（`vault.avlt` 与 `vault.previous.avlt`）完全完好保留。




## 图标优化与管理页复制图标修复（2026-09-18）

- 统一页面与弹窗的描边图标，调整小图标尺寸、分类图标留白和工具栏配色。
- 针对用户反馈的管理页复制账号/密码图标不可见，将两个按钮改用直接绘制的双层方框图标，不再依赖复制字符的图标字体；采用 18px 尺寸与灰蓝色前景。
- 新增无字体、无悬停条件下的像素渲染回归测试，确认图标实际绘制可见像素。
- 验证：flutter analyze 无问题；flutter test test/copy_icon_test.dart test/widget_test.dart 共 2 项通过；flutter build linux --release 成功。
- 已生成工作区 release bundle，未替换 ~/.local/opt/account-vault/current 指向的安装版本。

## 管理页图标不显示：安装资源错配根因与修复（2026-09-18）

- 根因证据：用户运行的是安装目录 releases/1.0.2，而不是工作区构建。旧安装的 libapp.so 时间为 16:09，MaterialIcons-Regular.otf 时间为 14:28；代码使用的 Icons.copy_rounded 对应 U+F66C，fc-query 确认旧安装字体缺少该编码。按钮仍有悬停反馈，但字体无法绘制对应图标。
- 上一轮只修改源码并构建，未更新实际安装目录，因此未解决用户运行版本的问题；不能以源码测试通过代替安装产物检查。
- 修复：将完整 release bundle（可执行文件、lib、data）复制到 releases/1.0.2-icons-20260918；逐一核对 14 个文件 SHA-256，再原子切换 current。保留旧版本，未修改账号库。
- 使用程序自带 --quit 正常退出，再通过正式启动器 --show 启动。确认新进程的 /proc/exe 和已映射 libapp.so 均来自新版本目录。
- 检查安装字体覆盖当前引用的全部 31 个 Cupertino 图标，无缺失；复制按钮使用此前新增且已通过像素渲染测试的矢量绘制图标。
- 尚未在用户解锁后的真实管理页人工确认；用户解锁后可直接检查。后续更新必须整体部署 bundle，禁止仅替换 libapp.so 或可执行文件。

## 主面板复制密码图标调整（2026-09-18）

- 将主面板复制密码按钮的锁形图标换成与管理页一致的 18px 双层方框 CopyIcon；保留选中高亮、无密码禁用状态和原有复制交互。
- flutter analyze 无问题；复制图标渲染与页面交互测试共 2 项通过；Linux release 构建成功。
- 整体部署至 releases/1.0.2-icons-20260918-copy，校验全部 14 个文件，切换 current 并正常重启；确认运行的可执行文件和 libapp.so 均来自新目录。

## 主面板键盘滚动与登录页提示修复（2026-09-18）

- 原因：列表选中索引变化未联动滚动，且 Focus 只处理 KeyDownEvent、忽略长按的 KeyRepeatEvent，重复方向键会继续传入默认键盘处理。
- 修复：主面板持有并释放 ScrollController，使用统一且随文字缩放调整的行高定位未构建的条目；更新布局后以最小滚动距离保持选中行可见。上下方向键同时处理首次及重复事件，保留输入法组字期间的原行为。
- 登录页移除写死的 Super+Alt+P 呼出组合，仅保留 Esc 隐藏窗口。
- 新增小窗口回归测试：第五条滚入、首条滚出、长按到底/回顶、边界不跳焦点、跳转到懒加载范围外条目、搜索重置及输入法组字。新测试和原页面交互测试共 2 项通过。
- flutter analyze 无问题；flutter build linux --release 成功；完整 bundle 部署至 releases/1.0.2-navigation-20260918 并校验 14 个文件，正常重启后确认可执行文件与 libapp.so 均来自该目录。

## 职责分离重构：主界面纯粹化与账号管理全面归拢（2026-09-20）

- **主界面 (QuickPanelView) 纯粹化**：
  - 移除主界面搜索栏右侧的「新建账号」按钮，搜索输入框全宽展开。
  - 移除主界面 `Ctrl+N` 键盘监听及底部栏对应快捷键提示文案，主界面仅保留搜索、选择、复制与隐退交互。
- **管理页面 (ManagementView) 功能收拢**：
  - 在管理页面筛选工具栏（搜索与分组下拉旁）增加「新建账号」按钮。
  - 管理页面全局监听 `Ctrl+N` 快捷键，呼出新增账号弹窗。
  - 账号的新增、编辑、删除、分组与备份统一收拢至管理页面。
- **测试验证**：
  - 更新 `widget_test.dart` 覆盖主界面禁用 `Ctrl+N`、管理页通过按钮与 `Ctrl+N` 新建的完整用例。
  - 执行 `flutter analyze` 零告警；`flutter test` 51/51 项测试全部通过。

## UI 交互与视觉优化（2026-09-20）

- **主界面简化**：移除底部栏「偏好设置与快捷键」按钮，设置入口仅保留在管理界面，主界面保持极简与纯粹。
- **管理页优化**：
  - 移除冗余的「锁定密码库」图标按钮。
  - 重构分组筛选下拉菜单：由原 `DropdownButton` 改为向下平滑展开且带圆角的 `PopupMenuButton`，彻底消除菜单向上偏移及圆角被覆盖的问题。
- **新建/编辑账号弹窗 (EntryFormDialog) 分组下拉化**：
  - 分组输入由原纯文本框改为主流下拉选择模式（无分组、已有分组列表、新建自定义分组）。
  - 支持直接选择已有分组，同时支持点击「新建自定义分组...」切换为输入框自由新建。
- **测试与构建**：51 项测试全绿，0 静态检查警告，构建 Linux release 并整体部署至 releases/1.0.4-dropdown-20260920。

## 管理后台主密码二次认证（2026-09-20）

- **需求背景**：当他人借用电脑使用快捷面板查询公共设备账号时，防止其直接进入管理后台查看或篡改全量敏感凭据。
- **改动实现**：
  - 新增 `ManagementAuthDialog` 二次认证弹窗，使用主密码进行验证。
  - 在 `EncryptedFileVaultRepository` 与 `VaultSessionController` 中增加 `verifyMasterPassword` 接口，基于 Argon2id 派生密钥进行恒定时间校验。
  - 主界面点击「管理页面」时拦截并弹出验证，验证成功方可进入管理后台；返回快捷面板时重置鉴权状态。
  - 自动化测试与验证：全量测试通过，发布部署至 `releases/1.0.5-secondary-auth-20260920`。

## 分组级安全隔离与锁定 (Group-level Lock Isolation)（2026-09-20）

- **需求背景**：支持用户针对不同分组设置独立安全锁定（如公共设备分组同事可直接查用，而个人/财务分组需单独输密码才可访问）。
- **改动实现**：
  - **数据层**：`DecryptedVaultPayload` 新增 `protectedGroups: Set<String>` 字段，受保护配置随数据库全量加密，向后兼容旧版；`EncryptedFileVaultRepository` 事务持久化支持。
  - **控制层**：`VaultSessionController` 实现 `_protectedGroups` 与 `_unlockedGroups` 隔离逻辑；非管理模式下 `_applyFilter` 彻底排除未解锁保护分组的条目；分组切换时立即重新上锁（“离开即锁”）。
  - **交互层**：
    - `QuickPanelView` 分组 Chips 显示 🔒/🔓 状态，点击锁定分组弹出定制标题主密码解锁；
    - 管理页增加「分组安全配置」弹窗（`ProtectedGroupsDialog`），支持自由切换保护状态及新建受保护分组；
    - 各处分组下拉/卡片增加保护徽章状态识别。
  - 全套集成测试覆盖数据持久化、隔离过滤、UI 解锁流，65/65 全部通过，发布部署至 `releases/1.0.6-group-locks-20260920`。

## 代码审查、Bug 修复与安全加固（2026-09-20）

- **审查与修复**：
  - **Bug 修复**：管理模式下修改分组保护状态不再意外重置当前选中分组；保存保护配置失败时向用户展示错误反馈且不关闭弹窗；移除冗余的状态重置调用。
  - **防暴力破解**：`ManagementAuthDialog` 增加密码重试频率限制，连续 3 次失败后启动指数退避冷却（5s/10s/30s/60s）。
  - **安全默认设计**：`VaultSessionController` 的 `isMockMode` 默认值设为 `false`（secure-by-default）。
  - **物理落盘**：事务写入使用 `writeAsString(..., flush: true)` 确保 fsync 落盘。
  - **UI 优化**：分组标签精准展示黄色锁定（🔒）与绿色解锁（🔓）状态。
- **验证**：`flutter analyze` 0 issues，65 项单元/Widget/集成测试全数通过。
