import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../providers/admin_notification_provider.dart';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() => _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _targetUsersController = TextEditingController();
  String _sendType = 'system_wide';
  String _notificationType = 'info';

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _targetUsersController.dispose();
    super.dispose();
  }

  void _send() {
    final title = _titleController.text.trim();
    final message = _messageController.text.trim();
    if (title.isEmpty || message.isEmpty) {
      Fluttertoast.showToast(msg: 'Title and message are required', backgroundColor: Colors.red, textColor: Colors.white);
      return;
    }
    if (_sendType == 'targeted') {
      final raw = _targetUsersController.text.trim();
      if (raw.isEmpty) {
        Fluttertoast.showToast(msg: 'Enter at least one target user', backgroundColor: Colors.red, textColor: Colors.white);
        return;
      }
      final targets = raw.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      context.read<AdminNotificationProvider>().sendNotification(
        title: title,
        message: message,
        sendType: _sendType,
        targetUsers: targets,
        type: _notificationType,
      ).then((ok) {
        if (ok) {
          _titleController.clear();
          _messageController.clear();
          _targetUsersController.clear();
        }
      });
    } else {
      context.read<AdminNotificationProvider>().sendNotification(
        title: title,
        message: message,
        sendType: _sendType,
        type: _notificationType,
      ).then((ok) {
        if (ok) {
          _titleController.clear();
          _messageController.clear();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminNotificationProvider>(
      builder: (context, provider, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Send Notification', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              // Notification Type
              const Text('Notification Type', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _notificationType,
                dropdownColor: const Color(0xFF21262D),
                decoration: _inputDecoration(),
                items: const [
                  DropdownMenuItem(value: 'info', child: Text('Information', style: TextStyle(color: Colors.white))),
                  DropdownMenuItem(value: 'success', child: Text('Success', style: TextStyle(color: Colors.white))),
                  DropdownMenuItem(value: 'warning', child: Text('Warning', style: TextStyle(color: Colors.white))),
                  DropdownMenuItem(value: 'urgent', child: Text('Urgent', style: TextStyle(color: Colors.white))),
                  DropdownMenuItem(value: 'maintenance', child: Text('Maintenance', style: TextStyle(color: Colors.white))),
                ],
                onChanged: (v) => setState(() => _notificationType = v ?? 'info'),
              ),
              const SizedBox(height: 16),

              // Title
              const Text('Title', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: _titleController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration(hint: 'Notification title'),
              ),
              const SizedBox(height: 16),

              // Message
              const Text('Message', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: _messageController,
                style: const TextStyle(color: Colors.white),
                maxLines: 4,
                decoration: _inputDecoration(hint: 'Notification message'),
              ),
              const SizedBox(height: 16),

              // Send Type
              const Text('Send To', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _sendType,
                dropdownColor: const Color(0xFF21262D),
                decoration: _inputDecoration(),
                items: const [
                  DropdownMenuItem(value: 'system_wide', child: Text('All Users (System Wide)', style: TextStyle(color: Colors.white))),
                  DropdownMenuItem(value: 'targeted', child: Text('Specific Users', style: TextStyle(color: Colors.white))),
                ],
                onChanged: (v) => setState(() => _sendType = v ?? 'system_wide'),
              ),
              const SizedBox(height: 16),

              // Target users
              if (_sendType == 'targeted') ...[
                const Text('Target Users (one per line - username or email)', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: _targetUsersController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 5,
                  decoration: _inputDecoration(hint: 'username1\nusername2\nemail@example.com'),
                ),
                const SizedBox(height: 16),
              ],

              // Send button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: provider.isLoading ? null : _send,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: provider.isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Send Notification', style: TextStyle(color: Colors.white, fontSize: 15)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF7D8590), fontSize: 13),
      filled: true,
      fillColor: const Color(0xFF21262D),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF30363D)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF30363D)),
      ),
    );
  }
}
