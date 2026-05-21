import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/admin_auth_provider.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPinging = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      Fluttertoast.showToast(msg: 'Please enter username and password', toastLength: Toast.LENGTH_SHORT, gravity: ToastGravity.BOTTOM, backgroundColor: Colors.red, textColor: Colors.white);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final auth = Provider.of<AdminAuthProvider>(context, listen: false);
      final success = await auth.login(username, password);
      if (success && mounted) {
        Fluttertoast.showToast(msg: 'Welcome Admin', toastLength: Toast.LENGTH_SHORT, gravity: ToastGravity.BOTTOM, backgroundColor: Colors.green, textColor: Colors.white);
        context.go('/admin/dashboard');
      } else if (mounted) {
        final msg = auth.errorMessage ?? 'Login failed';
        Fluttertoast.showToast(msg: msg, toastLength: Toast.LENGTH_LONG, gravity: ToastGravity.BOTTOM, backgroundColor: Colors.red, textColor: Colors.white);
      }
    } catch (e) {
      if (mounted) Fluttertoast.showToast(msg: 'Login error: $e', toastLength: Toast.LENGTH_LONG, gravity: ToastGravity.BOTTOM, backgroundColor: Colors.red, textColor: Colors.white);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pingServer() async {
    setState(() => _isPinging = true);
    try {
      final url = 'https://copybloomfx-mobile-app-backend.onrender.com/api/health';
      final start = DateTime.now();
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      final ms = DateTime.now().difference(start).inMilliseconds;
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final uptime = (body['uptime'] as num?)?.toInt() ?? 0;
        Fluttertoast.showToast(
          msg: 'Server online (${ms}ms, uptime: ${uptime}s)',
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
      } else {
        Fluttertoast.showToast(
          msg: 'Server responded HTTP ${res.statusCode}',
          backgroundColor: Colors.orange,
          textColor: Colors.white,
        );
      }
    } on http.ClientException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('dns') || msg.contains('resolve')) {
        Fluttertoast.showToast(msg: 'DNS lookup failed — check your internet', backgroundColor: Colors.red, textColor: Colors.white, toastLength: Toast.LENGTH_LONG);
      } else if (msg.contains('timed out') || msg.contains('timeout')) {
        Fluttertoast.showToast(msg: 'Connection timed out (15s) — server took too long', backgroundColor: Colors.red, textColor: Colors.white, toastLength: Toast.LENGTH_LONG);
      } else if (msg.contains('connection refused')) {
        Fluttertoast.showToast(msg: 'Connection refused — server may be down', backgroundColor: Colors.red, textColor: Colors.white, toastLength: Toast.LENGTH_LONG);
      } else {
        Fluttertoast.showToast(msg: 'Network error: ${e.message.substring(0, e.message.length.clamp(0, 80))}', backgroundColor: Colors.red, textColor: Colors.white, toastLength: Toast.LENGTH_LONG);
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error: $e', backgroundColor: Colors.red, textColor: Colors.white, toastLength: Toast.LENGTH_LONG);
    } finally {
      if (mounted) setState(() => _isPinging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: const Color(0xFF1E3A8A), borderRadius: BorderRadius.circular(20)),
                    child: const Icon(Icons.admin_panel_settings, size: 60, color: Colors.white),
                  ),
                  const SizedBox(height: 24),
                  const Text('BloomFX Admin', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Administrative Control Panel', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: const Color(0xFF1A1F2E), borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: [
                        TextField(
                          controller: _usernameController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Email or Username', labelStyle: const TextStyle(color: Colors.white70),
                            prefixIcon: const Icon(Icons.person, color: Colors.white70),
                            filled: true, fillColor: const Color(0xFF0D1117),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Password', labelStyle: const TextStyle(color: Colors.white70),
                            prefixIcon: const Icon(Icons.lock, color: Colors.white70),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.white70),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            filled: true, fillColor: const Color(0xFF0D1117),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity, height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            child: _isLoading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Access Admin Panel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity, height: 44,
                          child: OutlinedButton.icon(
                            onPressed: _isPinging ? null : _pingServer,
                            icon: _isPinging
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70))
                                : const Icon(Icons.wifi_find, size: 18),
                            label: Text(_isPinging ? 'Waking server...' : 'Ping Server'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: const BorderSide(color: Colors.white24),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
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
}
