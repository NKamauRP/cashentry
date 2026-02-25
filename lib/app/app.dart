import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_service.dart';
import '../core/widgets/glass_widgets.dart';
import '../core/widgets/role_guard.dart';
import '../features/admin/presentation/screens/admin_hub_screen.dart';
import '../features/analytics/presentation/screens/analytics_export_screen.dart';
import '../features/auth/data/services/auth_service.dart';
import '../features/auth/data/services/role_service.dart';
import '../features/auth/domain/app_role.dart';
import '../features/auth/presentation/controllers/access_controller.dart';
import '../features/auth/presentation/screens/auth_screen.dart';
import '../features/cash_entries/data/repositories/cash_entry_repository.dart';
import '../features/dashboard/presentation/screens/home_screen.dart';
import '../features/entries/presentation/screens/entries_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import '../features/sync/data/services/sync_service.dart';
import '../features/sync/presentation/controllers/sync_controller.dart';

class CashFlowApp extends StatefulWidget {
  const CashFlowApp({super.key});

  @override
  State<CashFlowApp> createState() => _CashFlowAppState();
}

class _CashFlowAppState extends State<CashFlowApp> {
  final CashEntryRepository _repository = CashEntryRepository();
  late final SyncController _syncController;
  late final AccessController _accessController;
  AuthService? _authService;
  int _currentIndex = 0;
  String? _lastResolvedUserId;
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
    if (SupabaseConfig.isConfigured) {
      _authService = AuthService();
    }
    _accessController = AccessController(roleService: RoleService());
    _syncController = SyncController(
      SyncService(repository: _repository),
    );
    _syncController.initialize();
  }

  @override
  void dispose() {
    _syncController.dispose();
    _accessController.dispose();
    super.dispose();
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

  Future<void> _signOut() async {
    await _authService?.logoutUser();
    await _syncController.clearOnSignOut();
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
      home: !SupabaseConfig.isConfigured
          ? const _SupabaseConfigRequiredScreen()
          : StreamBuilder<AuthState>(
              stream: _authService!.authStateChanges,
              initialData: AuthState(AuthChangeEvent.initialSession, _authService!.currentSession),
              builder: (context, snapshot) {
                final session = snapshot.data?.session ?? _authService!.currentSession;
                if (session == null) {
                  _accessController.syncForUser(null);
                  _lastResolvedUserId = null;
                  _currentIndex = 0;
                  return Scaffold(
                    body: MistyBackground(
                      child: SafeArea(
                        child: AuthScreen(
                          authService: _authService!,
                          // Auth stream will still drive the shell; this just eagerly refreshes role metadata.
                          onAuthenticated: () async {
                            await _authService?.refreshSessionAndRoleMetadata();
                            await _accessController.syncForUser(_authService?.currentUser?.id);
                          },
                        ),
                      ),
                    ),
                  );
                }
                return FutureBuilder<void>(
                  future: _accessController.syncForUser(session.user.id),
                  builder: (context, roleSnapshot) {
                    if (_accessController.isLoading) {
                      return const Scaffold(
                        body: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (_accessController.error != null) {
                      return _RoleFetchErrorScreen(
                        message: _accessController.error!,
                        onRetry: () => _accessController.syncForUser(session.user.id),
                        onSignOut: _signOut,
                      );
                    }
                    if (_lastResolvedUserId != session.user.id) {
                      _lastResolvedUserId = session.user.id;
                      _currentIndex = _landingTabForRole(_accessController.role);
                    }
                    return AnimatedBuilder(
                      animation: _accessController,
                      builder: (context, _) => _buildAuthenticatedShell(),
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildAuthenticatedShell() {
    final tabs = <_TabSpec>[
      _TabSpec(
        icon: _roleHomeIcon(),
        label: _roleHomeLabel(),
        screen: _roleHomeScreen(),
      ),
      _TabSpec(
        icon: Icons.list_alt_rounded,
        label: 'Entries',
        screen: EntriesScreen(
          repository: _repository,
          syncController: _syncController,
        ),
      ),
      if (_accessController.role == AppRole.admin)
        _TabSpec(
          icon: Icons.auto_graph_rounded,
          label: 'Analytics',
          screen: RoleGuard(
            allowedRoles: ['manager', 'admin'],
            child: AnalyticsExportScreen(repository: _repository),
          ),
        ),
      if (_accessController.role == AppRole.admin)
        const _TabSpec(
          icon: Icons.admin_panel_settings_rounded,
          label: 'Admin',
          screen: RoleGuard(
            allowedRoles: ['admin'],
            child: AdminHubScreen(),
          ),
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
          syncController: _syncController,
          onSignOut: _signOut,
          roleLabel: _accessController.role.label,
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

  int _landingTabForRole(AppRole role) {
    return 0;
  }

  Widget _roleHomeScreen() {
    switch (_accessController.role) {
      case AppRole.admin:
        return const AdminDashboard();
      case AppRole.manager:
        return ManagerDashboard(repository: _repository);
      case AppRole.user:
        return UserHome(
          repository: _repository,
          syncController: _syncController,
          roleLabel: _accessController.role.label,
        );
    }
  }

  String _roleHomeLabel() {
    switch (_accessController.role) {
      case AppRole.admin:
        return 'Admin';
      case AppRole.manager:
        return 'Manager';
      case AppRole.user:
        return 'Home';
    }
  }

  IconData _roleHomeIcon() {
    switch (_accessController.role) {
      case AppRole.admin:
        return Icons.admin_panel_settings_rounded;
      case AppRole.manager:
        return Icons.analytics_rounded;
      case AppRole.user:
        return Icons.dashboard_rounded;
    }
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

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) => const AdminHubScreen();
}

class ManagerDashboard extends StatelessWidget {
  const ManagerDashboard({
    super.key,
    required this.repository,
  });

  final CashEntryRepository repository;

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      allowedRoles: const ['manager', 'admin'],
      child: AnalyticsExportScreen(repository: repository),
    );
  }
}

class UserHome extends StatelessWidget {
  const UserHome({
    super.key,
    required this.repository,
    required this.syncController,
    required this.roleLabel,
  });

  final CashEntryRepository repository;
  final SyncController syncController;
  final String roleLabel;

  @override
  Widget build(BuildContext context) {
    return HomeScreen(
      repository: repository,
      syncController: syncController,
      roleLabel: roleLabel,
    );
  }
}

class _SupabaseConfigRequiredScreen extends StatelessWidget {
  const _SupabaseConfigRequiredScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MistyBackground(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GlassCard(
                glow: true,
                child: const Text(
                  'Supabase is not configured.\nRun with --dart-define=SUPABASE_URL=... and --dart-define=SUPABASE_ANON_KEY=...',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleFetchErrorScreen extends StatelessWidget {
  const _RoleFetchErrorScreen({
    required this.message,
    required this.onRetry,
    required this.onSignOut,
  });

  final String message;
  final Future<void> Function() onRetry;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MistyBackground(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GlassCard(
                glow: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Unable to load your role',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(message),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        ElevatedButton(
                          onPressed: () async => onRetry(),
                          child: const Text('Retry'),
                        ),
                        TextButton(
                          onPressed: () async => onSignOut(),
                          child: const Text('Sign out'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
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
