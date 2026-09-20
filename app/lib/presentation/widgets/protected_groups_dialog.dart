import 'package:flutter/material.dart';

import '../../application/vault_session_controller.dart';
import 'vault_icons.dart';

/// Modal dialog for configuring protected / locked groups
class ProtectedGroupsDialog extends StatefulWidget {
  final VaultSessionController controller;

  const ProtectedGroupsDialog({super.key, required this.controller});

  static Future<bool> show(
    BuildContext context, {
    required VaultSessionController controller,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ProtectedGroupsDialog(controller: controller),
    );
    return result ?? false;
  }

  @override
  State<ProtectedGroupsDialog> createState() => _ProtectedGroupsDialogState();
}

class _ProtectedGroupsDialogState extends State<ProtectedGroupsDialog> {
  late Set<String> _selectedProtectedGroups;
  late Set<String> _allGroups;
  final TextEditingController _newGroupController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedProtectedGroups = Set<String>.from(widget.controller.protectedGroups);
    _allGroups = Set<String>.from(widget.controller.availableGroups);
    _allGroups.addAll(_selectedProtectedGroups);
  }

  @override
  void dispose() {
    _newGroupController.dispose();
    super.dispose();
  }

  void _addNewGroup() {
    final name = _newGroupController.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _allGroups.add(name);
      _selectedProtectedGroups.add(name);
      _newGroupController.clear();
    });
  }

  int _getEntryCountForGroup(String group) {
    return widget.controller.allEntries.where((e) => e.group == group).length;
  }

  Future<void> _handleSave() async {
    setState(() {
      _isSaving = true;
    });

    try {
      await widget.controller.updateProtectedGroups(_selectedProtectedGroups);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sortedGroups = _allGroups.toList()..sort();

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
          Expanded(
            child: Text(
              '分组安全保护设置',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '开启保护的分组在快捷面板中默认隐藏，防止未授权查看。仅在点击对应标签并验证主密码后才可临时访问。',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 12),
            // Add custom group row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newGroupController,
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                    decoration: InputDecoration(
                      hintText: '添加新保护分组名称...',
                      hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      isDense: true,
                      filled: true,
                      fillColor: const Color(0xFF282C34),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: Color(0xFF3E4451)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: Colors.blueAccent),
                      ),
                    ),
                    onSubmitted: (_) => _addNewGroup(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3E4451),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: _addNewGroup,
                  child: const Text('添加', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: Color(0xFF3E4451), height: 1),
            const SizedBox(height: 8),
            // Groups list
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: sortedGroups.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          '暂无任何可用分组',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: sortedGroups.length,
                      separatorBuilder: (_, _) => const Divider(
                        color: Color(0xFF282C34),
                        height: 1,
                      ),
                      itemBuilder: (context, index) {
                        final group = sortedGroups[index];
                        final isProtected = _selectedProtectedGroups.contains(group);
                        final count = _getEntryCountForGroup(group);

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                          child: Row(
                            children: [
                              Icon(
                                isProtected ? VaultIcons.lock : VaultIcons.list,
                                size: 16,
                                color: isProtected ? Colors.amberAccent : Colors.grey,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  group,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '$count 条记录',
                                  style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Transform.scale(
                                scale: 0.8,
                                child: Switch.adaptive(
                                  value: isProtected,
                                  activeTrackColor: Colors.blueAccent,
                                  onChanged: (val) {
                                    setState(() {
                                      if (val) {
                                        _selectedProtectedGroups.add(group);
                                      } else {
                                        _selectedProtectedGroups.remove(group);
                                      }
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: Text('取消', style: TextStyle(color: Colors.grey.shade400)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _isSaving ? null : _handleSave,
          child: _isSaving
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('保存设置', style: TextStyle(fontSize: 13)),
        ),
      ],
    );
  }
}
