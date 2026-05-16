import { DataTypes } from 'sequelize';
import { sequelize } from '../config/database.js';

const Rank = sequelize.define('Rank', {
  id: { type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true },
  name: { type: DataTypes.TEXT, allowNull: false },
  min_balance: { type: DataTypes.DECIMAL, defaultValue: 0 },
  max_balance: { type: DataTypes.DECIMAL, allowNull: true, defaultValue: null },
  daily_profit_pct: { type: DataTypes.DECIMAL, defaultValue: 0 },
  copy_trades_limit: { type: DataTypes.INTEGER, defaultValue: 1 },
  color: { type: DataTypes.TEXT, defaultValue: '#6366f1' },
  created_at: { type: DataTypes.DATE, defaultValue: DataTypes.NOW },
}, {
  tableName: 'ranks',
});

export default Rank;
