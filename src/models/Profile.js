import { DataTypes } from 'sequelize';
import { sequelize } from '../config/database.js';

const Profile = sequelize.define('Profile', {
  id: { type: DataTypes.UUID, primaryKey: true, defaultValue: DataTypes.UUIDV4 },
  user_id: { type: DataTypes.UUID, unique: true, allowNull: false },
  first_name: { type: DataTypes.TEXT },
  last_name: { type: DataTypes.TEXT },
  phone: { type: DataTypes.TEXT },
  country: { type: DataTypes.TEXT },
  referral_code: { type: DataTypes.TEXT, unique: true },
  referred_by: { type: DataTypes.TEXT },
  total_referrals: { type: DataTypes.INTEGER, defaultValue: 0 },
  valid_referrals: { type: DataTypes.INTEGER, defaultValue: 0 },
  referral_earnings: { type: DataTypes.DECIMAL, defaultValue: 0 },
  avatar_url: { type: DataTypes.TEXT },
  profile_picture: { type: DataTypes.TEXT },
  locked_balance: { type: DataTypes.DECIMAL, defaultValue: 0 },
  withdrawable_balance: { type: DataTypes.DECIMAL, defaultValue: 0 },
  rank_id: { type: DataTypes.INTEGER },
  last_daily_reward_at: { type: DataTypes.DATE },
  last_withdrawal_at: { type: DataTypes.DATE },
  created_at: { type: DataTypes.DATE, defaultValue: DataTypes.NOW },
}, {
  tableName: 'profiles',
});

export default Profile;
