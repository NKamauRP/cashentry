import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

enum AppTextSize {
  small,
  medium,
  large,
}

enum MeasurementSystem {
  metric,
  imperial,
}

class RegionSettings {
  const RegionSettings({
    required this.useSystemRegion,
    required this.languageCode,
    required this.countryCode,
    required this.measurementSystem,
  });

  final bool useSystemRegion;
  final String languageCode;
  final String countryCode;
  final MeasurementSystem measurementSystem;

  Locale get locale => Locale(languageCode, countryCode);

  RegionSettings copyWith({
    bool? useSystemRegion,
    String? languageCode,
    String? countryCode,
    MeasurementSystem? measurementSystem,
  }) {
    return RegionSettings(
      useSystemRegion: useSystemRegion ?? this.useSystemRegion,
      languageCode: languageCode ?? this.languageCode,
      countryCode: countryCode ?? this.countryCode,
      measurementSystem: measurementSystem ?? this.measurementSystem,
    );
  }
}

class ThemeService {
  ThemeService._();

  static const String _boxName = 'app_settings';
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyTextSize = 'text_size';
  static const String _keyRegionUseSystem = 'region_use_system';
  static const String _keyRegionLanguageCode = 'region_language_code';
  static const String _keyRegionCountryCode = 'region_country_code';
  static const String _keyMeasurementSystem = 'measurement_system';

  static late Box<dynamic> _box;

  static Future<void> ensureInitialized() async {
    if (!Hive.isBoxOpen(_boxName)) {
      _box = await Hive.openBox<dynamic>(_boxName);
    } else {
      _box = Hive.box<dynamic>(_boxName);
    }
  }

  static ThemeMode loadThemeMode() {
    final rawValue = _box.get(_keyThemeMode) as String?;
    switch (rawValue) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static Future<void> saveThemeMode(ThemeMode mode) async {
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await _box.put(_keyThemeMode, value);
  }

  static AppTextSize loadTextSize() {
    final rawValue = _box.get(_keyTextSize) as String?;
    switch (rawValue) {
      case 'small':
        return AppTextSize.small;
      case 'large':
        return AppTextSize.large;
      default:
        return AppTextSize.medium;
    }
  }

  static Future<void> saveTextSize(AppTextSize size) async {
    final value = switch (size) {
      AppTextSize.small => 'small',
      AppTextSize.medium => 'medium',
      AppTextSize.large => 'large',
    };
    await _box.put(_keyTextSize, value);
  }

  static double textScaleFactorFor(AppTextSize size) {
    return switch (size) {
      AppTextSize.small => 0.9,
      AppTextSize.medium => 1.0,
      AppTextSize.large => 1.18,
    };
  }

  static RegionSettings loadRegionSettings({required Locale deviceLocale}) {
    final useSystem = (_box.get(_keyRegionUseSystem) as bool?) ?? true;
    final languageCode = (_box.get(_keyRegionLanguageCode) as String?) ?? deviceLocale.languageCode;
    final countryCode = (_box.get(_keyRegionCountryCode) as String?) ?? (deviceLocale.countryCode ?? 'US');
    final measurementValue = _box.get(_keyMeasurementSystem) as String?;
    final measurementSystem = switch (measurementValue) {
      'imperial' => MeasurementSystem.imperial,
      'metric' => MeasurementSystem.metric,
      _ => measurementFromCountry(countryCode),
    };

    return RegionSettings(
      useSystemRegion: useSystem,
      languageCode: languageCode,
      countryCode: countryCode,
      measurementSystem: measurementSystem,
    );
  }

  static Future<void> saveRegionSettings(RegionSettings settings) async {
    await _box.put(_keyRegionUseSystem, settings.useSystemRegion);
    await _box.put(_keyRegionLanguageCode, settings.languageCode);
    await _box.put(_keyRegionCountryCode, settings.countryCode);
    await _box.put(
      _keyMeasurementSystem,
      settings.measurementSystem == MeasurementSystem.imperial ? 'imperial' : 'metric',
    );
  }

  static MeasurementSystem measurementFromCountry(String countryCode) {
    const imperialCountries = <String>{'US', 'LR', 'MM'};
    if (imperialCountries.contains(countryCode.toUpperCase())) {
      return MeasurementSystem.imperial;
    }
    return MeasurementSystem.metric;
  }
}
