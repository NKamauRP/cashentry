import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RoleService {
  RoleService({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<String> fetchUserRole(String userId) async {
    if (userId.isEmpty) {
      throw ArgumentError('userId must not be empty.');
    }
    final currentUser = _client.auth.currentUser;
    if (currentUser == null || currentUser.id != userId) {
      debugPrint('RoleService: authenticated user not found for role lookup, defaulting to user.');
      return 'user';
    }
    await _safeRefreshSession();
    final metadata = _client.auth.currentUser?.userMetadata;
    final role = metadata?['role']?.toString();
    if (role == null || role.trim().isEmpty) {
      debugPrint('RoleService: role metadata missing for user $userId, defaulting to user.');
      return 'user';
    }
    return role.toLowerCase();
  }

  Future<List<String>> fetchManagedBranches(String userId) async {
    if (userId.isEmpty) {
      return const <String>[];
    }
    final currentUser = _client.auth.currentUser;
    if (currentUser == null || currentUser.id != userId) {
      return const <String>[];
    }
    final rawBranches = currentUser.userMetadata?['managed_branch_ids'];
    if (rawBranches is List) {
      return rawBranches.map((item) => item.toString()).where((id) => id.trim().isNotEmpty).toList(growable: false);
    }
    return const <String>[];
  }

  Future<void> updateCurrentUserRole(String role) async {
    final normalizedRole = role.trim().toLowerCase();
    if (normalizedRole.isEmpty) {
      throw ArgumentError('role must not be empty.');
    }
    await _client.auth.updateUser(
      UserAttributes(
        data: {'role': normalizedRole},
      ),
    );
    await _safeRefreshSession();
  }

  Future<void> _safeRefreshSession() async {
    try {
      await _client.auth.refreshSession();
    } catch (error) {
      debugPrint('RoleService: session refresh failed: $error');
    }
  }
}
