import 'package:flutter/material.dart';
import 'app/app.dart';
import 'core/services/backup_worker.dart';
import 'core/theme/theme_service.dart';
import 'features/cash_entries/data/repositories/cash_entry_repository.dart';
import 'package:workmanager/workmanager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  await initializeCashEntryStorage();
  await ThemeService.ensureInitialized();

  runApp(const CashFlowApp());
}
