/// Background task entry-point for scheduled backup and retry queue processing.
///
/// Runs via WorkManager and reuses [BackupService] to perform:
/// - periodic Google Sheets webhook backup
/// - retry of any queued payloads
library;
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../../features/branches/data/branch_repository.dart';
import '../../features/cash_entries/data/repositories/cash_entry_repository.dart';
import 'backup_service.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    await BackupService.ensureInitialized();
    final repository = CashEntryRepository();
    final branchRepository = BranchRepository();
    final config = await BackupService.loadConfig();
    if (task == BackupService.backupTaskName) {
      await BackupService.backupNow(repository, branchRepository, isBackground: true);
    }
    await BackupService.processQueue(config);
    return Future.value(true);
  });
}
