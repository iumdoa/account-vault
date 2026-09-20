import 'dart:io';

import 'package:flutter/material.dart';

import 'package:path/path.dart' as p;

import '../../application/vault_session_controller.dart';
import '../../infrastructure/storage/vault_path_provider.dart';
import '../../platform/native_dialog_service.dart';
import 'vault_icons.dart';

class BackupExportDialog extends StatefulWidget {
  final VaultSessionController controller;

  const BackupExportDialog({super.key, required this.controller});

  static Future<void> show(
    BuildContext context, {
    required VaultSessionController controller,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => BackupExportDialog(controller: controller),
    );
  }

  @override
  State<BackupExportDialog> createState() => _BackupExportDialogState();
}

class _BackupExportDialogState extends State<BackupExportDialog> {
  late final TextEditingController _pathController;
  String? _errorMessage;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    final defaultDir = VaultPathProvider.resolveDefaultBackupDirectory();
    final defaultFilename = VaultPathProvider.generateBackupFilename();
    _pathController = TextEditingController(
      text: p.join(defaultDir.path, defaultFilename),
    );
  }

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _handleBrowse() async {
    final defaultFilename = VaultPathProvider.generateBackupFilename();
    final currentDir = Directory(_pathController.text).parent.path;
    final selected = await NativeDialogService.pickSaveFile(
      defaultFilename: defaultFilename,
      initialDirectory: currentDir,
    );
    if (selected != null && mounted) {
      setState(() {
        _pathController.text = selected;
      });
    }
  }

  Future<void> _handleExport() async {
    final targetPath = _pathController.text.trim();
    if (targetPath.isEmpty) {
      setState(() {
        _errorMessage = '导出路径不能为空';
      });
      return;
    }

    setState(() {
      _isExporting = true;
      _errorMessage = null;
    });

    final targetFile = File(targetPath);
    final success = await widget.controller.exportBackup(targetFile);

    if (mounted) {
      if (success) {
        Navigator.of(context).pop();
      } else {
        setState(() {
          _isExporting = false;
          _errorMessage = widget.controller.errorMessage ?? '导出失败';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final entryCount = widget.controller.allEntries.length;

    return AlertDialog(
      backgroundColor: const Color(0xFF21252B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF3E4451)),
      ),
      title: const Row(
        children: [
          Icon(VaultIcons.export, color: Colors.blueAccent, size: 22),
          SizedBox(width: 8),
          Text('导出加密备份', style: TextStyle(color: Colors.white, fontSize: 16)),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '将当前密码库全部凭据（共 $entryCount 条）导出为独立的加密备份文件 (.avlt)。备份使用当前主密码解锁。',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
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
                        VaultIcons.error,
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
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _pathController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: '导出文件目标路径',
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
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _isExporting ? null : _handleBrowse,
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
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isExporting ? null : () => Navigator.of(context).pop(),
          child: Text('取消', style: TextStyle(color: Colors.grey.shade400)),
        ),
        FilledButton(
          onPressed: _isExporting ? null : _handleExport,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF1E88E5),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: _isExporting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('导出'),
        ),
      ],
    );
  }
}
