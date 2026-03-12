import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:workmanager/workmanager.dart';

import '../../features/branches/data/branch_repository.dart';
import '../../features/cash_entries/data/repositories/cash_entry_repository.dart';

class BackupConfig {
  const BackupConfig({
    required this.webhookUrl,
    required this.webhookSecret,
    required this.periodicEnabled,
    required this.lastBackupAt,
  });

  final String webhookUrl;
  final String webhookSecret;
  final bool periodicEnabled;
  final DateTime? lastBackupAt;
}

class BackupResult {
  const BackupResult({required this.success, required this.message});

  final bool success;
  final String message;
}

class BackupService {
  static const String _settingsBoxName = 'app_settings';
  static const String _keyWebhookUrl = 'backup_webhook_url';
  static const String _keyWebhookSecret = 'backup_webhook_secret';
  static const String _keyPeriodicEnabled = 'backup_periodic_enabled';
  static const String _keyLastBackupAt = 'backup_last_at';
  static const String _taskName = 'periodicBackup';
  static const String _taskId = 'periodicBackupTask';

  static bool _initialized = false;

  static Future<void> ensureInitialized() async {
    if (_initialized) {
      return;
    }
    WidgetsFlutterBinding.ensureInitialized();
    await Hive.initFlutter();
    _initialized = true;
  }

  static Future<Box<dynamic>> _settingsBox() async {
    if (Hive.isBoxOpen(_settingsBoxName)) {
      return Hive.box<dynamic>(_settingsBoxName);
    }
    return Hive.openBox<dynamic>(_settingsBoxName);
  }

  static Future<BackupConfig> loadConfig() async {
    final box = await _settingsBox();
    final url = (box.get(_keyWebhookUrl) ?? '').toString();
    final secret = (box.get(_keyWebhookSecret) ?? '').toString();
    final enabled = box.get(_keyPeriodicEnabled) == true;
    final lastRaw = (box.get(_keyLastBackupAt) ?? '').toString();
    final last = lastRaw.isEmpty ? null : DateTime.tryParse(lastRaw);
    return BackupConfig(
      webhookUrl: url,
      webhookSecret: secret,
      periodicEnabled: enabled,
      lastBackupAt: last,
    );
  }

  static Future<void> saveConfig({
    required String webhookUrl,
    required String webhookSecret,
  }) async {
    final box = await _settingsBox();
    await box.put(_keyWebhookUrl, webhookUrl.trim());
    await box.put(_keyWebhookSecret, webhookSecret.trim());
  }

  static Future<void> setPeriodicEnabled(bool enabled, {Duration frequency = const Duration(hours: 1)}) async {
    final box = await _settingsBox();
    await box.put(_keyPeriodicEnabled, enabled);
    if (enabled) {
      await Workmanager().registerPeriodicTask(
        _taskId,
        _taskName,
        frequency: frequency,
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );
    } else {
      await Workmanager().cancelByUniqueName(_taskId);
    }
  }

  static Future<BackupResult> backupNow(
    CashEntryRepository repository,
    BranchRepository branchRepository, {
    bool isBackground = false,
  }) async {
    final config = await loadConfig();
    if (config.webhookUrl.isEmpty) {
      return const BackupResult(
        success: false,
        message: 'Set a Google Sheets webhook URL first.',
      );
    }

    final branchNames = await branchRepository.branchNameMap();
    final records = await repository.getAllEntryRecords();
    final payload = {
      'source': 'cashentry',
      'timestamp': DateTime.now().toIso8601String(),
      'entries': records.map((record) {
        final entry = record.entry;
        final revenue = entry.cash + entry.cashNotes + entry.coins + entry.till;
        final netProfit = revenue - entry.expenses;
        return {
          'local_id': record.id,
          'date': entry.date.toIso8601String(),
          'branch_id': entry.branchId,
          'branch_name': branchNames[entry.branchId] ?? '',
          'cash': entry.cash,
          'cash_notes': entry.cashNotes,
          'coins': entry.coins,
          'till': entry.till,
          'expenses': entry.expenses,
          'revenue': revenue,
          'net_profit': netProfit,
        };
      }).toList(growable: false),
    };

    try {
      final response = await http.post(
        Uri.parse(config.webhookUrl),
        headers: {
          HttpHeaders.contentTypeHeader: 'application/json',
          if (config.webhookSecret.isNotEmpty) 'X-Backup-Secret': config.webhookSecret,
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return BackupResult(
          success: false,
          message: 'Backup failed (${response.statusCode}).',
        );
      }

      final box = await _settingsBox();
      await box.put(_keyLastBackupAt, DateTime.now().toIso8601String());
      return BackupResult(success: true, message: 'Backup completed successfully.');
    } catch (error) {
      if (isBackground) {
        return const BackupResult(success: false, message: 'Background backup failed.');
      }
      return BackupResult(success: false, message: 'Backup failed: $error');
    }
  }

  static Future<File> exportCsv(
    CashEntryRepository repository,
    BranchRepository branchRepository,
  ) async {
    final rows = await _exportRows(repository, branchRepository);
    final csv = const ListToCsvConverter().convert(rows);
    return _writeExportFile('cash_entries.csv', csv);
  }

  static Future<File> exportXlsx(
    CashEntryRepository repository,
    BranchRepository branchRepository,
  ) async {
    final rows = await _exportRows(repository, branchRepository);
    final excel = Excel.createExcel();
    final sheet = excel['Entries'];
    for (final row in rows) {
      sheet.appendRow(row);
    }
    final bytes = excel.encode();
    return _writeExportFile('cash_entries.xlsx', bytes ?? <int>[]);
  }

  static Future<File> exportPdf(
    CashEntryRepository repository,
    BranchRepository branchRepository,
  ) async {
    final rows = await _exportRows(repository, branchRepository);
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        build: (_) => [
          pw.Text('Cash Entry Export', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          pw.Table.fromTextArray(
            data: rows,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
          ),
        ],
      ),
    );
    final bytes = await doc.save();
    return _writeExportFile('cash_entries.pdf', bytes);
  }

  static Future<List<List<dynamic>>> _exportRows(
    CashEntryRepository repository,
    BranchRepository branchRepository,
  ) async {
    final branchNames = await branchRepository.branchNameMap();
    final records = await repository.getAllEntryRecords();
    final rows = <List<dynamic>>[
      [
        'local_id',
        'date',
        'branch_id',
        'branch_name',
        'cash',
        'cash_notes',
        'coins',
        'till',
        'expenses',
        'revenue',
        'net_profit',
      ],
    ];

    for (final record in records) {
      final entry = record.entry;
      final revenue = entry.cash + entry.cashNotes + entry.coins + entry.till;
      final netProfit = revenue - entry.expenses;
      rows.add([
        record.id,
        entry.date.toIso8601String(),
        entry.branchId,
        branchNames[entry.branchId] ?? '',
        entry.cash,
        entry.cashNotes,
        entry.coins,
        entry.till,
        entry.expenses,
        revenue,
        netProfit,
      ]);
    }

    return rows;
  }

  static Future<File> _writeExportFile(String name, dynamic content) async {
    final dir = await getApplicationDocumentsDirectory();
    final exportDir = Directory('${dir.path}/exports');
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }
    final file = File('${exportDir.path}/$name');
    if (content is String) {
      await file.writeAsString(content, flush: true);
    } else if (content is List<int>) {
      await file.writeAsBytes(content, flush: true);
    } else {
      await file.writeAsBytes(content as List<int>, flush: true);
    }
    return file;
  }
}
