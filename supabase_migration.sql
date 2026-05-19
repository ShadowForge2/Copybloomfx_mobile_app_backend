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
-- SERVICE ROLE PERMISSIONS
-- =============================================

-- Grant needed permissions to service_role
GRANT ALL ON support_conversations TO service_role;
GRANT ALL ON support_messages TO service_role;

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
DROP TRIGGER IF EXISTS support_messages_update_conversation_timestamp ON support_messages;
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
