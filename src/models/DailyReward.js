import { DataTypes } from 'sequelize';
import { sequelize } from '../config/database.js';

const DailyReward = sequelize.define('DailyReward', {
  id: { type: DataTypes.UUID, primaryKey: true, defaultValue: DataTypes.UUIDV4 },
  user_id: { type: DataTypes.UUID, allowNull: false },
  amount: { type: DataTypes.DECIMAL, defaultValue: 0 },
  claimed_at: { type: DataTypes.DATE, defaultValue: DataTypes.NOW },
}, {
  tableName: 'daily_rewards',
});

export default DailyReward;
