import 'package:flutter/material.dart';

import '../../application/vault_session_controller.dart';
import 'vault_icons.dart';

/// Modal dialog for verifying master password before entering management console
class ManagementAuthDialog extends StatefulWidget {
  final VaultSessionController controller;

  const ManagementAuthDialog({super.key, required this.controller});

  static Future<bool> show(
    BuildContext context, {
    required VaultSessionController controller,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ManagementAuthDialog(controller: controller),
    );
    return result ?? false;
  }

  @override
  State<ManagementAuthDialog> createState() => _ManagementAuthDialogState();
}

class _ManagementAuthDialogState extends State<ManagementAuthDialog> {
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _obscurePassword = true;
  bool _isVerifying = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleVerify() async {
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() {
        _errorMessage = '请输入主密码';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final isValid = await widget.controller.verifyMasterPassword(password);
      if (!mounted) return;

      if (isValid) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _errorMessage = '主密码错误，请重新输入';
          _passwordController.clear();
        });
        _focusNode.requestFocus();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '验证异常: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF21252B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFF3E4451)),
      ),
      title: const Row(
        children: [
          Icon(VaultIcons.shield, color: Colors.blueAccent, size: 22),
          SizedBox(width: 8),
          Text(
            '管理权限验证',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '进入账号库管理后台需验证主密码',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            ),
            const SizedBox(height: 14),
            if (_errorMessage != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(VaultIcons.error, color: Colors.redAccent, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            TextField(
              controller: _passwordController,
              focusNode: _focusNode,
              autofocus: true,
              obscureText: _obscurePassword,
              enabled: !_isVerifying,
              style: const TextStyle(fontSize: 14, color: Colors.white),
              decoration: InputDecoration(
                hintText: '输入主密码',
                hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                prefixIcon: const Icon(
                  VaultIcons.password,
                  size: 18,
                  color: Colors.grey,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? VaultIcons.eyeOff : VaultIcons.eye,
                    size: 18,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
                filled: true,
                fillColor: const Color(0xFF282C34),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF3E4451)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
                ),
              ),
              onSubmitted: (_) => _handleVerify(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isVerifying ? null : () => Navigator.of(context).pop(false),
          child: Text('取消', style: TextStyle(color: Colors.grey.shade400)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _isVerifying ? null : _handleVerify,
          child: _isVerifying
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('验 证', style: TextStyle(fontSize: 13)),
        ),
      ],
    );
  }
}
