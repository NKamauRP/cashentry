enum AppRole {
  user,
  manager,
  admin,
}

extension AppRoleX on AppRole {
  String get label {
    switch (this) {
      case AppRole.user:
        return 'User';
      case AppRole.manager:
        return 'Manager';
      case AppRole.admin:
        return 'Admin';
    }
  }
}

AppRole parseAppRole(String? rawValue) {
  switch ((rawValue ?? '').toLowerCase()) {
    case 'admin':
      return AppRole.admin;
    case 'manager':
      return AppRole.manager;
    default:
      return AppRole.user;
  }
}
