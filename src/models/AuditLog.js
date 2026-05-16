import { DataTypes } from 'sequelize';
import { sequelize } from '../config/database.js';

const AuditLog = sequelize.define('AuditLog', {
  id: { type: DataTypes.UUID, defaultValue: DataTypes.UUIDV4, primaryKey: true },
  user_id: { type: DataTypes.STRING, allowNull: true },
  target_user_id: { type: DataTypes.STRING, allowNull: true },
  action: { type: DataTypes.STRING, allowNull: false },
  entity_type: { type: DataTypes.STRING },
  entity_id: { type: DataTypes.STRING },
  description: { type: DataTypes.TEXT },
  metadata: { type: DataTypes.TEXT },
  ip_address: { type: DataTypes.STRING },
  created_at: { type: DataTypes.DATE, defaultValue: DataTypes.NOW },
}, {
  tableName: 'audit_logs',
  timestamps: false,
});

export default AuditLog;
