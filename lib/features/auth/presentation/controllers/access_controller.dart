import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/services/access_context.dart';
import '../../data/services/role_service.dart';
import '../../domain/app_role.dart';

class AccessController extends ChangeNotifier {
  AccessController({
    required RoleService roleService,
  }) : _roleService = roleService;

  final RoleService _roleService;

  bool isLoading = false;
  String? error;
  AppRole role = AppRole.user;
  String? userId;
  String? branchId;
  List<String> managedBranchIds = <String>[];

  Future<void> syncForUser(String? nextUserId) async {
    if (nextUserId == null || nextUserId.isEmpty) {
      _reset();
      return;
    }
    if (nextUserId == userId && !isLoading) {
      return;
    }

    isLoading = true;
    error = null;
    userId = nextUserId;
    notifyListeners();

    try {
      final roleRaw = await _roleService.fetchUserRole(nextUserId);
      role = parseAppRole(roleRaw);
      managedBranchIds = await _roleService.fetchManagedBranches(nextUserId);
      branchId = managedBranchIds.isNotEmpty ? managedBranchIds.first : null;
      _applyToContext();
      error = null;
    } catch (e) {
      role = AppRole.user;
      branchId = null;
      managedBranchIds = const <String>[];
      _applyToContext();
      error = null;
      debugPrint('AccessController: failed to load role metadata, defaulting to user. Error: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void _reset() {
    isLoading = false;
    error = null;
    role = AppRole.user;
    userId = null;
    branchId = null;
    managedBranchIds = const <String>[];
    _applyToContext();
    notifyListeners();
  }

  void _applyToContext() {
    AccessContext.update(
      nextUserId: userId,
      nextRole: role,
      nextRoleLabel: role.name,
      nextBranchId: branchId,
      nextManagedBranchIds: managedBranchIds,
      nextCurrentUser: Supabase.instance.client.auth.currentUser,
    );
  }
}
