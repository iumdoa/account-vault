import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  final _recorderFocusNode = FocusNode();

  String _currentActiveShortcut = 'Super+Alt+P';
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isRecording = false;
  String? _errorMessage;
  ExistingBinding? _conflictingBinding;

  static const List<String> _presets = [
    'Super+Alt+P',
    'Super+Alt+V',
    'Super+Space',
    'Super+P',
    'Super+K',
    'Ctrl+Alt+P',
    'Super+Shift+P',
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  @override
  void dispose() {
    _recorderFocusNode.dispose();
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
    _checkConflict(preset);
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _errorMessage = null;
    });
    _recorderFocusNode.requestFocus();
  }

  void _cancelRecording() {
    setState(() {
      _isRecording = false;
    });
  }

  KeyEventResult _handleRecorderKeyEvent(FocusNode node, KeyEvent event) {
    if (!_isRecording) return KeyEventResult.ignored;

    final isSuper = HardwareKeyboard.instance.isMetaPressed;
    final isAlt = HardwareKeyboard.instance.isAltPressed;
    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;

    if (event is KeyDownEvent) {
      final key = event.logicalKey;

      // Escape with no modifiers cancels recording
      if (key == LogicalKeyboardKey.escape &&
          !isSuper &&
          !isAlt &&
          !isCtrl &&
          !isShift) {
        _cancelRecording();
        return KeyEventResult.handled;
      }

      // Check if key itself is a modifier
      final isModifierKey =
          key == LogicalKeyboardKey.meta ||
          key == LogicalKeyboardKey.metaLeft ||
          key == LogicalKeyboardKey.metaRight ||
          key == LogicalKeyboardKey.alt ||
          key == LogicalKeyboardKey.altLeft ||
          key == LogicalKeyboardKey.altRight ||
          key == LogicalKeyboardKey.control ||
          key == LogicalKeyboardKey.controlLeft ||
          key == LogicalKeyboardKey.controlRight ||
          key == LogicalKeyboardKey.shift ||
          key == LogicalKeyboardKey.shiftLeft ||
          key == LogicalKeyboardKey.shiftRight;

      if (isModifierKey) {
        // Redraw to show currently held modifiers
        setState(() {});
        return KeyEventResult.handled;
      }

      // Non-modifier key was pressed down!
      final keyName = _mapKeyToNiriName(key);
      if (keyName != null && keyName.isNotEmpty) {
        final mods = <String>[];
        if (isSuper) mods.add('Super');
        if (isAlt) mods.add('Alt');
        if (isCtrl) mods.add('Ctrl');
        if (isShift) mods.add('Shift');

        final combo = mods.isEmpty ? keyName : '${mods.join('+')}+$keyName';

        setState(() {
          _isRecording = false;
          _shortcutController.text = combo;
        });
        _checkConflict(combo);
        return KeyEventResult.handled;
      }
    } else if (event is KeyUpEvent) {
      setState(() {});
    }

    return KeyEventResult.handled;
  }

  String? _mapKeyToNiriName(LogicalKeyboardKey key) {
    // Letters A-Z
    if (key.keyId >= LogicalKeyboardKey.keyA.keyId &&
        key.keyId <= LogicalKeyboardKey.keyZ.keyId) {
      return key.keyLabel.toUpperCase();
    }
    // Digits 0-9
    if (key.keyId >= LogicalKeyboardKey.digit0.keyId &&
        key.keyId <= LogicalKeyboardKey.digit9.keyId) {
      return key.keyLabel;
    }
    // Function keys F1-F12
    if (key == LogicalKeyboardKey.f1) return 'F1';
    if (key == LogicalKeyboardKey.f2) return 'F2';
    if (key == LogicalKeyboardKey.f3) return 'F3';
    if (key == LogicalKeyboardKey.f4) return 'F4';
    if (key == LogicalKeyboardKey.f5) return 'F5';
    if (key == LogicalKeyboardKey.f6) return 'F6';
    if (key == LogicalKeyboardKey.f7) return 'F7';
    if (key == LogicalKeyboardKey.f8) return 'F8';
    if (key == LogicalKeyboardKey.f9) return 'F9';
    if (key == LogicalKeyboardKey.f10) return 'F10';
    if (key == LogicalKeyboardKey.f11) return 'F11';
    if (key == LogicalKeyboardKey.f12) return 'F12';

    // Space, Tab, Return, etc.
    if (key == LogicalKeyboardKey.space) return 'Space';
    if (key == LogicalKeyboardKey.tab) return 'Tab';
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      return 'Return';
    }
    if (key == LogicalKeyboardKey.backspace) return 'BackSpace';
    if (key == LogicalKeyboardKey.delete) return 'Delete';

    // Arrow keys
    if (key == LogicalKeyboardKey.arrowLeft) return 'Left';
    if (key == LogicalKeyboardKey.arrowRight) return 'Right';
    if (key == LogicalKeyboardKey.arrowUp) return 'Up';
    if (key == LogicalKeyboardKey.arrowDown) return 'Down';

    // Single ASCII char
    if (key.keyLabel.length == 1 &&
        RegExp(r'^[a-zA-Z0-9]$').hasMatch(key.keyLabel)) {
      return key.keyLabel.toUpperCase();
    }

    return null;
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
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 630),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Header
              Row(
                children: [
                  const Icon(
                    Icons.settings_rounded,
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
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(color: Color(0xFF2C313A), height: 20),

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
                                        ? Icons.check_circle_rounded
                                        : Icons.info_outline_rounded,
                                    color: isNiriAvailable
                                        ? Colors.greenAccent
                                        : Colors.amberAccent,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      isNiriAvailable
                                          ? '检测到 niri 桌面合成器 (Wayland): 修改快捷键经语法预检后即时自动重载生效'
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

                            // Hotkey Recorder Section (按键录制识别)
                            const Text(
                              '全局唤起快捷键录制：',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                              ),
                            ),
                            const SizedBox(height: 8),

                            Focus(
                              focusNode: _recorderFocusNode,
                              onKeyEvent: _handleRecorderKeyEvent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: _isRecording
                                    ? _cancelRecording
                                    : _startRecording,
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: _isRecording
                                        ? Colors.blue.withValues(alpha: 0.15)
                                        : const Color(0xFF282C34),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: _isRecording
                                          ? Colors.blueAccent
                                          : const Color(0xFF3E4451),
                                      width: _isRecording ? 2 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            _isRecording
                                                ? Icons
                                                      .radio_button_checked_rounded
                                                : Icons.keyboard_rounded,
                                            size: 20,
                                            color: _isRecording
                                                ? Colors.redAccent
                                                : Colors.blueAccent,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _isRecording
                                                ? '● 正在监听键盘... 请在键盘上直接按下快捷键 (按 Esc 取消)'
                                                : '点击此处开始在键盘上录制按键',
                                            style: TextStyle(
                                              color: _isRecording
                                                  ? Colors.redAccent
                                                  : Colors.grey.shade300,
                                              fontSize: 12.5,
                                              fontWeight: _isRecording
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                          const Spacer(),
                                          if (!_isRecording)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.blueAccent
                                                    .withValues(alpha: 0.2),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                '按键录制',
                                                style: TextStyle(
                                                  color: Colors.blueAccent,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),

                                      // Display Keycaps
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: _buildKeycapBadges(),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Presets Chips
                            const Text(
                              '或选择推荐常用组合：',
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
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
                                    fontSize: 11.5,
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
                            const SizedBox(height: 12),

                            // Conflict or Status Alert
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
                                        '检测到按键冲突：此快捷键已被占用 (${_conflictingBinding!.key} -> ${_conflictingBinding!.title ?? _conflictingBinding!.action ?? "系统操作"})，请更换以防冲突',
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
                                      Icons.info_outline_rounded,
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
                                      Icons.check_circle_rounded,
                                      color: Colors.greenAccent,
                                      size: 16,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      '该按键组合无系统冲突，可直接保存应用',
                                      style: TextStyle(
                                        color: Colors.greenAccent,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            if (_errorMessage != null) ...[
                              const SizedBox(height: 10),
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
                                      Icons.error_outline_rounded,
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

                            const SizedBox(height: 16),
                            const Divider(color: Color(0xFF2C313A)),
                            const SizedBox(height: 8),

                            // System Info Section
                            const Text(
                              '配置与安全说明：',
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '• niri 配置文件：${widget.shortcutService.getConfigFilePath()}\n'
                              '• 保存防护流水线：写前候选验证 (niri validate) + 失败自动回滚 + 自动备份 (.bak)\n'
                              '• 浮动窗口：680 × 460 居中，解锁后内存常驻不重新锁库',
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

              const SizedBox(height: 14),
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
                  const SizedBox(width: 10),
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
                        : const Icon(Icons.check_rounded, size: 16),
                    label: Text(_isSaving ? '正在验证并保存...' : '保存并立即生效'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
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

  List<Widget> _buildKeycapBadges() {
    if (_isRecording) {
      final isSuper = HardwareKeyboard.instance.isMetaPressed;
      final isAlt = HardwareKeyboard.instance.isAltPressed;
      final isCtrl = HardwareKeyboard.instance.isControlPressed;
      final isShift = HardwareKeyboard.instance.isShiftPressed;

      final widgets = <Widget>[];
      if (isSuper) {
        widgets.add(_keycap('Super', active: true));
      }
      if (isAlt) {
        widgets.add(_keycap('Alt', active: true));
      }
      if (isCtrl) {
        widgets.add(_keycap('Ctrl', active: true));
      }
      if (isShift) {
        widgets.add(_keycap('Shift', active: true));
      }

      if (widgets.isEmpty) {
        return [_keycap('按下修饰键 (Super / Alt / Ctrl) + 字母键...', isPrompt: true)];
      }

      final interspersed = <Widget>[];
      for (var i = 0; i < widgets.length; i++) {
        interspersed.add(widgets[i]);
        interspersed.add(const Text('+', style: TextStyle(color: Colors.grey)));
      }
      interspersed.add(_keycap('...', isPrompt: true));
      return interspersed;
    }

    final text = _shortcutController.text.trim();
    if (text.isEmpty) {
      return [_keycap('未配置快捷键', isPrompt: true)];
    }

    final parts = text.split('+');
    final widgets = <Widget>[];
    for (var i = 0; i < parts.length; i++) {
      widgets.add(_keycap(parts[i]));
      if (i < parts.length - 1) {
        widgets.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              '+',
              style: TextStyle(
                color: Colors.blueAccent,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        );
      }
    }
    return widgets;
  }

  Widget _keycap(String label, {bool active = false, bool isPrompt = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active
            ? Colors.blueAccent.withValues(alpha: 0.3)
            : const Color(0xFF181A1F),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: active
              ? Colors.blueAccent
              : (isPrompt ? Colors.grey.shade700 : const Color(0xFF3E4451)),
        ),
        boxShadow: active
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  offset: const Offset(0, 2),
                  blurRadius: 2,
                ),
              ],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isPrompt
              ? Colors.grey.shade400
              : (active ? Colors.white : Colors.blue.shade100),
          fontWeight: FontWeight.bold,
          fontSize: 13,
          fontFamily: isPrompt ? null : 'monospace',
        ),
      ),
    );
  }
}
