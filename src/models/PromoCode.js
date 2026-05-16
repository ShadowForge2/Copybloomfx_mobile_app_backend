import { DataTypes } from 'sequelize';
import { sequelize } from '../config/database.js';

const PromoCode = sequelize.define('PromoCode', {
  id: { type: DataTypes.UUID, primaryKey: true, defaultValue: DataTypes.UUIDV4 },
  code: { type: DataTypes.TEXT, unique: true, allowNull: false },
  bonus_min: { type: DataTypes.DECIMAL, defaultValue: 0 },
  bonus_max: { type: DataTypes.DECIMAL, defaultValue: 0 },
  expiration: { type: DataTypes.DATE },
  usage_limit: { type: DataTypes.INTEGER },
  usage_count: { type: DataTypes.INTEGER, defaultValue: 0 },
  status: { type: DataTypes.TEXT, defaultValue: 'active' },
  created_at: { type: DataTypes.DATE, defaultValue: DataTypes.NOW },
}, {
  tableName: 'promo_codes',
});

export default PromoCode;
