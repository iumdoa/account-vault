import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AccountVaultApp());
}

class AccountVaultApp extends StatelessWidget {
  const AccountVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Account Vault',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5),
          brightness: Brightness.dark,
        ),
      ),
      home: const QuickPanelHome(),
    );
  }
}

class QuickPanelHome extends StatefulWidget {
  const QuickPanelHome({super.key});

  @override
  State<QuickPanelHome> createState() => _QuickPanelHomeState();
}

class _QuickPanelHomeState extends State<QuickPanelHome> {
  static const MethodChannel _windowChannel =
      MethodChannel('dev.local.account_vault/window');

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  int _showCount = 1;
  String _lastTriggerTime = '程序启动';

  @override
  void initState() {
    super.initState();
    _windowChannel.setMethodCallHandler(_handleNativeMethodCall);

    // Initial focus on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusSearchBox();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<dynamic> _handleNativeMethodCall(MethodCall call) async {
    if (call.method == 'onShow') {
      setState(() {
        _showCount++;
        final now = DateTime.now();
        _lastTriggerTime =
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      });
      _focusSearchBox();
      return true;
    }
    return null;
  }

  void _focusSearchBox() {
    if (!_searchFocusNode.hasFocus) {
      _searchFocusNode.requestFocus();
    }
    if (_searchController.text.isNotEmpty) {
      _searchController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _searchController.text.length,
      );
    }
  }

  Future<void> _hideWindow() async {
    try {
      await _windowChannel.invokeMethod('hideWindow');
    } catch (e) {
      debugPrint('Error hiding window: $e');
    }
  }

  Future<void> _quitApp() async {
    try {
      await _windowChannel.invokeMethod('quitApp');
    } catch (e) {
      debugPrint('Error quitting app: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode(),
      autofocus: true,
      onKeyEvent: (KeyEvent event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          _hideWindow();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF181A1F),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Search Bar
                TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  decoration: InputDecoration(
                    hintText: '搜索账号、地址、标题或备注 (Esc 隐藏)...',
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFF23272E),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF3E4451)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: Colors.blueAccent, width: 2),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),

                // Center Content / Feasibility Verification Info
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF21252B),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF2C313A)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.verified_user_outlined,
                                color: Colors.greenAccent, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              '阶段 0 桌面可行性验证壳已就绪',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '唤起计数: $_showCount',
                                style: const TextStyle(
                                  color: Colors.blueAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24, color: Color(0xFF2C313A)),
                        _buildInfoRow('App ID', 'dev.local.account_vault'),
                        _buildInfoRow('运行环境', 'Wayland + niri (Arch Linux)'),
                        _buildInfoRow('单实例模式', 'GApplication (D-Bus 会话互斥)'),
                        _buildInfoRow('最近唤起', _lastTriggerTime),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E2227),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '快捷键与控制说明：',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.white70,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '• 在终端执行 account-vault --show 或按快捷键，可无缝激活并聚焦搜索框\n'
                                '• 按 Esc 或点击窗口关闭按钮 (X) 将隐藏面板，后台继续驻留\n'
                                '• 点击底部“退出程序”才完全终止进程',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white60,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Bottom Action Buttons
                Row(
                  children: [
                    Text(
                      '按 Esc 隐藏',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.visibility_off, size: 16),
                      label: const Text('隐藏面板'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade300,
                        side: const BorderSide(color: Color(0xFF3E4451)),
                      ),
                      onPressed: _hideWindow,
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.power_settings_new, size: 16),
                      label: const Text('退出程序'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade900,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _quitApp,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
