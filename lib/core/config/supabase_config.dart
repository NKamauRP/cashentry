class SupabaseConfig {
  const SupabaseConfig._();

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://gmebuekaeaefbejauneb.supabase.co',
  );
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdtZWJ1ZWthZWFlZmJlamF1bmViIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE5MTE4NDksImV4cCI6MjA4NzQ4Nzg0OX0.l68R0ONXGt-1Sxl0y018h6fdgg-Y-bWm72XjuI53Mu8',
  );

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
