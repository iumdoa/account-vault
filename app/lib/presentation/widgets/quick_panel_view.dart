import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/vault_session_controller.dart';
import '../../domain/models/vault_entry.dart';
import 'settings_dialog.dart';

/// Quick Search and Copy Panel View (README Section 3.2)
class QuickPanelView extends StatelessWidget {
  final VaultSessionController controller;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final VoidCallback onOpenManagement;
  final VoidCallback onHideWindow;

  const QuickPanelView({
    super.key,
    required this.controller,
    required this.searchController,
    required this.searchFocusNode,
    required this.onOpenManagement,
    required this.onHideWindow,
  });

  void _handleKeyEnter({required bool isCtrl}) async {
    // If Chinese/IME is currently composing, do not intercept Enter!
    if (searchController.value.composing.isValid) {
      return;
    }

    final entry = controller.selectedEntry;
    if (entry == null) return;

    if (isCtrl) {
      // Ctrl+Enter: copy username and keep panel
      await controller.copyUsername(entry);
    } else {
      // Enter: copy password and hide panel
      final success = await controller.copyPassword(entry);
      if (success) {
        onHideWindow();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) {
          return KeyEventResult.ignored;
        }

        // IME composing check
        final isComposing = searchController.value.composing.isValid;

        if (event.logicalKey == LogicalKeyboardKey.arrowDown && !isComposing) {
          controller.selectNext();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowUp &&
            !isComposing) {
          controller.selectPrevious();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.enter &&
            !isComposing) {
          final isCtrl = HardwareKeyboard.instance.isControlPressed;
          _handleKeyEnter(isCtrl: isCtrl);
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.escape) {
          onHideWindow();
          return KeyEventResult.handled;
        }

        return KeyEventResult.ignored;
      },
      child: Column(
        children: [
          // Top Search Input
          TextField(
            controller: searchController,
            focusNode: searchFocusNode,
            autofocus: true,
            style: const TextStyle(fontSize: 15, color: Colors.white),
            decoration: InputDecoration(
              hintText: '搜索标题、IP、网址片段、账号、标签或备注...',
              hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              prefixIcon: const Icon(
                Icons.search,
                color: Colors.blueAccent,
                size: 22,
              ),
              suffixIcon: searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        searchController.clear();
                        controller.setQuery('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFF21252B),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF3E4451)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Colors.blueAccent,
                  width: 2,
                ),
              ),
            ),
            onChanged: (val) {
              controller.setQuery(val);
            },
          ),
          const SizedBox(height: 8),

          // In-memory Phase 1 notice badge
          if (controller.isMockMode)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.amberAccent),
                  SizedBox(width: 6),
                  Text(
                    '阶段 1 内存模式：内置 20 条覆盖设备、网站与应用的虚构凭据，修改不持久化到硬盘',
                    style: TextStyle(color: Colors.amberAccent, fontSize: 11),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),

          // Result List
          Expanded(
            child: controller.filteredEntries.isEmpty
                ? Center(
                    child: Text(
                      controller.currentQuery.isEmpty
                          ? '暂无任何账号记录'
                          : '未找到匹配 "${controller.currentQuery}" 的记录',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 13,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: controller.filteredEntries.length,
                    itemBuilder: (context, index) {
                      final entry = controller.filteredEntries[index];
                      final isSelected = index == controller.selectedIndex;
                      return _EntryListItem(
                        entry: entry,
                        isSelected: isSelected,
                        onTap: () => controller.selectIndex(index),
                        onCopyAccount: () => controller.copyUsername(entry),
                        onCopyPassword: () async {
                          final ok = await controller.copyPassword(entry);
                          if (ok) onHideWindow();
                        },
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),

          // Bottom Bar & Hints
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFF2C313A), width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '↑↓ 切换 · Enter 复制密码 · Ctrl+Enter 复制账号 · Esc 隐藏',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.tune_outlined, size: 16),
                  color: Colors.grey.shade400,
                  tooltip: '快捷键与偏好设置',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => SettingsDialog.show(context),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  icon: const Icon(Icons.table_chart_outlined, size: 16),
                  label: const Text('管理页面', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blueAccent,
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: onOpenManagement,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryListItem extends StatelessWidget {
  final VaultEntry entry;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onCopyAccount;
  final VoidCallback onCopyPassword;

  const _EntryListItem({
    required this.entry,
    required this.isSelected,
    required this.onTap,
    required this.onCopyAccount,
    required this.onCopyPassword,
  });

  @override
  Widget build(BuildContext context) {
    final hasUsername = entry.username != null && entry.username!.isNotEmpty;
    final hasPassword = entry.password != null && entry.password!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.blue.withValues(alpha: 0.18)
            : const Color(0xFF21252B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? Colors.blueAccent : const Color(0xFF2C313A),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // Icon or Group Indicator
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.blueAccent.withValues(alpha: 0.3)
                      : const Color(0xFF282C34),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  _getCategoryIcon(entry),
                  size: 18,
                  color: isSelected ? Colors.white : Colors.blueGrey.shade300,
                ),
              ),
              const SizedBox(width: 12),

              // Title and Credential info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            entry.title,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.grey.shade200,
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (entry.group != null && entry.group!.isNotEmpty) ...[
                          const SizedBox(width: 6),
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
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (entry.address != null &&
                            entry.address!.isNotEmpty) ...[
                          Icon(
                            Icons.link,
                            size: 12,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              entry.address!,
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (hasUsername) ...[
                          Icon(
                            Icons.person_outline,
                            size: 12,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              entry.username!,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.blue.shade100
                                    : Colors.grey.shade400,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Copy Buttons
              if (hasUsername)
                IconButton(
                  tooltip: '复制账号 (Ctrl+Enter)',
                  icon: const Icon(Icons.person_pin_outlined, size: 18),
                  color: isSelected ? Colors.blueAccent : Colors.grey.shade400,
                  onPressed: onCopyAccount,
                ),
              IconButton(
                tooltip: hasPassword ? '复制密码 (Enter)' : '无密码',
                icon: Icon(
                  Icons.key,
                  size: 18,
                  color: hasPassword
                      ? (isSelected ? Colors.greenAccent : Colors.grey.shade400)
                      : Colors.grey.shade700,
                ),
                onPressed: hasPassword ? onCopyPassword : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(VaultEntry entry) {
    final g = (entry.group ?? '').toLowerCase();
    if (g.contains('网络') || g.contains('设备')) {
      return Icons.router;
    } else if (g.contains('开发') || g.contains('工具')) {
      return Icons.code;
    } else if (g.contains('云')) {
      return Icons.cloud_queue;
    } else if (g.contains('数据') || g.contains('存储')) {
      return Icons.storage;
    }
    return Icons.lock_outline;
  }
}
