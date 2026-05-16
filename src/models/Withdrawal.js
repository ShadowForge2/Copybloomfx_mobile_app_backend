import { DataTypes } from 'sequelize';
import { sequelize } from '../config/database.js';

const Withdrawal = sequelize.define('Withdrawal', {
  id: { type: DataTypes.UUID, primaryKey: true, defaultValue: DataTypes.UUIDV4 },
  user_id: { type: DataTypes.UUID, allowNull: false },
  amount: { type: DataTypes.DECIMAL, allowNull: false },
  network: { type: DataTypes.TEXT },
  wallet_address: { type: DataTypes.TEXT },
  status: { type: DataTypes.TEXT, defaultValue: 'pending' },
  created_at: { type: DataTypes.DATE, defaultValue: DataTypes.NOW },
  processed_at: { type: DataTypes.DATE },
}, {
  tableName: 'withdrawals',
});

export default Withdrawal;
