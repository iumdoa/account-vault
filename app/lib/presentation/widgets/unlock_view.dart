import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import '../../application/vault_session_controller.dart';
import 'backup_restore_dialog.dart';
import 'vault_icons.dart';

/// Screen presented when an encrypted vault exists on disk but is locked
class UnlockView extends StatefulWidget {
  final VaultSessionController controller;
  final VoidCallback onHideWindow;
  final VoidCallback? onQuitApp;

  const UnlockView({
    super.key,
    required this.controller,
    required this.onHideWindow,
    this.onQuitApp,
  });

  @override
  State<UnlockView> createState() => _UnlockViewState();
}

class _UnlockViewState extends State<UnlockView> {
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleUnlock() async {
    final password = _passwordController.text;
    if (password.isEmpty || widget.controller.isBusy) return;

    final success = await widget.controller.unlock(password);
    if (success) {
      _passwordController.clear();
    } else {
      _passwordController.clear();
      if (mounted) {
        _focusNode.requestFocus();
      }
    }
  }

  Future<void> _handleRestore() async {
    final password = _passwordController.text;
    if (password.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请先输入主密码以尝试解密回退备份')));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF21252B),
        title: const Text('从上一份快照恢复', style: TextStyle(color: Colors.white)),
        content: const Text(
          '确定要从 vault.previous.avlt 恢复密码库吗？当前损坏的主库将保留，但会被回退快照覆盖为最新版本。',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确认恢复'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await widget.controller.restoreFromPrevious(password);
      if (success) {
        _passwordController.clear();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          widget.onHideWindow();
        }
      },
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 12.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Icon & Header
                  Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E88E5).withAlpha(35),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF1E88E5).withAlpha(80),
                        ),
                      ),
                      child: const Icon(
                        VaultIcons.lock,
                        color: Color(0xFF42A5F5),
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Center(
                    child: Text(
                      'Account Vault',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      '本地加密库已就绪，请输入主密码解锁',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Error Message Banner
                  if (widget.controller.errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade900.withAlpha(50),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.red.shade700.withAlpha(120),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            VaultIcons.error,
                            size: 18,
                            color: Colors.red.shade300,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.controller.errorMessage!,
                              style: TextStyle(
                                color: Colors.red.shade200,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Password input
                  TextField(
                    controller: _passwordController,
                    focusNode: _focusNode,
                    obscureText: _obscurePassword,
                    enabled: !widget.controller.isBusy,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: '输入主密码',
                      hintStyle: TextStyle(color: Colors.grey.shade600),
                      prefixIcon: const Icon(
                        VaultIcons.password,
                        color: Colors.grey,
                        size: 18,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? VaultIcons.eyeOff : VaultIcons.eye,
                          color: Colors.grey,
                          size: 18,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      filled: true,
                      fillColor: const Color(0xFF21252B),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF3E4451)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF3E4451)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: Color(0xFF1E88E5),
                          width: 1.5,
                        ),
                      ),
                    ),
                    onSubmitted: (_) => _handleUnlock(),
                  ),
                  const SizedBox(height: 16),

                  // Unlock Button
                  FilledButton(
                    onPressed: widget.controller.isBusy ? null : _handleUnlock,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1E88E5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: widget.controller.isBusy
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 10),
                              Text(
                                '正在派生密钥并验证...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          )
                        : const Text(
                            '解 锁',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),

                  // Restore link if backup available
                  if (widget.controller.hasPreviousBackup) ...[
                    const SizedBox(height: 10),
                    Center(
                      child: TextButton.icon(
                        onPressed: widget.controller.isBusy
                            ? null
                            : _handleRestore,
                        icon: const Icon(VaultIcons.history, size: 14),
                        label: const Text(
                          '从上一份快照恢复 (vault.previous.avlt)',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.amber.shade300,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Center(
                    child: TextButton.icon(
                      onPressed: widget.controller.isBusy
                          ? null
                          : () => BackupRestoreDialog.show(
                              context,
                              controller: widget.controller,
                            ),
                      icon: const Icon(VaultIcons.restore, size: 14),
                      label: const Text(
                        '从外部备份恢复 (.avlt)',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blue.shade300,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Footer hints
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Esc 隐藏窗口',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11,
                        ),
                      ),
                      if (widget.onQuitApp != null)
                        InkWell(
                          onTap: widget.onQuitApp,
                          child: Text(
                            '退出程序',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 11,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
