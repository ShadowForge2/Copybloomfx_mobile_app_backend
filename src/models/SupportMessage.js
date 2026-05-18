import { DataTypes } from 'sequelize';
import { sequelize } from '../config/database.js';

const SupportMessage = sequelize.define('SupportMessage', {
  id: { type: DataTypes.UUID, primaryKey: true, defaultValue: DataTypes.UUIDV4 },
  conversation_id: { type: DataTypes.UUID, allowNull: false },
  sender_type: { type: DataTypes.STRING, allowNull: false },
  sender_id: { type: DataTypes.UUID, allowNull: false },
  message: { type: DataTypes.TEXT, allowNull: false },
  is_read: { type: DataTypes.BOOLEAN, defaultValue: false },
  created_at: { type: DataTypes.DATE, defaultValue: DataTypes.NOW },
}, {
  tableName: 'support_messages',
  timestamps: false,
});

export default SupportMessage;
