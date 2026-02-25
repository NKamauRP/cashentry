import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/app_role.dart';
import 'access_context.dart';

class AuthService {
  AuthService({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Session? get currentSession => _client.auth.currentSession;
  User? get currentUser => _client.auth.currentUser;

  Future<AuthResponse> signUpUser(
    String email,
    String password,
    String role,
  ) async {
    final normalizedRole = role.trim().isEmpty ? 'user' : role.trim().toLowerCase();
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'role': normalizedRole},
    );
    await _refreshSessionAndMetadata();
    return response;
  }

  Future<User> loginUser(String email, String password) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    await _refreshSessionAndMetadata();
    final user = response.user ?? _client.auth.currentUser;
    if (user == null) {
      throw StateError('Authenticated user was not returned after login.');
    }
    _applyRoleToAccessContext(_readRoleFromCurrentUserMetadata());
    return user;
  }

  Future<String> getCurrentUserRole() async {
    await _refreshSessionAndMetadata();
    final role = _readRoleFromCurrentUserMetadata();
    _applyRoleToAccessContext(role);
    return role;
  }

  Future<void> logoutUser() async {
    await _client.auth.signOut();
    AccessContext.clear();
  }

  Future<void> refreshSessionAndRoleMetadata() => _refreshSessionAndMetadata();

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await loginUser(email, password);
    return AuthResponse(
      user: _client.auth.currentUser,
      session: _client.auth.currentSession,
    );
  }

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String role = 'user',
  }) async {
    return signUpUser(email, password, role);
  }

  Future<void> signOut() => logoutUser();

  String? currentUserRoleFromMetadata() {
    return _readRoleFromCurrentUserMetadata();
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
    await _refreshSessionAndMetadata();
    _applyRoleToAccessContext(normalizedRole);
  }

  Future<void> _refreshSessionAndMetadata() async {
    try {
      await _client.auth.refreshSession();
    } catch (error) {
      // Refresh can fail on expired sessions; role fallback still keeps app usable.
      debugPrint('AuthService: session refresh failed: $error');
    }
    _applyRoleToAccessContext(_readRoleFromCurrentUserMetadata());
  }

  String _readRoleFromCurrentUserMetadata() {
    final metadata = _client.auth.currentUser?.userMetadata;
    final rawRole = metadata?['role']?.toString();
    final normalizedRole = rawRole?.trim().toLowerCase();
    if (normalizedRole == null || normalizedRole.isEmpty) {
      debugPrint('AuthService: role metadata missing, defaulting to user.');
      return 'user';
    }
    return normalizedRole;
  }

  void _applyRoleToAccessContext(String roleName) {
    final parsedRole = parseAppRole(roleName);
    AccessContext.update(
      nextUserId: _client.auth.currentUser?.id,
      nextRole: parsedRole,
      nextRoleLabel: roleName,
      nextCurrentUser: _client.auth.currentUser,
    );
  }
}
