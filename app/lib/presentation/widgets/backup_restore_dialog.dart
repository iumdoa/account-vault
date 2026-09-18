import 'dart:io';

import 'package:flutter/material.dart';

import '../../application/vault_session_controller.dart';
import '../../infrastructure/crypto/vault_crypto_types.dart';
import '../../platform/native_dialog_service.dart';

class BackupRestoreDialog extends StatefulWidget {
  final VaultSessionController controller;

  const BackupRestoreDialog({super.key, required this.controller});

  static Future<void> show(
    BuildContext context, {
    required VaultSessionController controller,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => BackupRestoreDialog(controller: controller),
    );
  }

  @override
  State<BackupRestoreDialog> createState() => _BackupRestoreDialogState();
}

class _BackupRestoreDialogState extends State<BackupRestoreDialog> {
  final TextEditingController _pathController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _errorMessage;
  bool _isProcessing = false;
  DecryptedVaultPayload? _previewPayload;

  @override
  void dispose() {
    _pathController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleBrowse() async {
    final selected = await NativeDialogService.pickOpenFile();
    if (selected != null && mounted) {
      setState(() {
        _pathController.text = selected;
        _previewPayload = null;
        _errorMessage = null;
      });
    }
  }

  Future<void> _handlePreview() async {
    final path = _pathController.text.trim();
    final password = _passwordController.text;

    if (path.isEmpty) {
      setState(() {
        _errorMessage = '请选择或输入备份文件路径';
      });
      return;
    }

    final file = File(path);
    if (!file.existsSync()) {
      setState(() {
        _errorMessage = '所选备份文件不存在';
      });
      return;
    }

    if (password.isEmpty) {
      setState(() {
        _errorMessage = '请输入该备份文件的主密码';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _previewPayload = null;
    });

    final payload = await widget.controller.previewBackup(
      backupFile: file,
      masterPassword: password,
    );

    if (mounted) {
      setState(() {
        _isProcessing = false;
        _previewPayload = payload;
        if (payload == null) {
          _errorMessage = widget.controller.errorMessage ?? '解密预览失败';
        }
      });
    }
  }

  Future<void> _handleRestore() async {
    if (_previewPayload == null) {
      await _handlePreview();
      if (_previewPayload == null) return;
    }

    final file = File(_pathController.text.trim());
    final password = _passwordController.text;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    final result = await widget.controller.restoreFromBackup(
      backupFile: file,
      masterPassword: password,
    );

    if (mounted) {
      if (result.success) {
        Navigator.of(context).pop();
        if (result.safetyBackupFile != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '整库恢复完成！恢复前副本已备份至: ${result.safetyBackupFile!.path}',
                style: const TextStyle(fontSize: 12),
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        setState(() {
          _isProcessing = false;
          _errorMessage = widget.controller.errorMessage ?? '恢复失败';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF21252B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF3E4451)),
      ),
      title: const Row(
        children: [
          Icon(
            Icons.settings_backup_restore,
            color: Colors.amberAccent,
            size: 22,
          ),
          SizedBox(width: 8),
          Text('从备份整库恢复', style: TextStyle(color: Colors.white, fontSize: 16)),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '选择一个有效的 .avlt 加密备份文件，验证密码后进行整库替换。现有库将在替换前自动生成安全备份。',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900.withAlpha(50),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.red.shade700.withAlpha(120),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 16,
                        color: Colors.red.shade300,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Colors.red.shade200,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Backup file path input
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _pathController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: '备份文件路径 (.avlt)',
                        labelStyle: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 12,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF1E2227),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFF3E4451),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFF3E4451),
                          ),
                        ),
                      ),
                      onChanged: (_) => setState(() => _previewPayload = null),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _isProcessing ? null : _handleBrowse,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Color(0xFF3E4451)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                    child: const Text('浏览...'),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Backup password
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: '备份文件的主密码',
                  labelStyle: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 12,
                  ),
                  filled: true,
                  fillColor: const Color(0xFF1E2227),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.grey,
                      size: 16,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF3E4451)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF3E4451)),
                  ),
                ),
                onChanged: (_) => setState(() => _previewPayload = null),
              ),
              const SizedBox(height: 12),

              // Preview button
              if (_previewPayload == null) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _isProcessing ? null : _handlePreview,
                    icon: const Icon(Icons.search, size: 16),
                    label: const Text('检查并预览备份内容'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blueAccent,
                      side: const BorderSide(color: Colors.blueAccent),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
              ],

              // Preview Result Card
              if (_previewPayload != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade900.withAlpha(40),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.green.shade600.withAlpha(100),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            color: Colors.greenAccent,
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Text(
                            '备份验证成功！快照概要：',
                            style: TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '• 凭据记录数: ${_previewPayload!.entries.length} 条\n'
                        '• 快照版本号: #${_previewPayload!.revision}\n'
                        '• 库 UUID: ${_previewPayload!.vaultId}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade900.withAlpha(40),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.amber.shade600.withAlpha(100),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.amberAccent,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '恢复后主密码将变更为该备份文件的密码！当前库将备份为独立文件保存在数据目录。',
                          style: TextStyle(
                            color: Colors.amber.shade200,
                            fontSize: 11,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
          child: Text('取消', style: TextStyle(color: Colors.grey.shade400)),
        ),
        if (_previewPayload != null)
          FilledButton(
            onPressed: _isProcessing ? null : _handleRestore,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: _isProcessing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('确认整库恢复'),
          ),
      ],
    );
  }
}
