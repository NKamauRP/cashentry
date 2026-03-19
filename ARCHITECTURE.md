# CashEntry App Architecture

This document explains the current architecture, file layout, and the main data flows for tracking entries, branches, analytics, and backup/export/import.

## Overview

The app is a single-user, offline-first Flutter application. All data is stored locally using Hive. Users can:
- create cash entries tied to business branches
- view analytics by branch or across multiple branches
- export and import entries (CSV/XLSX/PDF)
- back up data to Google Sheets via a webhook with retry queue and periodic scheduling

## Layers and Responsibilities

### App Shell
- [lib/main.dart](c:/Users/NKamau/Documents/Flutter app/cashentry/lib/main.dart)
  - Initializes Flutter bindings, Hive, and WorkManager background tasks.
  - Runs `MyApp` (see app.dart).

- [lib/app/app.dart](c:/Users/NKamau/Documents/Flutter app/cashentry/lib/app/app.dart)
  - Root widget and navigation shell.
  - Creates repositories and passes them to screens.
  - Owns the bottom navigation and routes to Home, Entries, Analytics, Settings.

### Data Layer (Local Storage)
- [lib/features/cash_entries/data/models/cash_entry.dart](c:/Users/NKamau/Documents/Flutter app/cashentry/lib/features/cash_entries/data/models/cash_entry.dart)
  - Hive model for cash entries (date, cash, notes, coins, till, expenses, branchId).

- [lib/features/cash_entries/data/repositories/cash_entry_repository.dart](c:/Users/NKamau/Documents/Flutter app/cashentry/lib/features/cash_entries/data/repositories/cash_entry_repository.dart)
  - CRUD operations for entries and methods to return records for analytics/export.

- [lib/features/branches/data/branch_repository.dart](c:/Users/NKamau/Documents/Flutter app/cashentry/lib/features/branches/data/branch_repository.dart)
  - CRUD operations for business branches in Hive.
  - Provides a `branchNameMap()` for display/export.

### Analytics Layer
- [lib/features/analytics/domain/analytics_models.dart](c:/Users/NKamau/Documents/Flutter app/cashentry/lib/features/analytics/domain/analytics_models.dart)
  - DTOs and summary types for analytics calculations.

- [lib/features/analytics/domain/analytics_service.dart](c:/Users/NKamau/Documents/Flutter app/cashentry/lib/features/analytics/domain/analytics_service.dart)
  - Core analytics logic (revenue, expenses, net profit).
  - Supports per-branch and multi-branch comparisons and summaries.

### Presentation Layer (Screens)
- [lib/features/dashboard/presentation/screens/home_screen.dart](c:/Users/NKamau/Documents/Flutter app/cashentry/lib/features/dashboard/presentation/screens/home_screen.dart)
  - Main dashboard with KPIs and a backup status card.

- [lib/features/entries/presentation/screens/entries_screen.dart](c:/Users/NKamau/Documents/Flutter app/cashentry/lib/features/entries/presentation/screens/entries_screen.dart)
  - Entry creation form with branch dropdown.
  - Users can add entries linked to a selected branch.

- [lib/features/analytics/presentation/screens/analytics_export_screen.dart](c:/Users/NKamau/Documents/Flutter app/cashentry/lib/features/analytics/presentation/screens/analytics_export_screen.dart)
  - Analytics filters by branch and comparison summary.

- [lib/features/settings/presentation/screens/settings_screen.dart](c:/Users/NKamau/Documents/Flutter app/cashentry/lib/features/settings/presentation/screens/settings_screen.dart)
  - Branch management card.
  - Backup/export/import configuration and actions.

### Shared UI and Utilities
- [lib/core/utils/layout.dart](c:/Users/NKamau/Documents/Flutter app/cashentry/lib/core/utils/layout.dart)
  - Adjusts padding for different Android navigation styles.

- [lib/core/utils/formatting.dart](c:/Users/NKamau/Documents/Flutter app/cashentry/lib/core/utils/formatting.dart)
  - Date/number formatting utilities.

- [lib/core/widgets/glass_widgets.dart](c:/Users/NKamau/Documents/Flutter app/cashentry/lib/core/widgets/glass_widgets.dart)
  - Reusable UI elements used across screens.

## Storage Model (Hive)

The app uses Hive boxes to persist data locally:
- `cash_entries`: saved cash entry objects
- `branches`: business branch records
- `app_settings`: backup configuration (webhook URL, secret, periodic enabled, last backup time)
- `backup_queue`: queued webhook payloads to retry

## Branch Management Flow

1. User adds a branch in Settings.
2. Branch is stored in Hive (`branches`).
3. Entry form uses a dropdown of branches.
4. Analytics groups entries by branch and supports multi-branch summaries.

## Entry Flow

1. User selects a branch in Entries.
2. User enters cash amounts and expenses.
3. Entry is persisted to Hive and shown on dashboard analytics.

## Analytics Flow

1. All entries are fetched from `CashEntryRepository`.
2. Analytics service calculates totals and summaries.
3. UI supports:
   - single-branch view
   - comparison between branches
   - total summary across selected branches

## Backup and Export Flow

Files:
- [lib/core/services/backup_service.dart](c:/Users/NKamau/Documents/Flutter app/cashentry/lib/core/services/backup_service.dart)
- [lib/core/services/backup_worker.dart](c:/Users/NKamau/Documents/Flutter app/cashentry/lib/core/services/backup_worker.dart)

### Manual Backup
1. User provides Google Sheets webhook URL (and optional secret).
2. User can optionally set a target sheet name for the webhook.
2. User taps “Backup Now.”
3. App collects all entries + branch names.
4. Data is POSTed to webhook with a `headers` list (column names) and optional `sheet_name`.
5. If the request fails, payload is queued for retry.

### Retry Queue
1. Failed payloads are stored in `backup_queue`.
2. Retry runs in background (WorkManager) or via “Retry Queue.”
3. Successful retries are removed from queue.

### Periodic Backup
1. User enables periodic backup in Settings.
2. WorkManager schedules a backup task and a retry task.
3. Tasks run in background and use the same backup logic.

### Export Formats
1. Export CSV, XLSX, and PDF use a shared export row builder.
2. “Export Bundle” creates a ZIP with selected formats.
3. Files are written to the app documents directory and can be shared.

### Import With Preview
1. User chooses a CSV file.
2. App parses and counts conflicts + new branches.
3. User decides to skip conflicts or import all.
4. Missing branches are created automatically.

## Error Handling

- Missing webhook URL: user gets a friendly error.
- Failed backup: payload is queued.
- Import errors: user sees a clear failure message.
- Branch name collisions are blocked when adding a new branch.

## Where to Extend

- Add more analytics: update `analytics_service.dart` and add new cards in analytics screen.
- Add more backup targets: extend `BackupService` with additional exporters.
- Add scheduled exports: call `BackupService.exportZip` in background tasks.
