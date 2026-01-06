import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../dashboard/admin_dashboard_shell.dart';
import 'admin_login_screen.dart';

/// Controla se mostra login ou dashboard, baseado na sessão atual
class AdminAuthGate extends StatefulWidget {
  const AdminAuthGate({super.key});

  @override
  State<AdminAuthGate> createState() => _AdminAuthGateState();
}

class _AdminAuthGateState extends State<AdminAuthGate> {
  Session? _session;
  bool _checkingAdmin = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final supabase = Supabase.instance.client;
    final currentSession = supabase.auth.currentSession;

    if (currentSession == null) {
      setState(() {
        _checkingAdmin = false;
        _session = null;
      });
      return;
    }

    final isAdmin = await _checkIsAdmin(currentSession);

    setState(() {
      _session = currentSession;
      _isAdmin = isAdmin;
      _checkingAdmin = false;
    });

    supabase.auth.onAuthStateChange.listen((event) async {
      final newSession = event.session;
      if (!mounted) return;

      if (newSession == null) {
        setState(() {
          _session = null;
          _isAdmin = false;
        });
        return;
      }

      final admin = await _checkIsAdmin(newSession);
      if (!mounted) return;
      setState(() {
        _session = newSession;
        _isAdmin = admin;
      });
    });
  }

  Future<bool> _checkIsAdmin(Session session) async {
    final supabase = Supabase.instance.client;
    final userId = session.user.id;

    final response = await supabase
        .from('admin_users')
        .select('user_id')
        .eq('user_id', userId)
        .maybeSingle();

    return response != null;
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingAdmin) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_session == null || !_isAdmin) {
      return const AdminLoginScreen();
    }

    return AdminDashboardShell(session: _session!);
  }
}
