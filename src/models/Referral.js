import { DataTypes } from 'sequelize';
import { sequelize } from '../config/database.js';

const Referral = sequelize.define('Referral', {
  id: { type: DataTypes.UUID, primaryKey: true, defaultValue: DataTypes.UUIDV4 },
  referrer_id: { type: DataTypes.UUID, allowNull: false },
  referee_id: { type: DataTypes.UUID, allowNull: false },
  bonus_amount: { type: DataTypes.DECIMAL, defaultValue: 0 },
  deposit_id: { type: DataTypes.UUID },
  created_at: { type: DataTypes.DATE, defaultValue: DataTypes.NOW },
}, {
  tableName: 'referrals',
});

export default Referral;
