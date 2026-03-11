import 'package:flutter/material.dart';
import 'app/app.dart';
import 'core/theme/theme_service.dart';
import 'features/cash_entries/data/repositories/cash_entry_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeCashEntryStorage();
  await ThemeService.ensureInitialized();

  runApp(const CashFlowApp());
}
