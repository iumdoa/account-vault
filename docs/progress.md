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
- **下一步**：
  - 进入 **阶段 4：加密备份与整库恢复**：
    - 在管理页面提供“导出加密备份”与“从备份恢复”入口；
    - 备份文件采用独立时间戳密文格式，包含自验证 Header 与校验签名；
    - 导入恢复前先对现有库进行安全备份，验证备份文件可解密后通过事务覆盖生效。
