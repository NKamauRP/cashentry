// Backup, export, import, and retry queue logic for local data sync.
//
// Responsibilities:
// - Store webhook settings in Hive.
// - Run manual and periodic Google Sheets webhook backups.
// - Queue failed payloads and retry them later.
// - Export entries (CSV/XLSX/PDF) and bundle as ZIP.
// - Import CSV with preview and conflict handling.
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
import 'package:archive/archive_io.dart';

import '../../features/branches/data/branch_repository.dart';
import '../../features/cash_entries/data/models/cash_entry.dart';
import '../../features/cash_entries/data/repositories/cash_entry_repository.dart';

class BackupConfig {
  const BackupConfig({
    required this.webhookUrl,
    required this.webhookSecret,
    required this.sheetName,
    required this.periodicEnabled,
    required this.lastBackupAt,
  });

  final String webhookUrl;
  final String webhookSecret;
  final String sheetName;
  final bool periodicEnabled;
  final DateTime? lastBackupAt;
}

class BackupResult {
  const BackupResult({required this.success, required this.message});

  final bool success;
  final String message;
}

class ImportPreview {
  const ImportPreview({
    required this.totalRows,
    required this.validRows,
    required this.conflicts,
    required this.newBranches,
  });

  final int totalRows;
  final int validRows;
  final int conflicts;
  final int newBranches;
}

class BackupService {
  static const String _settingsBoxName = 'app_settings';
  static const String _queueBoxName = 'backup_queue';
  static const String _keyWebhookUrl = 'backup_webhook_url';
  static const String _keyWebhookSecret = 'backup_webhook_secret';
  static const String _keySheetName = 'backup_sheet_name';
  static const String _keyPeriodicEnabled = 'backup_periodic_enabled';
  static const String _keyLastBackupAt = 'backup_last_at';
  static const String backupTaskName = 'periodicBackup';
  static const String backupTaskId = 'periodicBackupTask';
  static const String retryTaskName = 'retryQueue';
  static const String retryTaskId = 'retryQueueTask';

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

  static Future<Box<Map>> _queueBox() async {
    if (Hive.isBoxOpen(_queueBoxName)) {
      return Hive.box<Map>(_queueBoxName);
    }
    return Hive.openBox<Map>(_queueBoxName);
  }

  static Future<BackupConfig> loadConfig() async {
    final box = await _settingsBox();
    final url = (box.get(_keyWebhookUrl) ?? '').toString();
    final secret = (box.get(_keyWebhookSecret) ?? '').toString();
    final sheetName = (box.get(_keySheetName) ?? '').toString();
    final enabled = box.get(_keyPeriodicEnabled) == true;
    final lastRaw = (box.get(_keyLastBackupAt) ?? '').toString();
    final last = lastRaw.isEmpty ? null : DateTime.tryParse(lastRaw);
    return BackupConfig(
      webhookUrl: url,
      webhookSecret: secret,
      sheetName: sheetName,
      periodicEnabled: enabled,
      lastBackupAt: last,
    );
  }

  static Future<void> saveConfig({
    required String webhookUrl,
    required String webhookSecret,
    String sheetName = '',
  }) async {
    final box = await _settingsBox();
    await box.put(_keyWebhookUrl, webhookUrl.trim());
    await box.put(_keyWebhookSecret, webhookSecret.trim());
    await box.put(_keySheetName, sheetName.trim());
  }

  static Future<void> setPeriodicEnabled(bool enabled, {Duration frequency = const Duration(hours: 1)}) async {
    final box = await _settingsBox();
    await box.put(_keyPeriodicEnabled, enabled);
    if (enabled) {
      await Workmanager().registerPeriodicTask(
        backupTaskId,
        backupTaskName,
        frequency: frequency,
        existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
      );
      await Workmanager().registerPeriodicTask(
        retryTaskId,
        retryTaskName,
        frequency: const Duration(hours: 6),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
      );
    } else {
      await Workmanager().cancelByUniqueName(backupTaskId);
      await Workmanager().cancelByUniqueName(retryTaskId);
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
      if (config.sheetName.trim().isNotEmpty) 'sheet_name': config.sheetName.trim(),
      'headers': _exportHeaders,
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
        await _enqueuePayload(payload);
        return BackupResult(
          success: false,
          message: 'Backup failed (${response.statusCode}). Queued for retry.',
        );
      }

      final box = await _settingsBox();
      await box.put(_keyLastBackupAt, DateTime.now().toIso8601String());
      await processQueue(config);
      return BackupResult(success: true, message: 'Backup completed successfully.');
    } catch (error) {
      await _enqueuePayload(payload);
      if (isBackground) {
        return const BackupResult(success: false, message: 'Background backup failed.');
      }
      return BackupResult(success: false, message: 'Backup failed: $error (queued).');
    }
  }

  static Future<void> _enqueuePayload(Map<String, dynamic> payload) async {
    final box = await _queueBox();
    await box.add({
      'createdAt': DateTime.now().toIso8601String(),
      'payload': payload,
    });
  }

  static Future<int> queuedCount() async {
    final box = await _queueBox();
    return box.length;
  }

  static Future<BackupResult> processQueue(BackupConfig config) async {
    final box = await _queueBox();
    if (box.isEmpty || config.webhookUrl.isEmpty) {
      return const BackupResult(success: true, message: 'No queued backups.');
    }
    final keys = box.keys.toList(growable: false);
    int sent = 0;
    for (final key in keys) {
      final record = box.get(key);
      if (record == null) {
        continue;
      }
      final payload = (record['payload'] as Map?)?.cast<String, dynamic>();
      if (payload == null) {
        await box.delete(key);
        continue;
      }
      try {
        final response = await http.post(
          Uri.parse(config.webhookUrl),
          headers: {
            HttpHeaders.contentTypeHeader: 'application/json',
            if (config.webhookSecret.isNotEmpty) 'X-Backup-Secret': config.webhookSecret,
          },
          body: jsonEncode(payload),
        );
        if (response.statusCode >= 200 && response.statusCode < 300) {
          await box.delete(key);
          sent++;
        } else {
          break;
        }
      } catch (_) {
        break;
      }
    }
    return BackupResult(success: true, message: 'Processed $sent queued backups.');
  }

  static Future<File> exportCsv(
    CashEntryRepository repository,
    BranchRepository branchRepository,
  ) async {
    final rows = await _exportRows(repository, branchRepository);
    final csvContent = const CsvEncoder().convert(rows);
    return _writeExportFile('cash_entries.csv', csvContent);
  }

  static Future<File> exportXlsx(
    CashEntryRepository repository,
    BranchRepository branchRepository,
  ) async {
    final rows = await _exportRows(repository, branchRepository);
    final excel = Excel.createExcel();
    final sheet = excel['Entries'];
    for (final row in rows) {
      sheet.appendRow(row.map(_toCellValue).toList(growable: false));
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
          pw.TableHelper.fromTextArray(
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

  static Future<File> exportZip(
    CashEntryRepository repository,
    BranchRepository branchRepository, {
    bool includeCsv = true,
    bool includeXlsx = true,
    bool includePdf = true,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final exportDir = Directory('${dir.path}/exports');
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }
    final files = <File>[];
    if (includeCsv) {
      files.add(await exportCsv(repository, branchRepository));
    }
    if (includeXlsx) {
      files.add(await exportXlsx(repository, branchRepository));
    }
    if (includePdf) {
      files.add(await exportPdf(repository, branchRepository));
    }

    final zipPath = '${exportDir.path}/cash_entries_export.zip';
    final encoder = ZipFileEncoder();
    encoder.create(zipPath);
    for (final file in files) {
      encoder.addFile(file);
    }
    encoder.close();
    return File(zipPath);
  }

  static Future<BackupResult> importCsv(
    File file,
    CashEntryRepository repository,
    BranchRepository branchRepository, {
    bool skipConflicts = true,
  }
  ) async {
    try {
      final parsed = await _parseImportRows(file);
      if (parsed.isEmpty) {
        return const BackupResult(success: false, message: 'CSV file is empty or invalid.');
      }

      final existingSignatures = await _existingSignatures(repository, branchRepository);
      final branchNames = await branchRepository.branchNameMap();
      final nameToId = {
        for (final entry in branchNames.entries) entry.value.toLowerCase(): entry.key,
      };

      int imported = 0;
      for (final row in parsed) {
        final signature = _signatureForRow(row);
        if (skipConflicts && existingSignatures.contains(signature)) {
          continue;
        }
        String branchId = '';
        if (row.branchId.isNotEmpty && branchNames.containsKey(row.branchId)) {
          branchId = row.branchId;
        } else if (row.branchName.isNotEmpty) {
          final normalized = row.branchName.toLowerCase();
          branchId = nameToId[normalized] ?? '';
          if (branchId.isEmpty) {
            final newBranch = await branchRepository.addBranch(row.branchName);
            branchId = newBranch.id;
            nameToId[normalized] = newBranch.id;
          }
        } else {
          const fallback = 'Unassigned';
          branchId = nameToId[fallback.toLowerCase()] ?? '';
          if (branchId.isEmpty) {
            final newBranch = await branchRepository.addBranch(fallback);
            branchId = newBranch.id;
            nameToId[fallback.toLowerCase()] = newBranch.id;
          }
        }

        final entry = CashEntry(
          date: row.date,
          cash: row.cash,
          cashNotes: row.cashNotes,
          coins: row.coins,
          till: row.till,
          expenses: row.expenses,
          branchId: branchId,
        );
        await repository.addEntry(entry);
        imported++;
      }

      return BackupResult(success: true, message: 'Imported $imported entries.');
    } catch (error) {
      return BackupResult(success: false, message: 'Import failed: $error');
    }
  }

  static Future<ImportPreview> previewImportCsv(
    File file,
    CashEntryRepository repository,
    BranchRepository branchRepository,
  ) async {
    final parsed = await _parseImportRows(file);
    if (parsed.isEmpty) {
      return const ImportPreview(totalRows: 0, validRows: 0, conflicts: 0, newBranches: 0);
    }
    final existingSignatures = await _existingSignatures(repository, branchRepository);
    final branchNames = await branchRepository.branchNameMap();
    final nameToId = {
      for (final entry in branchNames.entries) entry.value.toLowerCase(): entry.key,
    };

    int conflicts = 0;
    int newBranches = 0;
    for (final row in parsed) {
      final signature = _signatureForRow(row);
      if (existingSignatures.contains(signature)) {
        conflicts++;
      }
      if (row.branchName.isNotEmpty && !nameToId.containsKey(row.branchName.toLowerCase())) {
        newBranches++;
        nameToId[row.branchName.toLowerCase()] = '__pending__$newBranches';
      }
    }

    return ImportPreview(
      totalRows: parsed.length,
      validRows: parsed.length,
      conflicts: conflicts,
      newBranches: newBranches,
    );
  }

  static const List<String> _exportHeaders = [
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
  ];

  static Future<List<List<dynamic>>> _exportRows(
    CashEntryRepository repository,
    BranchRepository branchRepository,
  ) async {
    final branchNames = await branchRepository.branchNameMap();
    final records = await repository.getAllEntryRecords();
    final rows = <List<dynamic>>[
      _exportHeaders,
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

  static CellValue _toCellValue(dynamic value) {
    if (value == null) {
      return TextCellValue('');
    }
    if (value is int) {
      return IntCellValue(value);
    }
    if (value is double) {
      return DoubleCellValue(value);
    }
    if (value is bool) {
      return BoolCellValue(value);
    }
    if (value is DateTime) {
      return DateCellValue.fromDateTime(value);
    }
    return TextCellValue(value.toString());
  }

  static double _toDouble(dynamic value) {
    if (value == null) {
      return 0;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString()) ?? 0;
  }

  static Future<List<_ImportRow>> _parseImportRows(File file) async {
    final content = await file.readAsString();
    final rows = const CsvDecoder().convert(content);    if (rows.isEmpty) {
      return const [];
    }
    final header = rows.first.map((e) => e.toString().trim()).toList(growable: false);
    int idxOf(String name) => header.indexWhere((h) => h.toLowerCase() == name.toLowerCase());

    final dateIdx = idxOf('date');
    final branchIdIdx = idxOf('branch_id');
    final branchNameIdx = idxOf('branch_name');
    final cashIdx = idxOf('cash');
    final cashNotesIdx = idxOf('cash_notes');
    final coinsIdx = idxOf('coins');
    final tillIdx = idxOf('till');
    final expensesIdx = idxOf('expenses');

    if ([dateIdx, cashIdx, cashNotesIdx, coinsIdx, tillIdx, expensesIdx].any((i) => i < 0)) {
      return const [];
    }

    final parsed = <_ImportRow>[];
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty) {
        continue;
      }
      final date = DateTime.tryParse(row[dateIdx].toString());
      if (date == null) {
        continue;
      }
      parsed.add(
        _ImportRow(
          date: date,
          branchId: branchIdIdx >= 0 ? row[branchIdIdx].toString().trim() : '',
          branchName: branchNameIdx >= 0 ? row[branchNameIdx].toString().trim() : '',
          cash: _toDouble(row[cashIdx]),
          cashNotes: _toDouble(row[cashNotesIdx]),
          coins: _toDouble(row[coinsIdx]),
          till: _toDouble(row[tillIdx]),
          expenses: _toDouble(row[expensesIdx]),
        ),
      );
    }
    return parsed;
  }

  static Future<Set<String>> _existingSignatures(
    CashEntryRepository repository,
    BranchRepository branchRepository,
  ) async {
    final branchNames = await branchRepository.branchNameMap();
    final records = await repository.getAllEntryRecords();
    final signatures = <String>{};
    for (final record in records) {
      final entry = record.entry;
      final branchName = branchNames[entry.branchId]?.toLowerCase() ?? '';
      final base = _signatureCore(
        date: entry.date,
        cash: entry.cash,
        cashNotes: entry.cashNotes,
        coins: entry.coins,
        till: entry.till,
        expenses: entry.expenses,
      );
      if (entry.branchId.isNotEmpty) {
        signatures.add('${entry.branchId}|$base');
      }
      if (branchName.isNotEmpty) {
        signatures.add('$branchName|$base');
      }
    }
    return signatures;
  }

  static String _signatureForRow(_ImportRow row) {
    final branchKey = row.branchId.isNotEmpty ? row.branchId : row.branchName.toLowerCase();
    return '$branchKey|${_signatureCore(date: row.date, cash: row.cash, cashNotes: row.cashNotes, coins: row.coins, till: row.till, expenses: row.expenses)}';
  }

  static String _signatureCore({
    required DateTime date,
    required double cash,
    required double cashNotes,
    required double coins,
    required double till,
    required double expenses,
  }) {
    return '${date.toIso8601String()}|$cash|$cashNotes|$coins|$till|$expenses';
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

class _ImportRow {
  const _ImportRow({
    required this.date,
    required this.branchId,
    required this.branchName,
    required this.cash,
    required this.cashNotes,
    required this.coins,
    required this.till,
    required this.expenses,
  });

  final DateTime date;
  final String branchId;
  final String branchName;
  final double cash;
  final double cashNotes;
  final double coins;
  final double till;
  final double expenses;
}
