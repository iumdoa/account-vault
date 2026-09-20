import '../models/vault_entry.dart';

/// Abstract repository interface for credential entries
abstract class VaultRepository {
  Future<List<VaultEntry>> getAll();
  Future<VaultEntry?> getById(String id);
  Future<void> save(VaultEntry entry);
  Future<void> delete(String id);
  Set<String> get protectedGroups;
  Future<void> setProtectedGroups(Set<String> groups);
}
