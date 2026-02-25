import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/glass_widgets.dart';
import '../../data/services/auth_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.authService,
    this.onAuthenticated,
  });

  final AuthService authService;
  final Future<void> Function()? onAuthenticated;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true;
  bool _loading = false;
  bool _checkingHost = true;
  bool _hostReachable = true;
  String? _hostError;

  @override
  void initState() {
    super.initState();
    _checkSupabaseHealth();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: GlassCard(
            glow: true,
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isLogin ? 'Sign In' : 'Create Account',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Authenticate to access your cash flow workspace.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 14),
                  if (!_hostReachable)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: AppColors.danger.withValues(alpha: 0.12),
                        border: Border.all(color: AppColors.danger.withValues(alpha: 0.55)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Cannot reach Supabase host.',
                            style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.danger),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _hostError ?? 'Check internet, DNS, or Supabase URL.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 6),
                          TextButton.icon(
                            onPressed: _checkingHost ? null : _checkSupabaseHealth,
                            icon: _checkingHost
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Retry connection check'),
                          ),
                        ],
                      ),
                    ),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Email is required';
                      }
                      if (!value.contains('@')) {
                        return 'Enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Password is required';
                      }
                      if (value.length < 6) {
                        return 'Use at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: (_loading || _checkingHost) ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.teal,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(44),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(_isLogin ? 'Sign In' : 'Register'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () {
                            setState(() {
                              _isLogin = !_isLogin;
                            });
                          },
                    child: Text(
                      _isLogin ? 'Need an account? Register' : 'Already have an account? Sign in',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_hostReachable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Supabase host unreachable. Please retry after network check.')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _loading = true);
    try {
      if (_isLogin) {
        await widget.authService.loginUser(
          _emailController.text.trim(),
          _passwordController.text,
        );
      } else {
        await widget.authService.signUpUser(
          _emailController.text.trim(),
          _passwordController.text,
          'user',
        );
      }
      await widget.authService.refreshSessionAndRoleMetadata();
      await widget.onAuthenticated?.call();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isLogin ? 'Signed in successfully.' : 'Registration complete. You are signed in.'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Authentication failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _checkSupabaseHealth() async {
    setState(() {
      _checkingHost = true;
    });

    try {
      final uri = Uri.parse('${SupabaseConfig.url}/auth/v1/health');
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
      final request = await client.getUrl(uri);
      final response = await request.close();
      final reachable = response.statusCode >= 200 && response.statusCode < 500;
      client.close(force: true);

      if (!mounted) {
        return;
      }
      setState(() {
        _hostReachable = reachable;
        _hostError = reachable ? null : 'Host responded with status ${response.statusCode}.';
        _checkingHost = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _hostReachable = false;
        _hostError = error.toString();
        _checkingHost = false;
      });
    }
  }
}
