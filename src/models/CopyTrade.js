import { DataTypes } from 'sequelize';
import { sequelize } from '../config/database.js';

const CopyTrade = sequelize.define('CopyTrade', {
  id: { type: DataTypes.UUID, primaryKey: true, defaultValue: DataTypes.UUIDV4 },
  user_id: { type: DataTypes.UUID, allowNull: false },
  pair: { type: DataTypes.TEXT },
  action: { type: DataTypes.TEXT },
  amount: { type: DataTypes.DECIMAL, defaultValue: 0 },
  profit: { type: DataTypes.DECIMAL, defaultValue: 0 },
  status: { type: DataTypes.TEXT, defaultValue: 'pending' },
  close_at: { type: DataTypes.DATE, allowNull: true },
  created_at: { type: DataTypes.DATE, defaultValue: DataTypes.NOW },
}, {
  tableName: 'copy_trades',
});

export default CopyTrade;
