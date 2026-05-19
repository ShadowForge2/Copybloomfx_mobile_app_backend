import { Router } from 'express';
import { authMiddleware, adminOnly } from '../middleware/auth.js';
import {
  getOrCreateSupportConversation,
  getSupportConversation,
  getSupportConversations,
  updateSupportConversation,
  getSupportMessages,
  createSupportMessage,
  markSupportMessageAsRead,
  countUnreadConversationMessages,
  createNotification,
  getUsers,
} from '../config/data.js';

const router = Router();

// All routes require authentication
router.use(authMiddleware);

// ==============================
// USER ENDPOINTS
// ==============================

// GET /api/support/conversation/:userId — get or create conversation
router.get('/conversation/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const requestingUserId = req.user.id;

    if (requestingUserId !== userId && req.user.role !== 'admin') {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const conversation = await getOrCreateSupportConversation(userId);
    res.json({ conversation });
  } catch (e) {
    console.error('[Support] getOrCreateConversation error:', e);
    res.status(500).json({ error: 'Failed to get or create conversation' });
  }
});

// ==============================
// ADMIN ENDPOINTS
// ==============================

// GET /api/support/conversations — list all conversations (admin)
router.get('/conversations', adminOnly, async (req, res) => {
  try {
    const conversations = await getSupportConversations();
    res.json({ conversations });
  } catch (e) {
    console.error('[Support] listConversations error:', e);
    res.status(500).json({ error: 'Failed to load conversations' });
  }
});

// GET /api/support/conversations/:conversationId/messages — get messages
router.get('/conversations/:conversationId/messages', async (req, res) => {
  try {
    const { conversationId } = req.params;
    const conversation = await getSupportConversation(conversationId);
    if (!conversation) {
      return res.status(404).json({ error: 'Conversation not found' });
    }

    const requestingUserId = req.user.id;
    if (conversation.user_id !== requestingUserId && req.user.role !== 'admin') {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const messages = await getSupportMessages(conversationId);
    res.json({ messages });
  } catch (e) {
    console.error('[Support] getMessages error:', e);
    res.status(500).json({ error: 'Failed to load messages' });
  }
});

// POST /api/support/conversations/:conversationId/messages — send a message
router.post('/conversations/:conversationId/messages', async (req, res) => {
  try {
    const { conversationId } = req.params;
    const { message } = req.body;
    const senderId = req.user.id;
    const userRole = req.user.role;

    if (!message || !message.trim()) {
      return res.status(400).json({ error: 'Message is required' });
    }

    const conversation = await getSupportConversation(conversationId);
    if (!conversation) {
      return res.status(404).json({ error: 'Conversation not found' });
    }

    if (conversation.status === 'closed') {
      await updateSupportConversation(conversationId, {
        status: 'open',
        updated_at: new Date().toISOString(),
      });
    }

    if (conversation.user_id !== senderId && userRole !== 'admin') {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const senderType = userRole === 'admin' ? 'admin' : 'user';
    const newStatus = senderType === 'admin' ? 'waiting_user' : 'waiting_admin';

    const supportMessage = await createSupportMessage({
      conversation_id: conversationId,
      sender_type: senderType,
      sender_id: senderId,
      message: message.trim(),
    });

    await updateSupportConversation(conversationId, {
      status: newStatus,
      last_message_at: supportMessage.created_at || new Date().toISOString(),
      updated_at: new Date().toISOString(),
    });

    // Fire in-app notification
    if (senderType === 'admin') {
      createNotification(
        conversation.user_id,
        'Support Reply',
        'Admin replied to your support ticket',
        'info',
      ).catch(() => {});
    } else {
      try {
        const admins = await getUsers({ role: 'admin' });
        for (const admin of admins) {
          createNotification(
            admin.id,
            'New Support Message',
            `User ${conversation.user_id.substring(0, 8)} sent a message`,
            'info',
          ).catch(() => {});
        }
      } catch (_) {}
    }

    res.json({ message: supportMessage });
  } catch (e) {
    console.error('[Support] sendMessage error:', e);
    res.status(500).json({ error: 'Failed to send message' });
  }
});

// PATCH /api/support/messages/:messageId/read — mark message as read
router.patch('/messages/:messageId/read', async (req, res) => {
  try {
    const { messageId } = req.params;
    await markSupportMessageAsRead(messageId);
    res.json({ success: true });
  } catch (e) {
    console.error('[Support] markRead error:', e);
    res.status(500).json({ error: 'Failed to mark message as read' });
  }
});

// PATCH /api/support/conversations/:conversationId/close — close conversation
router.patch('/conversations/:conversationId/close', async (req, res) => {
  try {
    const { conversationId } = req.params;
    const conversation = await getSupportConversation(conversationId);
    if (!conversation) {
      return res.status(404).json({ error: 'Conversation not found' });
    }

    const userId = req.user.id;
    if (conversation.user_id !== userId && req.user.role !== 'admin') {
      return res.status(403).json({ error: 'Forbidden' });
    }

    await updateSupportConversation(conversationId, {
      status: 'closed',
      updated_at: new Date().toISOString(),
    });

    res.json({ success: true });
  } catch (e) {
    console.error('[Support] closeConversation error:', e);
    res.status(500).json({ error: 'Failed to close conversation' });
  }
});

// GET /api/support/conversations/:conversationId/unread — get unread count
router.get('/conversations/:conversationId/unread', async (req, res) => {
  try {
    const { conversationId } = req.params;
    const count = await countUnreadConversationMessages(conversationId);
    res.json({ count });
  } catch (e) {
    console.error('[Support] unreadCount error:', e);
    res.status(500).json({ error: 'Failed to get unread count' });
  }
});

export default router;
