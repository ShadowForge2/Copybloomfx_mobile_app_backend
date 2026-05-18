import { DataTypes } from 'sequelize';
import { sequelize } from '../config/database.js';

const SupportConversation = sequelize.define('SupportConversation', {
  id: { type: DataTypes.UUID, primaryKey: true, defaultValue: DataTypes.UUIDV4 },
  user_id: { type: DataTypes.UUID, allowNull: false },
  status: { type: DataTypes.STRING, defaultValue: 'open' },
  last_message_at: { type: DataTypes.DATE },
  created_at: { type: DataTypes.DATE, defaultValue: DataTypes.NOW },
  updated_at: { type: DataTypes.DATE, defaultValue: DataTypes.NOW },
}, {
  tableName: 'support_conversations',
  timestamps: false,
});

export default SupportConversation;
