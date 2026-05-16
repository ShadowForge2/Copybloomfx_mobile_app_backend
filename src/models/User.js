import { DataTypes } from 'sequelize';
import { sequelize } from '../config/database.js';

const User = sequelize.define('User', {
  id: { type: DataTypes.UUID, primaryKey: true, defaultValue: DataTypes.UUIDV4 },
  auth_user_id: { type: DataTypes.TEXT, unique: true },
  username: { type: DataTypes.TEXT, unique: true, allowNull: false },
  email: { type: DataTypes.TEXT },
  role: { type: DataTypes.TEXT, defaultValue: 'user' },
  status: { type: DataTypes.TEXT, defaultValue: 'active' },
  is_flagged: { type: DataTypes.BOOLEAN, defaultValue: false },
  is_banned: { type: DataTypes.BOOLEAN, defaultValue: false },
  last_login_ip: { type: DataTypes.TEXT },
  password_hash: { type: DataTypes.TEXT },
  created_at: { type: DataTypes.DATE, defaultValue: DataTypes.NOW },
}, {
  tableName: 'users',
});

export default User;
