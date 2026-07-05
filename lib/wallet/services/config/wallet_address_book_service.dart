import '../../../utils/storage.dart';
import '../../models/wallet_address_book_entry.dart';

/// 本地地址簿服务。
class WalletAddressBookService {
  WalletAddressBookService({Storage? storage})
    : _storage = storage ?? Storage();

  final Storage _storage;

  static const String _entriesKey = 'wallet_address_book_entries';

  Future<List<WalletAddressBookEntry>> loadEntries() async {
    final entriesJson = await _storage.getJsonList(_entriesKey);
    if (entriesJson == null) {
      return [];
    }
    final entries = <WalletAddressBookEntry>[];
    for (final item in entriesJson.whereType<Map>()) {
      final entry = WalletAddressBookEntry.fromJson(
        Map<String, dynamic>.from(item),
      );
      if (entry.id.isNotEmpty &&
          entry.name.trim().isNotEmpty &&
          entry.address.trim().isNotEmpty &&
          entry.chainId.trim().isNotEmpty) {
        entries.add(entry);
      }
    }
    entries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return entries;
  }

  Future<List<WalletAddressBookEntry>> loadEntriesForChain(
    String chainId,
  ) async {
    final normalizedChainId = chainId.trim();
    if (normalizedChainId.isEmpty) return [];
    final entries = await loadEntries();
    return entries
        .where((entry) => entry.chainId == normalizedChainId)
        .toList(growable: false);
  }

  Future<void> saveEntry({
    String? id,
    required String name,
    required String address,
    required String chainId,
    required String chainName,
    String note = '',
  }) async {
    final entries = [...await loadEntries()];
    final now = DateTime.now();
    final normalizedId = id?.trim();
    final index = normalizedId == null || normalizedId.isEmpty
        ? -1
        : entries.indexWhere((entry) => entry.id == normalizedId);
    final next = WalletAddressBookEntry(
      id: index >= 0 ? entries[index].id : _newId(now),
      name: name.trim(),
      address: address.trim(),
      chainId: chainId.trim(),
      chainName: chainName.trim(),
      note: note.trim(),
      createdAt: index >= 0 ? entries[index].createdAt : now,
      updatedAt: now,
    );

    if (index >= 0) {
      entries[index] = next;
    } else {
      entries.insert(0, next);
    }
    await _saveEntries(entries);
  }

  Future<void> removeEntry(String id) async {
    final entries = [...await loadEntries()]
      ..removeWhere((entry) => entry.id == id);
    await _saveEntries(entries);
  }

  Future<void> _saveEntries(List<WalletAddressBookEntry> entries) {
    entries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return _storage.setJsonList(
      _entriesKey,
      entries.map((entry) => entry.toJson()).toList(growable: false),
    );
  }

  String _newId(DateTime now) {
    return 'addr_${now.microsecondsSinceEpoch}';
  }
}
