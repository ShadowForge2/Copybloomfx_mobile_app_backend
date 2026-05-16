import { DataTypes } from 'sequelize';
import { sequelize } from '../config/database.js';

const Transaction = sequelize.define('Transaction', {
  id: { type: DataTypes.UUID, primaryKey: true, defaultValue: DataTypes.UUIDV4 },
  user_id: { type: DataTypes.UUID, allowNull: false },
  type: { type: DataTypes.TEXT, allowNull: false },
  amount: { type: DataTypes.DECIMAL, allowNull: false },
  status: { type: DataTypes.TEXT, defaultValue: 'completed' },
  description: { type: DataTypes.TEXT },
  reference: { type: DataTypes.TEXT },
  processed_at: { type: DataTypes.DATE },
  created_at: { type: DataTypes.DATE, defaultValue: DataTypes.NOW },
}, {
  tableName: 'transactions',
});

export default Transaction;
