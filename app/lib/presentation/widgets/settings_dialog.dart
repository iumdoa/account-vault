import 'package:flutter/material.dart';

import '../../platform/shortcut_config_service.dart';

class SettingsDialog extends StatefulWidget {
  final ShortcutConfigService shortcutService;

  const SettingsDialog({super.key, required this.shortcutService});

  static Future<void> show(
    BuildContext context, {
    ShortcutConfigService? shortcutService,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SettingsDialog(
        shortcutService: shortcutService ?? ShortcutConfigService(),
      ),
    );
  }

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  final _shortcutController = TextEditingController();
  String _currentActiveShortcut = 'Super+Alt+P';
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  ExistingBinding? _conflictingBinding;

  // Modifier toggles
  bool _modSuper = true;
  bool _modAlt = true;
  bool _modCtrl = false;
  bool _modShift = false;
  String _keyPart = 'P';

  static const List<String> _presets = [
    'Super+Alt+P',
    'Super+Alt+V',
    'Super+Space',
    'Super+P',
    'Ctrl+Alt+P',
    'Super+Shift+P',
    'Super+K',
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  @override
  void dispose() {
    _shortcutController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentConfig() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final current = await widget.shortcutService.getCurrentShortcut();
      _currentActiveShortcut = current;
      _shortcutController.text = current;
      _parseModifiersFromShortcut(current);
      await _checkConflict(current);
    } catch (e) {
      _errorMessage = '读取当前配置失败: $e';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _parseModifiersFromShortcut(String shortcut) {
    final parts = shortcut
        .split('+')
        .map((s) => s.trim().toLowerCase())
        .toList();
    _modSuper = parts.contains('super') || parts.contains('mod');
    _modAlt = parts.contains('alt');
    _modCtrl = parts.contains('ctrl');
    _modShift = parts.contains('shift');

    final remaining = parts
        .where(
          (s) =>
              s != 'super' &&
              s != 'mod' &&
              s != 'alt' &&
              s != 'ctrl' &&
              s != 'shift',
        )
        .toList();
    if (remaining.isNotEmpty) {
      _keyPart = remaining.first.toUpperCase();
    }
  }

  void _buildShortcutFromToggles() {
    final list = <String>[];
    if (_modSuper) list.add('Super');
    if (_modAlt) list.add('Alt');
    if (_modCtrl) list.add('Ctrl');
    if (_modShift) list.add('Shift');
    if (_keyPart.trim().isNotEmpty) {
      list.add(_keyPart.trim());
    }

    final combined = list.join('+');
    _shortcutController.text = combined;
    _checkConflict(combined);
  }

  Future<void> _checkConflict(String shortcut) async {
    try {
      final conflict = await widget.shortcutService.checkConflict(shortcut);
      if (mounted) {
        setState(() {
          _conflictingBinding = conflict;
        });
      }
    } catch (_) {}
  }

  void _applyPreset(String preset) {
    _shortcutController.text = preset;
    _parseModifiersFromShortcut(preset);
    _checkConflict(preset);
  }

  Future<void> _saveShortcut() async {
    final shortcut = _shortcutController.text.trim();
    if (shortcut.isEmpty) {
      setState(() {
        _errorMessage = '快捷键不能为空';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await widget.shortcutService.updateShortcut(shortcut);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('全局快捷键已更新为 $shortcut，niri 即刻生效！'),
            backgroundColor: Colors.green.shade700,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNiriAvailable = widget.shortcutService.isNiriConfigAvailable();

    return Dialog(
      backgroundColor: const Color(0xFF1E2227),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  const Icon(
                    Icons.settings,
                    color: Colors.blueAccent,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    '系统与偏好设置',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(color: Color(0xFF2C313A), height: 24),

              // Content Area
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Compositor Status Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isNiriAvailable
                                    ? Colors.green.withValues(alpha: 0.12)
                                    : Colors.amber.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isNiriAvailable
                                      ? Colors.green.withValues(alpha: 0.3)
                                      : Colors.amber.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isNiriAvailable
                                        ? Icons.check_circle_outline
                                        : Icons.info_outline,
                                    color: isNiriAvailable
                                        ? Colors.greenAccent
                                        : Colors.amberAccent,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      isNiriAvailable
                                          ? '检测到 niri 桌面合成器配置 (Wayland): 修改后即时自动重载生效'
                                          : '未在标准路径检测到 niri 配置，快捷键将仅保存至本地偏好设置',
                                      style: TextStyle(
                                        color: isNiriAvailable
                                            ? Colors.greenAccent
                                            : Colors.amberAccent,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Current Active Shortcut Display
                            Row(
                              children: [
                                const Text(
                                  '当前生效快捷键：',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: Colors.blueAccent.withValues(
                                        alpha: 0.4,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    _currentActiveShortcut,
                                    style: const TextStyle(
                                      color: Colors.blueAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Presets Chips
                            const Text(
                              '推荐常用组合：',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _presets.map((preset) {
                                final isSelected =
                                    _shortcutController.text
                                        .trim()
                                        .toLowerCase() ==
                                    preset.toLowerCase();
                                return ActionChip(
                                  label: Text(preset),
                                  backgroundColor: isSelected
                                      ? Colors.blueAccent.withValues(alpha: 0.3)
                                      : const Color(0xFF282C34),
                                  labelStyle: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.grey.shade300,
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                  side: BorderSide(
                                    color: isSelected
                                        ? Colors.blueAccent
                                        : const Color(0xFF3E4451),
                                  ),
                                  onPressed: () => _applyPreset(preset),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 18),

                            // Modifier Toggles & Key Input
                            const Text(
                              '自定义按键定制：',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [
                                FilterChip(
                                  label: const Text('Super (Mod)'),
                                  selected: _modSuper,
                                  onSelected: (val) {
                                    setState(() {
                                      _modSuper = val;
                                      _buildShortcutFromToggles();
                                    });
                                  },
                                ),
                                FilterChip(
                                  label: const Text('Alt'),
                                  selected: _modAlt,
                                  onSelected: (val) {
                                    setState(() {
                                      _modAlt = val;
                                      _buildShortcutFromToggles();
                                    });
                                  },
                                ),
                                FilterChip(
                                  label: const Text('Ctrl'),
                                  selected: _modCtrl,
                                  onSelected: (val) {
                                    setState(() {
                                      _modCtrl = val;
                                      _buildShortcutFromToggles();
                                    });
                                  },
                                ),
                                FilterChip(
                                  label: const Text('Shift'),
                                  selected: _modShift,
                                  onSelected: (val) {
                                    setState(() {
                                      _modShift = val;
                                      _buildShortcutFromToggles();
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Input Box
                            TextField(
                              controller: _shortcutController,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: InputDecoration(
                                labelText: '快捷键文本组合 (例如 Super+Alt+V)',
                                labelStyle: const TextStyle(color: Colors.grey),
                                helperText:
                                    '支持 Super, Alt, Ctrl, Shift 与字母/数字/功能键组合',
                                helperStyle: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 11,
                                ),
                                filled: true,
                                fillColor: const Color(0xFF282C34),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF3E4451),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: Colors.blueAccent,
                                    width: 2,
                                  ),
                                ),
                              ),
                              onChanged: (val) {
                                _parseModifiersFromShortcut(val);
                                _checkConflict(val);
                              },
                            ),
                            const SizedBox(height: 10),

                            // Conflict or Validation Feedback
                            if (_conflictingBinding != null)
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.orange.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.warning_amber_rounded,
                                      color: Colors.orangeAccent,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '检测到按键冲突：此快捷键已被现存绑定占用 (${_conflictingBinding!.key} -> ${_conflictingBinding!.title ?? _conflictingBinding!.action ?? "系统操作"})，请选择其他组合以防冲突',
                                        style: const TextStyle(
                                          color: Colors.orangeAccent,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else if (_shortcutController.text
                                    .trim()
                                    .toLowerCase() ==
                                _currentActiveShortcut.trim().toLowerCase())
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: Colors.blueAccent,
                                      size: 16,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      '当前正在生效的快捷键',
                                      style: TextStyle(
                                        color: Colors.blueAccent,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle_outline,
                                      color: Colors.greenAccent,
                                      size: 16,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      '该按键组合无系统冲突，可直接应用',
                                      style: TextStyle(
                                        color: Colors.greenAccent,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            if (_errorMessage != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.red.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.error_outline,
                                      color: Colors.redAccent,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: const TextStyle(
                                          color: Colors.redAccent,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 20),
                            const Divider(color: Color(0xFF2C313A)),
                            const SizedBox(height: 10),

                            // System Info Section
                            const Text(
                              '配置与路径参考：',
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '• niri 配置文件：${widget.shortcutService.getConfigFilePath()}\n'
                              '• 启动执行器：~/.local/bin/account-vault --show\n'
                              '• 浮动窗口规格：680 × 460 居中 (niri window-rule)\n'
                              '• 保存保护机制：写前备份 + niri validate 预验证，失败自动回滚',
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 11,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),

              const SizedBox(height: 16),
              // Bottom Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text(
                      '取消',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: _isSaving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined, size: 16),
                    label: Text(_isSaving ? '正在验证并保存...' : '保存并立即生效'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                    ),
                    onPressed: _isSaving ? null : _saveShortcut,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
