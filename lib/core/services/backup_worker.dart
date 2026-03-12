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
    await BackupService.backupNow(repository, branchRepository, isBackground: true);
    return Future.value(true);
  });
}
