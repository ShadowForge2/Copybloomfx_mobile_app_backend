import { DataTypes } from 'sequelize';
import { sequelize } from '../config/database.js';

const PromoRedemption = sequelize.define('PromoRedemption', {
  id: { type: DataTypes.UUID, primaryKey: true, defaultValue: DataTypes.UUIDV4 },
  user_id: { type: DataTypes.UUID, allowNull: false },
  promo_code_id: { type: DataTypes.UUID, allowNull: false },
  bonus_amount: { type: DataTypes.DECIMAL, defaultValue: 0 },
  created_at: { type: DataTypes.DATE, defaultValue: DataTypes.NOW },
}, {
  tableName: 'promo_redemptions',
});

export default PromoRedemption;
