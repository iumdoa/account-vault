import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/vault_session_controller.dart';
import '../../domain/models/vault_entry.dart';
import 'backup_export_dialog.dart';
import 'backup_restore_dialog.dart';
import 'entry_form_dialog.dart';
import 'copy_icon.dart';
import 'settings_dialog.dart';
import 'vault_icons.dart';

/// Full Management View (README Section 3.3)
class ManagementView extends StatelessWidget {
  final VaultSessionController controller;
  final VoidCallback onBackToQuickPanel;
  final VoidCallback onQuitApp;

  const ManagementView({
    super.key,
    required this.controller,
    required this.onBackToQuickPanel,
    required this.onQuitApp,
  });

  void _confirmDelete(BuildContext context, VaultEntry entry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF21252B),
        title: const Text(
          '确认删除记录',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: Text(
          '确定要删除记录「${entry.title}」吗？\n删除后不可恢复。',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('取消', style: TextStyle(color: Colors.grey.shade400)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade900,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await controller.deleteEntry(entry.id);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = controller.availableGroups;

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.keyN &&
            HardwareKeyboard.instance.isControlPressed) {
          EntryFormDialog.show(context, controller: controller);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Navigation Header
          Row(
            children: [
              IconButton(
                icon: const Icon(VaultIcons.back, color: Colors.blueAccent),
                tooltip: '返回快捷面板',
                onPressed: onBackToQuickPanel,
              ),
            const Text(
              '账号库管理',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '共 ${controller.allEntries.length} 条记录',
                style: const TextStyle(color: Colors.blueAccent, fontSize: 11),
              ),
            ),
            if (!controller.isMockMode && controller.revision > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '版本 #${controller.revision}',
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
            const Spacer(),
            if (!controller.isMockMode) ...[
              IconButton(
                icon: const Icon(
                  VaultIcons.export,
                  color: VaultIcons.muted,
                  size: 20,
                ),
                tooltip: '导出加密备份',
                onPressed: () =>
                    BackupExportDialog.show(context, controller: controller),
              ),
              IconButton(
                icon: const Icon(
                  VaultIcons.restore,
                  color: VaultIcons.muted,
                  size: 20,
                ),
                tooltip: '从备份整库恢复',
                onPressed: () =>
                    BackupRestoreDialog.show(context, controller: controller),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(
                  VaultIcons.lock,
                  color: VaultIcons.muted,
                  size: 20,
                ),
                tooltip: '锁定密码库',
                onPressed: () {
                  controller.lock();
                  onBackToQuickPanel();
                },
              ),
            ],
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(
                VaultIcons.settings,
                color: VaultIcons.muted,
                size: 20,
              ),
              tooltip: '偏好设置与快捷键',
              onPressed: () => SettingsDialog.show(context),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(
                VaultIcons.power,
                color: VaultIcons.danger,
                size: 20,
              ),
              tooltip: '退出程序',
              onPressed: onQuitApp,
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Filter Bar (Group Filter + Search)
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                style: const TextStyle(fontSize: 13, color: Colors.white),
                decoration: InputDecoration(
                  hintText: '筛选搜索...',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                  prefixIcon: const Icon(
                    VaultIcons.search,
                    size: 18,
                    color: Colors.grey,
                  ),
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFF21252B),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF3E4451)),
                  ),
                ),
                onChanged: (v) => controller.setQuery(v),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF21252B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF3E4451)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    icon: const Icon(
                      VaultIcons.chevronDown,
                      size: 16,
                      color: VaultIcons.muted,
                    ),
                    value: controller.selectedGroup,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF21252B),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    hint: Text(
                      '全部分组',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 12,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('全部分组', style: TextStyle(fontSize: 12)),
                      ),
                      ...groups.map(
                        (g) => DropdownMenuItem<String?>(
                          value: g,
                          child: Text(g, style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                    onChanged: (val) => controller.setGroupFilter(val),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              icon: const Icon(VaultIcons.add, size: 16),
              label: const Text(
                '新建账号',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () =>
                  EntryFormDialog.show(context, controller: controller),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Entries List
        Expanded(
          child: controller.filteredEntries.isEmpty
              ? Center(
                  child: Text(
                    '没有匹配的账号记录',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  ),
                )
              : ListView.builder(
                  itemCount: controller.filteredEntries.length,
                  itemBuilder: (context, index) {
                    final entry = controller.filteredEntries[index];
                    return _ManagementItemCard(
                      entry: entry,
                      onEdit: () => EntryFormDialog.show(
                        context,
                        controller: controller,
                        entry: entry,
                      ),
                      onDelete: () => _confirmDelete(context, entry),
                      onCopyAccount: () => controller.copyUsername(entry),
                      onCopyPassword: () => controller.copyPassword(entry),
                    );
                  },
                ),
        ),
      ],
    ),
  );
}
}

class _ManagementItemCard extends StatefulWidget {
  final VaultEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onCopyAccount;
  final VoidCallback onCopyPassword;

  const _ManagementItemCard({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
    required this.onCopyAccount,
    required this.onCopyPassword,
  });

  @override
  State<_ManagementItemCard> createState() => _ManagementItemCardState();
}

class _ManagementItemCardState extends State<_ManagementItemCard> {
  bool _revealPassword = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final hasUsername = entry.username != null && entry.username!.isNotEmpty;
    final hasPassword = entry.password != null && entry.password!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF21252B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2C313A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                entry.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              if (entry.group != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C313A),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    entry.group!,
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
                  ),
                ),
              const Spacer(),
              IconButton(
                icon: const Icon(
                  VaultIcons.edit,
                  size: 18,
                  color: VaultIcons.muted,
                ),
                tooltip: '编辑',
                onPressed: widget.onEdit,
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                icon: const Icon(
                  VaultIcons.delete,
                  size: 18,
                  color: VaultIcons.danger,
                ),
                tooltip: '删除',
                onPressed: widget.onDelete,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 6),

          if (entry.address != null && entry.address!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(VaultIcons.link, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    entry.address!,
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                  ),
                ],
              ),
            ),

          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              if (hasUsername)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      VaultIcons.person,
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '账号: ${entry.username!}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    IconButton(
                      icon: const CopyIcon(),
                      color: VaultIcons.muted,
                      tooltip: '复制账号',
                      onPressed: widget.onCopyAccount,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              if (hasPassword)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      VaultIcons.password,
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _revealPassword
                          ? '密码: ${entry.password!}'
                          : '密码: ••••••••',
                      style: TextStyle(
                        color: _revealPassword
                            ? Colors.amberAccent
                            : Colors.white70,
                        fontSize: 12,
                        fontFamily: _revealPassword ? 'monospace' : null,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _revealPassword ? VaultIcons.eyeOff : VaultIcons.eye,
                        size: 16,
                        color: VaultIcons.muted,
                      ),
                      tooltip: _revealPassword ? '隐藏密码' : '临时显示密码',
                      onPressed: () {
                        setState(() {
                          _revealPassword = !_revealPassword;
                        });
                      },
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      icon: const CopyIcon(),
                      color: VaultIcons.muted,
                      tooltip: '复制密码',
                      onPressed: widget.onCopyPassword,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
            ],
          ),

          if (entry.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 4,
                children: entry.tags
                    .map(
                      (t) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF282C34),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          '#$t',
                          style: TextStyle(
                            color: Colors.blue.shade200,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}
