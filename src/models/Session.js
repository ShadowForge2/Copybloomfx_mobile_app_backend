import { DataTypes } from 'sequelize';
import { sequelize } from '../config/database.js';

const Session = sequelize.define('Session', {
  id: { type: DataTypes.UUID, defaultValue: DataTypes.UUIDV4, primaryKey: true },
  user_id: { type: DataTypes.STRING, allowNull: false },
  token_hash: { type: DataTypes.STRING, allowNull: false },
  ip_address: { type: DataTypes.STRING },
  user_agent: { type: DataTypes.TEXT },
  expires_at: { type: DataTypes.DATE },
  created_at: { type: DataTypes.DATE, defaultValue: DataTypes.NOW },
  last_accessed_at: { type: DataTypes.DATE, defaultValue: DataTypes.NOW },
}, {
  tableName: 'sessions',
  timestamps: false,
});

export default Session;
