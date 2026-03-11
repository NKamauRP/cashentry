import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_service.dart';
import '../../../../core/widgets/glass_widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.themeMode,
    required this.textSize,
    required this.regionSettings,
    required this.deviceLocale,
    required this.onThemeModeChanged,
    required this.onTextSizeChanged,
    required this.onRegionSettingsChanged,
    this.onSignOut,
  });

  final ThemeMode themeMode;
  final AppTextSize textSize;
  final RegionSettings regionSettings;
  final Locale deviceLocale;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<AppTextSize> onTextSizeChanged;
  final ValueChanged<RegionSettings> onRegionSettingsChanged;
  final Future<void> Function()? onSignOut;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 140),
      children: [
        Text(
          'Settings',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Display',
          subtitle: _themeModeLabel(widget.themeMode),
          icon: Icons.light_mode_rounded,
          onTap: _openDisplaySheet,
        ),
        const SizedBox(height: 10),
        _SectionCard(
          title: 'Accessibility',
          subtitle: 'Text size: ${_textSizeLabel(widget.textSize)}',
          icon: Icons.accessibility_new_rounded,
          onTap: _openAccessibilitySheet,
        ),
        const SizedBox(height: 10),
        _SectionCard(
          title: 'Data & Storage',
          subtitle: 'Cache, storage info, and backup/export placeholder',
          icon: Icons.storage_rounded,
          onTap: _openDataStorageSheet,
        ),
        const SizedBox(height: 10),
        _SectionCard(
          title: 'Region',
          subtitle: _regionSubtitle(),
          icon: Icons.public_rounded,
          onTap: _openRegionSheet,
        ),
        if (widget.onSignOut != null) ...[
          const SizedBox(height: 10),
          _SectionCard(
            title: 'Account',
            subtitle: 'Sign out from this device',
            icon: Icons.logout_rounded,
            onTap: _handleSignOut,
          ),
        ],
      ],
    );
  }

  String _themeModeLabel(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => 'Light Mode',
      ThemeMode.dark => 'Dark Mode',
      ThemeMode.system => 'System Default',
    };
  }

  String _textSizeLabel(AppTextSize size) {
    return switch (size) {
      AppTextSize.small => 'Small',
      AppTextSize.medium => 'Medium',
      AppTextSize.large => 'Large',
    };
  }

  String _regionSubtitle() {
    final settings = widget.regionSettings;
    if (settings.useSystemRegion) {
      return 'System: ${widget.deviceLocale.languageCode.toUpperCase()}-${(widget.deviceLocale.countryCode ?? 'US').toUpperCase()}';
    }
    return 'Custom: ${settings.languageCode.toUpperCase()}-${settings.countryCode.toUpperCase()}';
  }

  Future<void> _openDisplaySheet() async {
    ThemeMode selected = widget.themeMode;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return _SettingsSheet(
              title: 'Display',
              child: Column(
                children: [
                  _ChoiceTile(
                    title: 'Light Mode',
                    selected: selected == ThemeMode.light,
                    onTap: () {
                      setModalState(() => selected = ThemeMode.light);
                      widget.onThemeModeChanged(ThemeMode.light);
                    },
                  ),
                  _ChoiceTile(
                    title: 'Dark Mode',
                    selected: selected == ThemeMode.dark,
                    onTap: () {
                      setModalState(() => selected = ThemeMode.dark);
                      widget.onThemeModeChanged(ThemeMode.dark);
                    },
                  ),
                  _ChoiceTile(
                    title: 'System Default',
                    selected: selected == ThemeMode.system,
                    onTap: () {
                      setModalState(() => selected = ThemeMode.system);
                      widget.onThemeModeChanged(ThemeMode.system);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openAccessibilitySheet() async {
    AppTextSize selected = widget.textSize;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final scale = ThemeService.textScaleFactorFor(selected);
            return _SettingsSheet(
              title: 'Accessibility',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _SizeChip(
                        label: 'Small',
                        selected: selected == AppTextSize.small,
                        onTap: () {
                          setModalState(() => selected = AppTextSize.small);
                          widget.onTextSizeChanged(AppTextSize.small);
                        },
                      ),
                      _SizeChip(
                        label: 'Medium',
                        selected: selected == AppTextSize.medium,
                        onTap: () {
                          setModalState(() => selected = AppTextSize.medium);
                          widget.onTextSizeChanged(AppTextSize.medium);
                        },
                      ),
                      _SizeChip(
                        label: 'Large',
                        selected: selected == AppTextSize.large,
                        onTap: () {
                          setModalState(() => selected = AppTextSize.large);
                          widget.onTextSizeChanged(AppTextSize.large);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  GlassCard(
                    borderRadius: 16,
                    padding: const EdgeInsets.all(14),
                    child: MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        textScaler: TextScaler.linear(scale),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Preview Text',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Cash flow summaries, totals, and settings previews update with this size.',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openDataStorageSheet() async {
    Future<_StorageInfo> infoFuture = _loadStorageInfo();
    final rootMessenger = ScaffoldMessenger.of(context);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return _SettingsSheet(
              title: 'Data & Storage',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ActionTile(
                    title: 'Clear Cache',
                    subtitle: 'Remove temporary files and in-memory image cache.',
                    icon: Icons.cleaning_services_rounded,
                    danger: true,
                    onTap: () async {
                      final confirmed = await _confirmClearCache();
                      if (!confirmed) {
                        return;
                      }
                      await _clearCache();
                      setModalState(() {
                        infoFuture = _loadStorageInfo();
                      });
                      if (!mounted) {
                        return;
                      }
                      rootMessenger.showSnackBar(
                        const SnackBar(content: Text('Cache cleared successfully.')),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  FutureBuilder<_StorageInfo>(
                    future: infoFuture,
                    builder: (context, snapshot) {
                      final info = snapshot.data;
                      return GlassCard(
                        borderRadius: 16,
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Storage Info',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Text('Hive boxes: ${info?.hiveBoxCount ?? '-'}'),
                            Text('Hive box size: ${_formatBytes(info?.hiveBytes ?? 0)}'),
                            Text('Cache size: ${_formatBytes(info?.cacheBytes ?? 0)}'),
                            Text('Total estimate: ${_formatBytes(info?.totalBytes ?? 0)}'),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openRegionSheet() async {
    bool useSystem = widget.regionSettings.useSystemRegion;
    _LocaleOption selectedLocale = _localeOptions.firstWhere(
      (option) =>
          option.locale.languageCode == widget.regionSettings.languageCode &&
          option.locale.countryCode == widget.regionSettings.countryCode,
      orElse: () => _localeOptions.first,
    );
    MeasurementSystem selectedMeasurement = widget.regionSettings.measurementSystem;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final deviceCountry = widget.deviceLocale.countryCode ?? 'US';
            final deviceMeasurement = ThemeService.measurementFromCountry(deviceCountry);

            return _SettingsSheet(
              title: 'Region',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GlassCard(
                    borderRadius: 16,
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Device Region',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text('Language: ${widget.deviceLocale.languageCode.toUpperCase()}'),
                        Text('Country: ${(widget.deviceLocale.countryCode ?? 'US').toUpperCase()}'),
                        Text(
                          'Measurement: ${deviceMeasurement == MeasurementSystem.metric ? 'Metric' : 'Imperial'}',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Use system region'),
                    value: useSystem,
                    activeThumbColor: AppColors.teal,
                    onChanged: (value) {
                      setModalState(() {
                        useSystem = value;
                      });

                      final updated = widget.regionSettings.copyWith(
                        useSystemRegion: value,
                        languageCode: value ? widget.deviceLocale.languageCode : selectedLocale.locale.languageCode,
                        countryCode: value
                            ? (widget.deviceLocale.countryCode ?? 'US')
                            : (selectedLocale.locale.countryCode ?? 'US'),
                        measurementSystem: value
                            ? ThemeService.measurementFromCountry(widget.deviceLocale.countryCode ?? 'US')
                            : selectedMeasurement,
                      );
                      widget.onRegionSettingsChanged(updated);
                    },
                  ),
                  const SizedBox(height: 8),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    child: useSystem
                        ? const SizedBox.shrink()
                        : Column(
                            key: const ValueKey<String>('custom-region'),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DropdownButtonFormField<_LocaleOption>(
                                initialValue: selectedLocale,
                                decoration: InputDecoration(
                                  labelText: 'Language & Country',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                items: _localeOptions
                                    .map(
                                      (option) => DropdownMenuItem<_LocaleOption>(
                                        value: option,
                                        child: Text(option.label),
                                      ),
                                    )
                                    .toList(growable: false),
                                onChanged: (option) {
                                  if (option == null) {
                                    return;
                                  }
                                  setModalState(() {
                                    selectedLocale = option;
                                  });
                                  widget.onRegionSettingsChanged(
                                    widget.regionSettings.copyWith(
                                      useSystemRegion: false,
                                      languageCode: option.locale.languageCode,
                                      countryCode: option.locale.countryCode ?? 'US',
                                      measurementSystem: selectedMeasurement,
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                children: [
                                  _SizeChip(
                                    label: 'Metric',
                                    selected: selectedMeasurement == MeasurementSystem.metric,
                                    onTap: () {
                                      setModalState(() {
                                        selectedMeasurement = MeasurementSystem.metric;
                                      });
                                      widget.onRegionSettingsChanged(
                                        widget.regionSettings.copyWith(
                                          useSystemRegion: false,
                                          languageCode: selectedLocale.locale.languageCode,
                                          countryCode: selectedLocale.locale.countryCode ?? 'US',
                                          measurementSystem: MeasurementSystem.metric,
                                        ),
                                      );
                                    },
                                  ),
                                  _SizeChip(
                                    label: 'Imperial',
                                    selected: selectedMeasurement == MeasurementSystem.imperial,
                                    onTap: () {
                                      setModalState(() {
                                        selectedMeasurement = MeasurementSystem.imperial;
                                      });
                                      widget.onRegionSettingsChanged(
                                        widget.regionSettings.copyWith(
                                          useSystemRegion: false,
                                          languageCode: selectedLocale.locale.languageCode,
                                          countryCode: selectedLocale.locale.countryCode ?? 'US',
                                          measurementSystem: MeasurementSystem.imperial,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need to sign in again to access your cash flow data.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed != true || widget.onSignOut == null) {
      return;
    }
    await widget.onSignOut!.call();
  }

  Future<bool> _confirmClearCache() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Clear Cache?'),
          content: const Text('This will delete temporary files and image cache data.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Clear',
                style: TextStyle(color: AppColors.danger),
              ),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  Future<void> _clearCache() async {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

    final tempDir = await getTemporaryDirectory();
    if (!await tempDir.exists()) {
      return;
    }

    final entities = tempDir.listSync();
    for (final entity in entities) {
      try {
        entity.deleteSync(recursive: true);
      } catch (_) {
        // Best-effort cleanup for platform-managed cache files.
      }
    }
  }

  Future<_StorageInfo> _loadStorageInfo() async {
    final hiveBytes = await _estimateHiveBoxBytes();
    final cacheBytes = await _estimateCacheBytes();
    return _StorageInfo(
      hiveBoxCount: _trackedHiveBoxNames.length,
      hiveBytes: hiveBytes,
      cacheBytes: cacheBytes,
      totalBytes: hiveBytes + cacheBytes,
    );
  }

  Future<int> _estimateHiveBoxBytes() async {
    int total = 0;
    for (final boxName in _trackedHiveBoxNames) {
      Box<dynamic> box;
      if (Hive.isBoxOpen(boxName)) {
        box = Hive.box<dynamic>(boxName);
      } else {
        box = await Hive.openBox<dynamic>(boxName);
      }

      final path = box.path;
      if (path == null) {
        continue;
      }
      final file = File(path);
      if (await file.exists()) {
        total += await file.length();
      }
      final lockFile = File('$path.lock');
      if (await lockFile.exists()) {
        total += await lockFile.length();
      }
    }
    return total;
  }

  Future<int> _estimateCacheBytes() async {
    final tempDir = await getTemporaryDirectory();
    final diskCacheBytes = await _directorySize(tempDir);
    final imageMemoryBytes = PaintingBinding.instance.imageCache.currentSizeBytes;
    return diskCacheBytes + imageMemoryBytes;
  }

  Future<int> _directorySize(Directory directory) async {
    if (!await directory.exists()) {
      return 0;
    }

    int total = 0;
    await for (final entity in directory.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) {
      return '0 B';
    }
    const units = ['B', 'KB', 'MB', 'GB'];
    double value = bytes.toDouble();
    int index = 0;
    while (value >= 1024 && index < units.length - 1) {
      value /= 1024;
      index++;
    }
    return '${value.toStringAsFixed(index == 0 ? 0 : 1)} ${units[index]}';
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      glow: true,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.teal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: GlassCard(
        borderRadius: 24,
        glow: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        borderRadius: 14,
        glow: selected,
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.teal : null,
                ),
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.teal,
              ),
          ],
        ),
      ),
    );
  }
}

class _SizeChip extends StatelessWidget {
  const _SizeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected ? AppColors.teal.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.08),
          border: Border.all(
            color: selected ? AppColors.teal : Colors.white.withValues(alpha: 0.22),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.teal.withValues(alpha: 0.24),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.teal : Theme.of(context).colorScheme.onSurface,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.teal;

    return GlassCard(
      borderRadius: 16,
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                ),
                const SizedBox(height: 3),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StorageInfo {
  const _StorageInfo({
    required this.hiveBoxCount,
    required this.hiveBytes,
    required this.cacheBytes,
    required this.totalBytes,
  });

  final int hiveBoxCount;
  final int hiveBytes;
  final int cacheBytes;
  final int totalBytes;
}

class _LocaleOption {
  const _LocaleOption(this.label, this.locale);

  final String label;
  final Locale locale;
}

const List<_LocaleOption> _localeOptions = [
  _LocaleOption('English (US)', Locale('en', 'US')),
  _LocaleOption('English (UK)', Locale('en', 'GB')),
  _LocaleOption('Swahili (Kenya)', Locale('sw', 'KE')),
  _LocaleOption('French (France)', Locale('fr', 'FR')),
  _LocaleOption('German (Germany)', Locale('de', 'DE')),
];

const List<String> _trackedHiveBoxNames = [
  'app_settings',
  'cash_entries',
];
