import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/theme_service.dart';
import '../core/widgets/glass_widgets.dart';
import '../features/analytics/presentation/screens/analytics_export_screen.dart';
import '../features/cash_entries/data/repositories/cash_entry_repository.dart';
import '../features/dashboard/presentation/screens/home_screen.dart';
import '../features/entries/presentation/screens/entries_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';

class CashFlowApp extends StatefulWidget {
  const CashFlowApp({super.key});

  @override
  State<CashFlowApp> createState() => _CashFlowAppState();
}

class _CashFlowAppState extends State<CashFlowApp> {
  final CashEntryRepository _repository = CashEntryRepository();
  int _currentIndex = 0;
  late ThemeMode _themeMode;
  late AppTextSize _textSize;
  late RegionSettings _regionSettings;
  late Locale _deviceLocale;

  @override
  void initState() {
    super.initState();
    _themeMode = ThemeService.loadThemeMode();
    _textSize = ThemeService.loadTextSize();
    _deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;
    _regionSettings = ThemeService.loadRegionSettings(deviceLocale: _deviceLocale);
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    setState(() {
      _themeMode = mode;
    });
    await ThemeService.saveThemeMode(mode);
  }

  Future<void> _setTextSize(AppTextSize size) async {
    setState(() {
      _textSize = size;
    });
    await ThemeService.saveTextSize(size);
  }

  Future<void> _setRegionSettings(RegionSettings settings) async {
    setState(() {
      _regionSettings = settings;
    });
    await ThemeService.saveRegionSettings(settings);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode,
      locale: _regionSettings.useSystemRegion ? null : _regionSettings.locale,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: TextScaler.linear(ThemeService.textScaleFactorFor(_textSize)),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: _buildShell(),
    );
  }

  Widget _buildShell() {
    final tabs = <_TabSpec>[
      _TabSpec(
        icon: Icons.dashboard_rounded,
        label: 'Dashboard',
        screen: HomeScreen(
          repository: _repository,
        ),
      ),
      _TabSpec(
        icon: Icons.list_alt_rounded,
        label: 'Entries',
        screen: EntriesScreen(
          repository: _repository,
        ),
      ),
      _TabSpec(
        icon: Icons.auto_graph_rounded,
        label: 'Analytics',
        screen: AnalyticsExportScreen(repository: _repository),
      ),
      _TabSpec(
        icon: Icons.settings_rounded,
        label: 'Settings',
        screen: SettingsScreen(
          themeMode: _themeMode,
          textSize: _textSize,
          regionSettings: _regionSettings,
          deviceLocale: _deviceLocale,
          onThemeModeChanged: _setThemeMode,
          onTextSizeChanged: _setTextSize,
          onRegionSettingsChanged: _setRegionSettings,
        ),
      ),
    ];

    final selectedIndex = _currentIndex >= tabs.length ? tabs.length - 1 : _currentIndex;
    if (_currentIndex != selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _currentIndex = selectedIndex;
          });
        }
      });
    }

    return Scaffold(
      extendBody: true,
      body: MistyBackground(
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            child: KeyedSubtree(
              key: ValueKey<int>(selectedIndex),
              child: tabs[selectedIndex].screen,
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: GlassCard(
          borderRadius: 24,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (int i = 0; i < tabs.length; i++)
                _NavButton(
                  index: i,
                  currentIndex: selectedIndex,
                  icon: tabs[i].icon,
                  label: tabs[i].label,
                  onTap: _onTapNav,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _onTapNav(int index) {
    if (_currentIndex == index) {
      return;
    }
    setState(() {
      _currentIndex = index;
    });
  }
}

typedef _NavDestination = Widget;

class _TabSpec {
  const _TabSpec({
    required this.icon,
    required this.label,
    required this.screen,
  });

  final IconData icon;
  final String label;
  final _NavDestination screen;
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.index,
    required this.currentIndex,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final int index;
  final int currentIndex;
  final IconData icon;
  final String label;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => onTap(index),
      child: GlowNavItem(
        icon: icon,
        label: label,
        active: currentIndex == index,
      ),
    );
  }
}
