import 'package:flutter/foundation.dart';

import '../../data/services/sync_service.dart';

class SyncController extends ChangeNotifier {
  SyncController(this._service);

  final SyncService _service;

  bool isOnline = false;
  bool hasPendingChanges = true;
  bool isSyncing = false;
  DateTime? lastSyncedAt;
  String statusMessage = 'Checking sync status...';

  Future<void> initialize() async {
    await refreshStatus();
  }

  Future<void> refreshStatus() async {
    final snapshot = await _service.getSnapshot();
    isOnline = snapshot.isOnline;
    hasPendingChanges = snapshot.hasPendingChanges;
    lastSyncedAt = snapshot.lastSyncedAt;
    statusMessage = _statusLabel();
    notifyListeners();
  }

  Future<SyncOutcome> syncNow() async {
    if (isSyncing) {
      return const SyncOutcome(success: false, message: 'Sync already in progress.');
    }
    isSyncing = true;
    statusMessage = 'Syncing...';
    notifyListeners();

    final outcome = await _service.syncNow();
    isSyncing = false;
    await refreshStatus();
    statusMessage = outcome.message;
    notifyListeners();
    return outcome;
  }

  Future<void> markLocalDataChanged() async {
    await refreshStatus();
  }

  Future<void> clearOnSignOut() async {
    await _service.clearSyncMarkers();
    isOnline = false;
    hasPendingChanges = true;
    lastSyncedAt = null;
    statusMessage = 'Signed out';
    notifyListeners();
  }

  String _statusLabel() {
    if (!isOnline) {
      return 'Offline';
    }
    if (hasPendingChanges) {
      return 'Pending sync';
    }
    return 'Synced';
  }
}
