import 'dart:convert';
import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../cash_entries/data/repositories/cash_entry_repository.dart';

class SyncSnapshot {
  const SyncSnapshot({
    required this.isOnline,
    required this.hasPendingChanges,
    required this.lastSyncedAt,
  });

  final bool isOnline;
  final bool hasPendingChanges;
  final DateTime? lastSyncedAt;
}

class SyncOutcome {
  const SyncOutcome({
    required this.success,
    required this.message,
  });

  final bool success;
  final String message;
}

class SyncService {
  SyncService({
    required CashEntryRepository repository,
    SupabaseClient? client,
  })  : _repository = repository,
        _client = client ?? Supabase.instance.client;

  static const String _settingsBoxName = 'app_settings';
  static const String _keyLastSyncedSignature = 'sync_last_signature';
  static const String _keyLastSyncedAtIso = 'sync_last_synced_at';

  final CashEntryRepository _repository;
  final SupabaseClient _client;

  Future<SyncSnapshot> getSnapshot() async {
    final isOnline = await checkOnline();
    final currentSignature = await _computeCurrentSignature();
    final settings = await _settingsBox();
    final lastSignature = settings.get(_keyLastSyncedSignature) as String?;
    final lastSyncedAtRaw = settings.get(_keyLastSyncedAtIso) as String?;
    final lastSyncedAt =
        lastSyncedAtRaw == null || lastSyncedAtRaw.isEmpty ? null : DateTime.tryParse(lastSyncedAtRaw);

    return SyncSnapshot(
      isOnline: isOnline,
      hasPendingChanges: currentSignature != lastSignature,
      lastSyncedAt: lastSyncedAt,
    );
  }

  Future<bool> checkOnline() async {
    if (!SupabaseConfig.isConfigured) {
      return false;
    }
    try {
      final uri = Uri.parse('${SupabaseConfig.url}/auth/v1/health');
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close();
      return response.statusCode >= 200 && response.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  Future<SyncOutcome> syncNow() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      return const SyncOutcome(success: false, message: 'Sign in required before syncing.');
    }

    final online = await checkOnline();
    if (!online) {
      return const SyncOutcome(success: false, message: 'No internet connection.');
    }

    final records = await _repository.getAllEntryRecords();
    final payload = records
        .map(
          (record) => {
            'user_id': record.entry.userId.isEmpty ? userId : record.entry.userId,
            'local_id': record.id,
            'date': record.entry.date.toIso8601String(),
            'cash': record.entry.cash,
            'cash_notes': record.entry.cashNotes,
            'coins': record.entry.coins,
            'till': record.entry.till,
            'expenses': record.entry.expenses,
            'branch_id': record.entry.branchId.isEmpty ? null : record.entry.branchId,
            'updated_at': DateTime.now().toIso8601String(),
          },
        )
        .toList(growable: false);

    try {
      if (payload.isNotEmpty) {
        await _client.from('cash_entries').upsert(payload, onConflict: 'user_id,local_id');
      }
      final settings = await _settingsBox();
      await settings.put(_keyLastSyncedSignature, await _computeCurrentSignature());
      await settings.put(_keyLastSyncedAtIso, DateTime.now().toIso8601String());
      return SyncOutcome(success: true, message: 'Synced ${payload.length} entries.');
    } catch (error) {
      return SyncOutcome(success: false, message: 'Sync failed: $error');
    }
  }

  Future<void> clearSyncMarkers() async {
    final settings = await _settingsBox();
    await settings.delete(_keyLastSyncedSignature);
    await settings.delete(_keyLastSyncedAtIso);
  }

  Future<String> _computeCurrentSignature() async {
    final records = await _repository.getAllEntryRecords()
      ..sort((a, b) => a.id.compareTo(b.id));

    final digestInput = records
        .map((record) {
          final entry = record.entry;
          return [
            record.id,
            entry.userId,
            entry.date.toIso8601String(),
            entry.cash,
            entry.cashNotes,
            entry.coins,
            entry.till,
            entry.expenses,
            entry.branchId,
          ].join('|');
        })
        .join('\n');

    return base64Encode(utf8.encode(digestInput));
  }

  Future<Box<dynamic>> _settingsBox() async {
    if (Hive.isBoxOpen(_settingsBoxName)) {
      return Hive.box<dynamic>(_settingsBoxName);
    }
    return Hive.openBox<dynamic>(_settingsBoxName);
  }
}
