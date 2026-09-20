import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/models/vault_entry.dart';
import '../domain/repositories/vault_repository.dart';
import '../domain/services/entry_search_service.dart';
import '../infrastructure/crypto/vault_crypto_types.dart';
import '../infrastructure/storage/encrypted_file_vault_repository.dart';

/// Lifecycle state of the vault session
enum VaultSessionState { initializing, uninitialized, locked, unlocked }

/// Application controller managing vault entries, search state, keyboard navigation,
/// clipboard interactions, and vault encryption lifecycle (create, unlock, lock).
class VaultSessionController extends ChangeNotifier {
  final VaultRepository repository;
  final bool isMockMode;

  VaultSessionState _state = VaultSessionState.initializing;
  List<VaultEntry> _allEntries = [];
  List<VaultEntry> _filteredEntries = [];
  String _currentQuery = '';
  String? _selectedGroup;
  int _selectedIndex = 0;
  bool _isLoading = false;
  bool _isBusy = false;
  String? _feedbackMessage;
  String? _errorMessage;
  bool _hasPreviousBackup = false;

  VaultSessionController({required this.repository, this.isMockMode = true}) {
    if (isMockMode) {
      _state = VaultSessionState.unlocked;
    }
  }

  VaultSessionState get state => _state;
  bool get isUnlocked => _state == VaultSessionState.unlocked;
  bool get isLocked => _state == VaultSessionState.locked;
  bool get isUninitialized => _state == VaultSessionState.uninitialized;
  bool get isBusy => _isBusy;
  String? get errorMessage => _errorMessage;
  bool get hasPreviousBackup => _hasPreviousBackup;

  EncryptedFileVaultRepository? get _encryptedRepo =>
      repository is EncryptedFileVaultRepository
      ? (repository as EncryptedFileVaultRepository)
      : null;

  String? get vaultPath => _encryptedRepo?.pathProvider.mainVaultFile.path;
  int get revision => _encryptedRepo?.revision ?? 0;

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

  /// Initial check for repository status
  Future<void> initialize() async {
    if (isMockMode || _encryptedRepo == null) {
      _state = VaultSessionState.unlocked;
      await loadEntries();
      return;
    }

    _isLoading = true;
    _state = VaultSessionState.initializing;
    notifyListeners();

    try {
      final exists = await _encryptedRepo!.vaultExists();
      _hasPreviousBackup = await _encryptedRepo!.previousExists();
      if (exists) {
        _state = VaultSessionState.locked;
      } else {
        _state = VaultSessionState.uninitialized;
      }
    } catch (e) {
      _state = VaultSessionState.uninitialized;
      _errorMessage = '初始化检查失败: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Creates a new vault with master password
  Future<bool> createVault({
    required String masterPassword,
    required String confirmPassword,
  }) async {
    if (masterPassword.isEmpty) {
      _errorMessage = '主密码不能为空';
      notifyListeners();
      return false;
    }

    if (masterPassword != confirmPassword) {
      _errorMessage = '两次输入的密码不一致';
      notifyListeners();
      return false;
    }

    if (masterPassword.length < 6) {
      _errorMessage = '主密码长度至少需要 6 个字符';
      notifyListeners();
      return false;
    }

    if (_encryptedRepo == null) {
      _state = VaultSessionState.unlocked;
      notifyListeners();
      return true;
    }

    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _encryptedRepo!.createVault(masterPassword: masterPassword);
      _hasPreviousBackup = await _encryptedRepo!.previousExists();
      _state = VaultSessionState.unlocked;
      await loadEntries();
      _setFeedback('密码库已初始化并就绪');
      return true;
    } catch (e) {
      _errorMessage = '创建密码库失败: $e';
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  /// Unlocks vault using master password
  Future<bool> unlock(String masterPassword) async {
    if (masterPassword.isEmpty) {
      _errorMessage = '请输入主密码';
      notifyListeners();
      return false;
    }

    if (_encryptedRepo == null) {
      _state = VaultSessionState.unlocked;
      notifyListeners();
      return true;
    }

    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final entries = await _encryptedRepo!.unlock(
        masterPassword: masterPassword,
      );
      _hasPreviousBackup = await _encryptedRepo!.previousExists();
      _allEntries = entries;
      _applyFilter();
      _state = VaultSessionState.unlocked;
      _setFeedback('密码库已解锁');
      return true;
    } on AuthenticationFailedException {
      _errorMessage = '主密码错误，请重新输入';
      return false;
    } on CorruptedFormatException catch (e) {
      _errorMessage = '密码库文件格式损坏: ${e.message}';
      return false;
    } catch (e) {
      _errorMessage = '解锁失败: $e';
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  /// Verifies master password against the current active vault session
  Future<bool> verifyMasterPassword(String password) async {
    if (password.isEmpty) return false;
    if (isMockMode) {
      // In mock mode (tests/previews), accept any non-empty password
      return true;
    }
    if (_encryptedRepo == null) return false;
    return await _encryptedRepo!.verifyMasterPassword(password);
  }

  /// Restores vault from vault.previous.avlt
  Future<bool> restoreFromPrevious(String masterPassword) async {
    if (_encryptedRepo == null) return false;

    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _encryptedRepo!.restoreFromPrevious(masterPassword);
      _hasPreviousBackup = await _encryptedRepo!.previousExists();
      _state = VaultSessionState.unlocked;
      await loadEntries();
      _setFeedback('已成功从回退备份恢复密码库');
      return true;
    } on AuthenticationFailedException {
      _errorMessage = '主密码错误，无法解密回退备份';
      return false;
    } catch (e) {
      _errorMessage = '从回退备份恢复失败: $e';
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  /// Closes the session and clears memory references
  void lock() {
    _encryptedRepo?.lock();
    _state = VaultSessionState.locked;
    _allEntries = [];
    _filteredEntries = [];
    _currentQuery = '';
    _selectedIndex = 0;
    _errorMessage = null;
    notifyListeners();
  }

  /// Exports verified encrypted backup to destination file (README Section 9.1)
  Future<bool> exportBackup(File destinationFile) async {
    if (_encryptedRepo == null) return false;

    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _encryptedRepo!.exportBackup(destinationFile);
      _setFeedback('已成功导出加密备份至: ${destinationFile.path}');
      return true;
    } catch (e) {
      _errorMessage = '导出备份失败: $e';
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  /// Previews an external backup file
  Future<DecryptedVaultPayload?> previewBackup({
    required File backupFile,
    required String masterPassword,
  }) async {
    if (_encryptedRepo == null) return null;

    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      return await _encryptedRepo!.previewBackup(
        backupFile: backupFile,
        masterPassword: masterPassword,
      );
    } on AuthenticationFailedException {
      _errorMessage = '备份密码错误，无法解密该备份文件';
      return null;
    } on CorruptedFormatException catch (e) {
      _errorMessage = '备份文件校验失败: ${e.message}';
      return null;
    } catch (e) {
      _errorMessage = '预览备份失败: $e';
      return null;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  /// Restores from external backup file (README Section 9.2)
  Future<({bool success, File? safetyBackupFile})> restoreFromBackup({
    required File backupFile,
    required String masterPassword,
  }) async {
    if (_encryptedRepo == null) return (success: false, safetyBackupFile: null);

    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final safetyFile = await _encryptedRepo!.restoreFromBackup(
        backupFile: backupFile,
        masterPassword: masterPassword,
      );
      _hasPreviousBackup = await _encryptedRepo!.previousExists();
      _state = VaultSessionState.unlocked;
      _currentQuery = '';
      _selectedIndex = 0;
      await loadEntries();
      _setFeedback('已成功从备份恢复！当前主密码已切换为此备份的密码');
      return (success: true, safetyBackupFile: safetyFile);
    } on AuthenticationFailedException {
      _errorMessage = '备份密码错误，无法解密该备份文件';
      return (success: false, safetyBackupFile: null);
    } catch (e) {
      _errorMessage = '恢复备份失败: $e';
      return (success: false, safetyBackupFile: null);
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
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

    try {
      await repository.save(toSave);
      await loadEntries();
      _setFeedback('已保存记录: ${toSave.title}');
      return ValidationResult.success();
    } catch (e) {
      return ValidationResult.failure({'storage': '保存到加密库失败: $e'});
    }
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
