import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class UsernameSetupScreen extends StatefulWidget {
  final String email;
  final String firstName;
  final String lastName;
  final String password;
  final String referralCode;

  const UsernameSetupScreen({
    super.key,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.password,
    this.referralCode = '',
  });

  @override
  State<UsernameSetupScreen> createState() => _UsernameSetupScreenState();
}

class _UsernameSetupScreenState extends State<UsernameSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _referralCodeController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _referralCodeController.dispose();
    super.dispose();
  }

  Future<void> _completeRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    final router = GoRouter.of(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    setState(() {
      _isLoading = true;
    });

    try {
      // Validate all required data is present
      if (widget.firstName.isEmpty || 
          widget.lastName.isEmpty || 
          widget.password.isEmpty) {
        Fluttertoast.showToast(
          msg: "Registration data is incomplete. Please start over.",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        router.go('/register');
        return;
      }

      final success = await authProvider.registerWithDetails(
        widget.firstName,
        widget.lastName,
        widget.email,
        widget.password,
        username: _usernameController.text.trim(),
        referralCode: _referralCodeController.text.trim(),
      );

      if (success) {
        Fluttertoast.showToast(
          msg: "Registration successful! Please login to continue.",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
        // Clear any stored auth data to force fresh login
        await authProvider.logout();
        router.go('/login');
      } else {
        Fluttertoast.showToast(
          msg: authProvider.errorMessage ?? "Registration failed. Please try again.",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Registration failed. Please try again.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A8A),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 60),
              // Logo and Title
              const Icon(
                Icons.currency_exchange,
                size: 80,
                color: Colors.white,
              ),
              const SizedBox(height: 20),
              const Text(
                'BloomFX',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Choose Your Username',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 60),
              // Username Setup Form
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Almost Done!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Welcome, ${widget.firstName}!',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 30),
                      TextFormField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          labelText: 'Username',
                          prefixIcon: const Icon(Icons.alternate_email, color: Color(0xFF7D8590)),
                          helperText: 'This will be your unique identifier',
                          helperStyle: const TextStyle(color: Color(0xFF7D8590)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF30363D)),
                          ),
                          filled: true,
                          fillColor: const Color(0xFF21262D),
                          labelStyle: const TextStyle(color: Color(0xFF7D8590)),
                          hintStyle: const TextStyle(color: Color(0xFF7D8590)),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a username';
                          }
                          if (value.length < 3) {
                            return 'Username must be at least 3 characters';
                          }
                          if (value.length > 20) {
                            return 'Username must be less than 20 characters';
                          }
                          if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
                            return 'Username can only contain letters, numbers, and underscores';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _referralCodeController,
                        decoration: InputDecoration(
                          labelText: 'Referral Code (optional)',
                          prefixIcon: const Icon(Icons.card_giftcard, color: Color(0xFF7D8590)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF30363D)),
                          ),
                          filled: true,
                          fillColor: const Color(0xFF21262D),
                          labelStyle: const TextStyle(color: Color(0xFF7D8590)),
                          hintStyle: const TextStyle(color: Color(0xFF7D8590)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _completeRegistration,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E3A8A),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text(
                                  'Complete Registration',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          context.go('/register');
                        },
                        child: const Text(
                          'Go Back',
                          style: TextStyle(
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
