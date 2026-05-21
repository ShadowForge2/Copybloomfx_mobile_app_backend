import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bloomfx_shared/bloomfx_shared.dart';
import '../providers/admin_support_provider.dart';
import '../providers/admin_auth_provider.dart';

class AdminSupportScreen extends StatefulWidget {
  const AdminSupportScreen({super.key});

  @override
  State<AdminSupportScreen> createState() => _AdminSupportScreenState();
}

class _AdminSupportScreenState extends State<AdminSupportScreen> {
  late TextEditingController _messageController;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    _scrollController = ScrollController();

    // Load conversations and start polling after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final support = Provider.of<AdminSupportProvider>(
        context,
        listen: false,
      );
      support.loadConversations();
      support.startPolling();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    // Stop polling when screen is disposed
    Provider.of<AdminSupportProvider>(context, listen: false).stopPolling();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendReply() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    final auth = Provider.of<AdminAuthProvider>(context, listen: false);
    final support = Provider.of<AdminSupportProvider>(context, listen: false);

    if (auth.adminUser == null) return;

    _messageController.clear();

    final success = await support.sendReply(message, auth.adminUser!.id);
    if (!success && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to send message')));
      _messageController.text = message;
    } else {
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AdminSupportProvider, AdminAuthProvider>(
      builder: (context, support, auth, _) {
        final selectedConv = support.selectedConversation;

        if (support.selectedConversationId == null) {
          return _buildConversationList(support);
        }

        return _buildChatView(support, auth, selectedConv);
      },
    );
  }

  Widget _buildConversationList(AdminSupportProvider support) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Color(0xFF1A1F2E),
            border: Border(bottom: BorderSide(color: Color(0xFF30363D))),
          ),
          child: Row(
            children: [
              const Icon(Icons.support_agent, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              const Text(
                'Support Conversations',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (support.totalUnreadCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${support.totalUnreadCount} new',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (support.errorMessage != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.red.shade900,
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    support.errorMessage!,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
                GestureDetector(
                  onTap: () => support.loadConversations(),
                  child: const Icon(Icons.refresh, color: Colors.white70, size: 18),
                ),
              ],
            ),
          ),
        // Conversations list
        Expanded(
          child: support.isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF58A6FF)),
                )
              : support.conversations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(
                        Icons.inbox_outlined,
                        color: Color(0xFF6E7681),
                        size: 48,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No support conversations',
                        style: TextStyle(color: Color(0xFF8B949E)),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => support.loadConversations(),
                  child: ListView.builder(
                    itemCount: support.conversations.length,
                    itemBuilder: (ctx, idx) {
                      final conv = support.conversations[idx];
                      final hasUnread = _getUnreadCount(support, conv.id) > 0;

                      return InkWell(
                        onTap: () => support.selectConversation(conv.id),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: hasUnread
                                ? const Color(0xFF0D1117)
                                : const Color(0xFF161B22),
                            border: Border(
                              bottom: BorderSide(
                                color: const Color(0xFF30363D),
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              // Unread indicator
                              if (hasUnread)
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(right: 12),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                )
                              else
                                const SizedBox(width: 20),
                              // Conversation info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'User ${conv.userId.substring(0, 8)}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      conv.status.toDisplayString(),
                                      style: TextStyle(
                                        color: _getStatusColor(conv.status),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Last message time
                              if (conv.lastMessageAt != null)
                                Text(
                                  _formatTime(conv.lastMessageAt!),
                                  style: const TextStyle(
                                    color: Color(0xFF8B949E),
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildChatView(
    AdminSupportProvider support,
    AdminAuthProvider auth,
    SupportConversation? conv,
  ) {
    return Column(
      children: [
        // Header with back button
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Color(0xFF1A1F2E),
            border: Border(bottom: BorderSide(color: Color(0xFF30363D))),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => support.deselectConversation(),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (conv != null) ...[
                      Text(
                        'User ${conv.userId.substring(0, 8)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        conv.status.toDisplayString(),
                        style: TextStyle(
                          color: _getStatusColor(conv.status),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton(
                itemBuilder: (ctx) => [
                  if (conv?.status != SupportConversationStatus.closed)
                    PopupMenuItem(
                      child: const Text('Close Conversation'),
                      onTap: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Close Conversation?'),
                            content: const Text(
                              'Mark this conversation as closed?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true && conv != null) {
                          await support.closeConversation(conv.id);
                        }
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
        // Messages
        Expanded(
          child: support.isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF58A6FF)),
                )
              : support.currentMessages.isEmpty
              ? const Center(
                  child: Text(
                    'No messages',
                    style: TextStyle(color: Color(0xFF8B949E)),
                  ),
                )
              : NotificationListener<ScrollUpdateNotification>(
                  onNotification: (notification) {
                    return false;
                  },
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: support.currentMessages.length,
                    itemBuilder: (ctx, idx) {
                      final msg = support.currentMessages[idx];
                      final isAdminMessage =
                          msg.senderType == MessageSenderType.admin;

                      return Align(
                        alignment: isAdminMessage
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isAdminMessage
                                ? const Color(0xFF1E3A8A)
                                : const Color(0xFF21262D),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                msg.message,
                                style: const TextStyle(color: Colors.white),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatTime(msg.createdAt),
                                style: const TextStyle(
                                  color: Color(0xFF8B949E),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
        // Input area
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFF161B22),
              border: Border(top: BorderSide(color: Color(0xFF30363D))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    enabled: !support.isSending,
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: 'Type your reply...',
                      hintStyle: const TextStyle(color: Color(0xFF8B949E)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF30363D)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF30363D)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF58A6FF)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton.small(
                  onPressed: support.isSending ? null : _sendReply,
                  backgroundColor: support.isSending
                      ? const Color(0xFF30363D)
                      : const Color(0xFF1E3A8A),
                  disabledElevation: 0,
                  child: support.isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.send, size: 20),
                ),
              ],
            ),
          ),
      ],
    );
  }

  int _getUnreadCount(AdminSupportProvider support, String conversationId) {
    return support.getUnreadCountForConversation(conversationId);
  }

  Color _getStatusColor(SupportConversationStatus status) {
    switch (status) {
      case SupportConversationStatus.open:
        return Colors.green;
      case SupportConversationStatus.closed:
        return Colors.grey;
      case SupportConversationStatus.waitingUser:
        return Colors.orange;
      case SupportConversationStatus.waitingAdmin:
        return Colors.blue;
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (msgDate == today) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (msgDate == yesterday) {
      return 'Yesterday';
    } else {
      return '${dateTime.day}/${dateTime.month}';
    }
  }
}
