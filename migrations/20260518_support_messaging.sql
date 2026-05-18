-- =============================================
-- Support Messaging Feature
-- Created: 2026-05-18
-- Support conversations and messages tables with RLS
-- =============================================

-- 15. SUPPORT_CONVERSATIONS
CREATE TABLE IF NOT EXISTS support_conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status TEXT DEFAULT 'open' CHECK (status IN ('open', 'closed', 'waiting_user', 'waiting_admin')),
  last_message_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 16. SUPPORT_MESSAGES
CREATE TABLE IF NOT EXISTS support_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES support_conversations(id) ON DELETE CASCADE,
  sender_type TEXT NOT NULL CHECK (sender_type IN ('user', 'admin')),
  sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  message TEXT NOT NULL,
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================
-- INDEXES (optimized for realtime queries)
-- =============================================
CREATE INDEX IF NOT EXISTS idx_support_conversations_user_id ON support_conversations(user_id);
CREATE INDEX IF NOT EXISTS idx_support_conversations_status ON support_conversations(status);
CREATE INDEX IF NOT EXISTS idx_support_conversations_last_message_at ON support_conversations(last_message_at DESC);
CREATE INDEX IF NOT EXISTS idx_support_conversations_created_at ON support_conversations(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_support_conversations_user_status ON support_conversations(user_id, status);

CREATE INDEX IF NOT EXISTS idx_support_messages_conversation_id ON support_messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_support_messages_sender_id ON support_messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_support_messages_sender_type ON support_messages(sender_type);
CREATE INDEX IF NOT EXISTS idx_support_messages_is_read ON support_messages(is_read);
CREATE INDEX IF NOT EXISTS idx_support_messages_created_at ON support_messages(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_support_messages_conversation_unread ON support_messages(conversation_id, is_read);
CREATE INDEX IF NOT EXISTS idx_support_messages_conversation_recent ON support_messages(conversation_id, created_at DESC);

-- =============================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- =============================================

-- Enable RLS on support tables
ALTER TABLE support_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE support_messages ENABLE ROW LEVEL SECURITY;

-- SUPPORT_CONVERSATIONS RLS Policies
-- 1. Users can view only their own conversations
CREATE POLICY "Users can view own conversations"
  ON support_conversations FOR SELECT
  USING (auth.uid()::text = user_id::text OR EXISTS (
    SELECT 1 FROM users WHERE users.id = auth.uid()::uuid AND users.role = 'admin'
  ));

-- 2. Users can create their own conversations
CREATE POLICY "Users can create conversations"
  ON support_conversations FOR INSERT
  WITH CHECK (auth.uid()::text = user_id::text);

-- 3. Only admins and conversation owners can update status
CREATE POLICY "Update conversation status"
  ON support_conversations FOR UPDATE
  USING (
    auth.uid()::text = user_id::text OR EXISTS (
      SELECT 1 FROM users WHERE users.id = auth.uid()::uuid AND users.role = 'admin'
    )
  )
  WITH CHECK (
    auth.uid()::text = user_id::text OR EXISTS (
      SELECT 1 FROM users WHERE users.id = auth.uid()::uuid AND users.role = 'admin'
    )
  );

-- SUPPORT_MESSAGES RLS Policies
-- 1. Users can view messages from their own conversations
CREATE POLICY "Users can view own conversation messages"
  ON support_messages FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM support_conversations
      WHERE support_conversations.id = conversation_id
      AND (
        support_conversations.user_id = auth.uid()::uuid OR
        EXISTS (SELECT 1 FROM users WHERE users.id = auth.uid()::uuid AND users.role = 'admin')
      )
    )
  );

-- 2. Users can insert messages into their own conversations
CREATE POLICY "Users can send messages to own conversations"
  ON support_messages FOR INSERT
  WITH CHECK (
    sender_id = auth.uid()::uuid AND
    EXISTS (
      SELECT 1 FROM support_conversations
      WHERE support_conversations.id = conversation_id
      AND support_conversations.user_id = auth.uid()::uuid
    )
  );

-- 3. Admins can insert messages to any conversation
CREATE POLICY "Admins can send messages to any conversation"
  ON support_messages FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM users WHERE users.id = auth.uid()::uuid AND users.role = 'admin'
    )
    AND sender_type = 'admin'
    AND sender_id = auth.uid()::uuid
  );

-- 4. Users and admins can update is_read for messages they can see
CREATE POLICY "Mark messages as read"
  ON support_messages FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM support_conversations
      WHERE support_conversations.id = conversation_id
      AND (
        support_conversations.user_id = auth.uid()::uuid OR
        EXISTS (SELECT 1 FROM users WHERE users.id = auth.uid()::uuid AND users.role = 'admin')
      )
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM support_conversations
      WHERE support_conversations.id = conversation_id
      AND (
        support_conversations.user_id = auth.uid()::uuid OR
        EXISTS (SELECT 1 FROM users WHERE users.id = auth.uid()::uuid AND users.role = 'admin')
      )
    )
  );

-- =============================================
-- HELPER FUNCTION: update_conversation_timestamp
-- Called by trigger when new message inserted
-- =============================================
CREATE OR REPLACE FUNCTION update_support_conversation_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE support_conversations
  SET last_message_at = NEW.created_at, updated_at = NOW()
  WHERE id = NEW.conversation_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to update conversation timestamp on new message
CREATE TRIGGER support_messages_update_conversation_timestamp
  AFTER INSERT ON support_messages
  FOR EACH ROW
  EXECUTE FUNCTION update_support_conversation_timestamp();

-- =============================================
-- NOTES
-- =============================================
-- RLS Policies use auth.uid() which is set by Supabase authentication
-- Make sure to use Supabase JWT tokens in API calls
-- All queries will automatically filter based on user role and permissions
