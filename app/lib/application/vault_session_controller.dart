import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/models/vault_entry.dart';
import '../domain/repositories/vault_repository.dart';
import '../domain/services/entry_search_service.dart';

/// Application controller managing vault entries, search state, keyboard navigation,
/// and clipboard interactions.
class VaultSessionController extends ChangeNotifier {
  final VaultRepository repository;
  final bool isMockMode;

  List<VaultEntry> _allEntries = [];
  List<VaultEntry> _filteredEntries = [];
  String _currentQuery = '';
  String? _selectedGroup;
  int _selectedIndex = 0;
  bool _isLoading = false;
  String? _feedbackMessage;

  VaultSessionController({required this.repository, this.isMockMode = true});

  List<VaultEntry> get allEntries => List.unmodifiable(_allEntries);
  List<VaultEntry> get filteredEntries => List.unmodifiable(_filteredEntries);
  String get currentQuery => _currentQuery;
  String? get selectedGroup => _selectedGroup;
  int get selectedIndex => _selectedIndex;
  bool get isLoading => _isLoading;
  String? get feedbackMessage => _feedbackMessage;

  VaultEntry? get selectedEntry {
    if (_filteredEntries.isEmpty ||
        _selectedIndex < 0 ||
        _selectedIndex >= _filteredEntries.length) {
      return null;
    }
    return _filteredEntries[_selectedIndex];
  }

  List<String> get availableGroups {
    final groups = <String>{};
    for (final entry in _allEntries) {
      if (entry.group != null && entry.group!.trim().isNotEmpty) {
        groups.add(entry.group!.trim());
      }
    }
    final list = groups.toList()..sort();
    return list;
  }

  /// Loads all entries from repository
  Future<void> loadEntries() async {
    _isLoading = true;
    notifyListeners();

    try {
      _allEntries = await repository.getAll();
      _applyFilter();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sets search query and re-runs pure search
  void setQuery(String query) {
    if (_currentQuery == query) return;
    _currentQuery = query;
    _selectedIndex = 0; // Reset selection on query change
    _applyFilter();
    notifyListeners();
  }

  /// Filters by group in management view
  void setGroupFilter(String? group) {
    if (_selectedGroup == group) return;
    _selectedGroup = group;
    _selectedIndex = 0;
    _applyFilter();
    notifyListeners();
  }

  /// Moves keyboard selection down
  void selectNext() {
    if (_filteredEntries.isEmpty) return;
    if (_selectedIndex < _filteredEntries.length - 1) {
      _selectedIndex++;
      notifyListeners();
    }
  }

  /// Moves keyboard selection up
  void selectPrevious() {
    if (_filteredEntries.isEmpty) return;
    if (_selectedIndex > 0) {
      _selectedIndex--;
      notifyListeners();
    }
  }

  void selectIndex(int index) {
    if (index >= 0 && index < _filteredEntries.length) {
      _selectedIndex = index;
      notifyListeners();
    }
  }

  /// Copies password to clipboard without trimming or modifying
  Future<bool> copyPassword(VaultEntry entry) async {
    if (entry.password == null || entry.password!.isEmpty) {
      _setFeedback('该记录无密码');
      return false;
    }

    try {
      await Clipboard.setData(ClipboardData(text: entry.password!));
      _setFeedback('已复制密码');
      return true;
    } catch (e) {
      _setFeedback('复制失败: $e');
      return false;
    }
  }

  /// Copies username to clipboard without trimming or modifying
  Future<bool> copyUsername(VaultEntry entry) async {
    if (entry.username == null || entry.username!.isEmpty) {
      _setFeedback('该记录无账号');
      return false;
    }

    try {
      await Clipboard.setData(ClipboardData(text: entry.username!));
      _setFeedback('已复制账号');
      return true;
    } catch (e) {
      _setFeedback('复制失败: $e');
      return false;
    }
  }

  /// Saves an entry after validating
  Future<ValidationResult> saveEntry(VaultEntry entry) async {
    final validation = VaultEntryValidator.validate(
      title: entry.title,
      address: entry.address,
      username: entry.username,
      password: entry.password,
      group: entry.group,
      tags: entry.tags,
      notes: entry.notes,
    );

    if (!validation.isValid) {
      return validation;
    }

    // Sanitize non-credential fields
    final sanitized = VaultEntryValidator.sanitize(
      title: entry.title,
      address: entry.address,
      username: entry.username,
      password: entry.password,
      group: entry.group,
      tags: entry.tags,
      notes: entry.notes,
    );

    final toSave = entry.copyWith(
      title: sanitized.title,
      address: sanitized.address,
      username: sanitized.username,
      password: sanitized.password,
      group: sanitized.group,
      tags: sanitized.tags,
      notes: sanitized.notes,
      updatedAt: DateTime.now().toUtc(),
    );

    await repository.save(toSave);
    await loadEntries();
    _setFeedback('已保存记录: ${toSave.title}');
    return ValidationResult.success();
  }

  /// Deletes an entry
  Future<void> deleteEntry(String id) async {
    final entry = await repository.getById(id);
    await repository.delete(id);
    await loadEntries();
    if (entry != null) {
      _setFeedback('已删除记录: ${entry.title}');
    }
  }

  void _applyFilter() {
    List<VaultEntry> candidates = _allEntries;
    if (_selectedGroup != null && _selectedGroup!.isNotEmpty) {
      candidates = candidates.where((e) => e.group == _selectedGroup).toList();
    }

    _filteredEntries = EntrySearchService.search(candidates, _currentQuery);

    if (_selectedIndex >= _filteredEntries.length) {
      _selectedIndex = _filteredEntries.isEmpty
          ? 0
          : _filteredEntries.length - 1;
    }
  }

  void _setFeedback(String message) {
    _feedbackMessage = message;
    notifyListeners();
  }

  void clearFeedback() {
    _feedbackMessage = null;
    notifyListeners();
  }
}
