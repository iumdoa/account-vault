import 'package:flutter/material.dart';

import '../../application/vault_session_controller.dart';
import '../../domain/models/vault_entry.dart';
import '../../domain/services/uuid_service.dart';
import 'vault_icons.dart';

/// Modal dialog for adding or editing a vault entry (Streamlined without redundant notes/tags)
class EntryFormDialog extends StatefulWidget {
  final VaultSessionController controller;
  final VaultEntry? initialEntry;

  const EntryFormDialog({
    super.key,
    required this.controller,
    this.initialEntry,
  });

  static Future<void> show(
    BuildContext context, {
    required VaultSessionController controller,
    VaultEntry? entry,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) =>
          EntryFormDialog(controller: controller, initialEntry: entry),
    );
  }

  @override
  State<EntryFormDialog> createState() => _EntryFormDialogState();
}

class _EntryFormDialogState extends State<EntryFormDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _addressController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _groupController;

  bool _obscurePassword = true;
  bool _isCustomGroup = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final e = widget.initialEntry;
    _titleController = TextEditingController(text: e?.title ?? '');
    _addressController = TextEditingController(text: e?.address ?? '');
    _usernameController = TextEditingController(text: e?.username ?? '');
    _passwordController = TextEditingController(text: e?.password ?? '');
    final initialGroup = e?.group ?? '';
    _groupController = TextEditingController(text: initialGroup);
    if (initialGroup.isNotEmpty &&
        !widget.controller.availableGroups.contains(initialGroup)) {
      _isCustomGroup = true;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _addressController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _groupController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    setState(() {
      _errorMessage = null;
    });

    final entryToSave = VaultEntry(
      id: widget.initialEntry?.id ?? UuidService.generateV4(),
      title: _titleController.text,
      address: _addressController.text.trim().isEmpty
          ? null
          : _addressController.text,
      username: _usernameController.text.isEmpty
          ? null
          : _usernameController.text,
      password: _passwordController.text.isEmpty
          ? null
          : _passwordController.text,
      group: _groupController.text.trim().isEmpty
          ? null
          : _groupController.text.trim(),
      tags: widget.initialEntry?.tags ?? const [],
      notes: widget.initialEntry?.notes,
      createdAt: widget.initialEntry?.createdAt,
      updatedAt: DateTime.now().toUtc(),
    );

    final result = await widget.controller.saveEntry(entryToSave);
    if (!result.isValid) {
      setState(() {
        _errorMessage = result.firstErrorMessage ?? '输入数据未通过校验';
      });
      return;
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialEntry != null;
    final availableGroups = widget.controller.availableGroups;

    return AlertDialog(
      backgroundColor: const Color(0xFF21252B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFF3E4451)),
      ),
      title: Row(
        children: [
          Icon(
            isEditing ? VaultIcons.edit : VaultIcons.add,
            color: Colors.blueAccent,
            size: 24,
          ),
          const SizedBox(width: 8),
          Text(
            isEditing ? '编辑账号记录' : '新增账号记录',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.redAccent),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        VaultIcons.error,
                        color: Colors.redAccent,
                        size: 16,
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

              // Title (Required)
              _buildTextField(
                controller: _titleController,
                label: '标题 (必填)',
                hint: '例如：GitHub 个人账号 / 核心交换机',
                autofocus: true,
              ),
              const SizedBox(height: 12),

              // Group and Address
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _isCustomGroup
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '新建分组',
                                    style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const Spacer(),
                                  InkWell(
                                    onTap: () {
                                      setState(() {
                                        _isCustomGroup = false;
                                        _groupController.clear();
                                      });
                                    },
                                    child: const Text(
                                      '返回下拉',
                                      style: TextStyle(
                                        color: Colors.blueAccent,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _groupController,
                                autofocus: true,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.white,
                                ),
                                decoration: InputDecoration(
                                  hintText: '输入新分组名称',
                                  hintStyle: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                  isDense: true,
                                  filled: true,
                                  fillColor: const Color(0xFF282C34),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
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
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '分组 (可选)',
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 6),
                              PopupMenuButton<String?>(
                                tooltip: '选择分组',
                                position: PopupMenuPosition.under,
                                offset: const Offset(0, 4),
                                color: const Color(0xFF21252B),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: const BorderSide(
                                    color: Color(0xFF3E4451),
                                  ),
                                ),
                                elevation: 8,
                                onSelected: (val) {
                                  if (val == '__custom__') {
                                    setState(() {
                                      _isCustomGroup = true;
                                      _groupController.clear();
                                    });
                                  } else {
                                    setState(() {
                                      _groupController.text = val ?? '';
                                    });
                                  }
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem<String?>(
                                    value: null,
                                    height: 36,
                                    child: Row(
                                      children: [
                                        Text(
                                          '无分组',
                                          style: TextStyle(
                                            color: _groupController.text
                                                    .trim()
                                                    .isEmpty
                                                ? Colors.blueAccent
                                                : Colors.white,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const Spacer(),
                                        if (_groupController.text
                                            .trim()
                                            .isEmpty)
                                          const Icon(
                                            VaultIcons.check,
                                            size: 14,
                                            color: Colors.blueAccent,
                                          ),
                                      ],
                                    ),
                                  ),
                                  ...availableGroups.map(
                                    (g) {
                                      final isProtected = widget.controller
                                          .isGroupProtected(g);
                                      return PopupMenuItem<String?>(
                                        value: g,
                                        height: 36,
                                        child: Row(
                                          children: [
                                            if (isProtected) ...[
                                              const Icon(
                                                VaultIcons.lock,
                                                size: 12,
                                                color: Colors.amberAccent,
                                              ),
                                              const SizedBox(width: 4),
                                            ],
                                            Expanded(
                                              child: Text(
                                                g,
                                                style: TextStyle(
                                                  color: _groupController.text
                                                              .trim() ==
                                                          g
                                                      ? Colors.blueAccent
                                                      : Colors.white,
                                                  fontSize: 12,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (_groupController.text.trim() == g)
                                              const Icon(
                                                VaultIcons.check,
                                                size: 14,
                                                color: Colors.blueAccent,
                                              ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                  const PopupMenuDivider(height: 1),
                                  const PopupMenuItem<String?>(
                                    value: '__custom__',
                                    height: 36,
                                    child: Row(
                                      children: [
                                        Icon(
                                          VaultIcons.add,
                                          size: 14,
                                          color: Colors.blueAccent,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          '新建自定义分组...',
                                          style: TextStyle(
                                            color: Colors.blueAccent,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                child: Container(
                                  height: 38,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF282C34),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFF3E4451),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _groupController.text.trim().isEmpty
                                              ? '无分组'
                                              : _groupController.text.trim(),
                                          style: TextStyle(
                                            color: _groupController.text
                                                    .trim()
                                                    .isEmpty
                                                ? Colors.grey.shade400
                                                : Colors.white,
                                            fontSize: 12,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const Icon(
                                        VaultIcons.chevronDown,
                                        size: 16,
                                        color: VaultIcons.muted,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildTextField(
                      controller: _addressController,
                      label: '网址 / IP / 登录地址 (可选)',
                      hint: 'github.com 或 192.168.1.1',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Username and Password
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _usernameController,
                      label: '账号 / 用户名 (可选)',
                      hint: 'admin 或 user@example.com',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildTextField(
                      controller: _passwordController,
                      label: '密码 (可选)',
                      hint: '输入复杂密码',
                      obscureText: _obscurePassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? VaultIcons.eyeOff : VaultIcons.eye,
                          size: 18,
                          color: Colors.grey.shade400,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('取消', style: TextStyle(color: Colors.grey.shade400)),
        ),
        ElevatedButton.icon(
          icon: const Icon(VaultIcons.check, size: 16),
          label: const Text('保存'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          onPressed: _handleSave,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool autofocus = false,
    bool obscureText = false,
    int maxLines = 1,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade300, fontSize: 12),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          autofocus: autofocus,
          obscureText: obscureText,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 13, color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            filled: true,
            fillColor: const Color(0xFF181A1F),
            suffixIcon: suffixIcon,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF3E4451)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Colors.blueAccent,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
