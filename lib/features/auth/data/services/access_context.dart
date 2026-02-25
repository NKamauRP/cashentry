import '../../domain/app_role.dart';

class AccessContext {
  const AccessContext._();

  static String? userId;
  static String? branchId;
  static List<String> managedBranchIds = <String>[];
  static dynamic currentUser;
  static AppRole role = AppRole.user;
  static String currentRole = 'user';

  static bool get isAuthenticated => userId != null && userId!.isNotEmpty;

  static void update({
    String? nextUserId,
    String? nextBranchId,
    List<String>? nextManagedBranchIds,
    dynamic nextCurrentUser,
    AppRole? nextRole,
    String? nextRoleLabel,
  }) {
    userId = nextUserId;
    branchId = nextBranchId;
    managedBranchIds = List<String>.from(nextManagedBranchIds ?? <String>[]);
    currentUser = nextCurrentUser;
    if (nextRole != null) {
      role = nextRole;
    }
    final resolvedRole = nextRoleLabel ?? role.name;
    currentRole = resolvedRole.isEmpty ? 'user' : resolvedRole.toLowerCase();
  }

  static void clear() {
    update(
      nextUserId: null,
      nextBranchId: null,
      nextManagedBranchIds: const <String>[],
      nextCurrentUser: null,
      nextRole: AppRole.user,
      nextRoleLabel: 'user',
    );
  }
}
