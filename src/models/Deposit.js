import { DataTypes } from 'sequelize';
import { sequelize } from '../config/database.js';

const Deposit = sequelize.define('Deposit', {
  id: { type: DataTypes.UUID, primaryKey: true, defaultValue: DataTypes.UUIDV4 },
  user_id: { type: DataTypes.UUID, allowNull: false },
  amount: { type: DataTypes.DECIMAL, allowNull: false },
  network: { type: DataTypes.TEXT },
  wallet_address: { type: DataTypes.TEXT },
  status: { type: DataTypes.TEXT, defaultValue: 'pending' },
  reference: { type: DataTypes.TEXT },
  notes: { type: DataTypes.TEXT },
  referrer_id: { type: DataTypes.UUID },
  expires_at: { type: DataTypes.DATE },
  approved_at: { type: DataTypes.DATE },
  created_at: { type: DataTypes.DATE, defaultValue: DataTypes.NOW },
}, {
  tableName: 'deposits',
});

export default Deposit;
