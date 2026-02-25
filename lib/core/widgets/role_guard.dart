import 'package:flutter/material.dart';

import '../../features/auth/data/services/access_context.dart';
import '../../features/auth/domain/app_role.dart';
import 'glass_widgets.dart';

class RoleGuard extends StatelessWidget {
  const RoleGuard({
    super.key,
    required this.allowedRoles,
    required this.child,
    this.fallback,
  });

  final List<String> allowedRoles;
  final Widget child;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    if (_isAllowed()) {
      return child;
    }
    return fallback ??
        const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: GlassCard(
              glow: true,
              child: Text('You do not have permission to access this screen.'),
            ),
          ),
        );
  }

  bool _isAllowed() {
    final normalizedAllowedRoles = allowedRoles.map((role) => role.toLowerCase()).toSet();
    final currentRole = AccessContext.currentRole.toLowerCase();
    return normalizedAllowedRoles.contains(currentRole);
  }
}

extension RoleGuardAppRole on AppRole {
  String get roleName => name.toLowerCase();
}
