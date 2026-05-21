import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bloomfx_shared/bloomfx_shared.dart';
import '../providers/support_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';

class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({super.key});

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  late TextEditingController _messageController;
  late ScrollController _scrollController;
  bool _shouldAutoScroll = true;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    _scrollController = ScrollController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final support = Provider.of<SupportProvider>(context, listen: false);
      if (auth.user != null) {
        support.initializeChat(auth.user!.id, auth.user!.id);
        support.startPolling();
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    Provider.of<SupportProvider>(context, listen: false).stopPolling();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_shouldAutoScroll && _scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final support = Provider.of<SupportProvider>(context, listen: false);

    if (auth.user == null) return;

    _messageController.clear();

    final success = await support.sendMessage(message, auth.user!.id);
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
    return Consumer3<SupportProvider, ThemeProvider, AuthProvider>(
      builder: (context, support, theme, auth, _) {
        final c = theme.colors;
        final user = auth.user;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Support'),
            backgroundColor: c.cardBg,
            foregroundColor: c.textPrimary,
            elevation: 0,
          ),
          body: user == null
              ? const Center(child: Text('Not logged in'))
              : _buildBody(support, user.id, c),
        );
      },
    );
  }

  Widget _buildBody(SupportProvider support, String userId, dynamic c) {
    if (support.isLoading && support.messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (support.errorMessage != null && support.currentConversation == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                support.errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textSecondary),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  support.clearError();
                  support.initializeChat(userId, userId);
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Thin status bar
        if (support.currentConversation != null)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
            color: c.surfaceBg,
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: support.currentConversation!.status ==
                            SupportConversationStatus.open
                        ? Colors.green
                        : Colors.grey,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  support.currentConversation!.status.toDisplayString(),
                  style: TextStyle(color: c.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),

        // Messages
        Expanded(
          child: support.messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_outlined, color: c.iconColor, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'No messages yet',
                        style: TextStyle(color: c.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Send a message to start chatting',
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )
              : NotificationListener<ScrollUpdateNotification>(
                  onNotification: (notification) {
                    _shouldAutoScroll =
                        notification.metrics.pixels >=
                        notification.metrics.maxScrollExtent - 100;
                    return false;
                  },
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    itemCount: support.messages.length,
                    itemBuilder: (ctx, idx) {
                      final msg = support.messages[idx];
                      final isUserMessage =
                          msg.senderType == MessageSenderType.user;

                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!msg.isRead && !isUserMessage) {
                          support.markMessageAsRead(msg.id);
                        }
                      });

                      return Align(
                        alignment: isUserMessage
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isUserMessage
                                ? c.accentBlue
                                : c.surfaceBg,
                            borderRadius: BorderRadius.circular(18),
                            border: isUserMessage
                                ? null
                                : Border.all(color: c.border),
                          ),
                          constraints: BoxConstraints(
                            maxWidth:
                                MediaQuery.of(context).size.width * 0.75,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                msg.message,
                                style: TextStyle(
                                  color: isUserMessage
                                      ? Colors.white
                                      : c.textPrimary,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatTime(msg.createdAt),
                                style: TextStyle(
                                  color: isUserMessage
                                      ? Colors.white60
                                      : c.textSecondary,
                                  fontSize: 10,
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

        // Facebook-style input area
        Container(
          padding: EdgeInsets.only(
            left: 12,
            right: 8,
            top: 8,
            bottom: MediaQuery.of(context).padding.bottom + 8,
          ),
          decoration: BoxDecoration(
            color: c.cardBg,
            border: Border(top: BorderSide(color: c.border)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  enabled: !support.isSending,
                  textInputAction: TextInputAction.send,
                  maxLines: 4,
                  minLines: 1,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: InputDecoration(
                    hintText: 'Message...',
                    hintStyle: TextStyle(color: c.textSecondary, fontSize: 14),
                    filled: true,
                    fillColor: c.surfaceBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    isDense: true,
                  ),
                  style: TextStyle(color: c.textPrimary, fontSize: 14),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: support.isSending ? null : _sendMessage,
                icon: Icon(
                  Icons.send_rounded,
                  color: support.isSending
                      ? c.textSecondary
                      : c.accentBlue,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (msgDate == today) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (msgDate == yesterday) {
      return 'Yesterday ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
