import { sequelize } from '../config/database.js';
import User from './User.js';
import Profile from './Profile.js';
import Rank from './Rank.js';
import Deposit from './Deposit.js';
import Withdrawal from './Withdrawal.js';
import CopyTrade from './CopyTrade.js';
import DailyReward from './DailyReward.js';
import Referral from './Referral.js';
import PromoCode from './PromoCode.js';
import PromoRedemption from './PromoRedemption.js';
import Notification from './Notification.js';
import Transaction from './Transaction.js';
import AuditLog from './AuditLog.js';
import Session from './Session.js';
import SupportConversation from './SupportConversation.js';
import SupportMessage from './SupportMessage.js';

User.hasOne(Profile, { foreignKey: 'user_id' });
Profile.belongsTo(User, { foreignKey: 'user_id' });

Profile.belongsTo(Rank, { foreignKey: 'rank_id' });
Rank.hasMany(Profile, { foreignKey: 'rank_id' });

User.hasMany(Deposit, { foreignKey: 'user_id' });
Deposit.belongsTo(User, { foreignKey: 'user_id' });

User.hasMany(Withdrawal, { foreignKey: 'user_id' });
Withdrawal.belongsTo(User, { foreignKey: 'user_id' });

User.hasMany(CopyTrade, { foreignKey: 'user_id' });
CopyTrade.belongsTo(User, { foreignKey: 'user_id' });

User.hasMany(DailyReward, { foreignKey: 'user_id' });
DailyReward.belongsTo(User, { foreignKey: 'user_id' });

User.hasMany(Referral, { foreignKey: 'referrer_id' });
Referral.belongsTo(User, { foreignKey: 'referrer_id' });

PromoCode.hasMany(PromoRedemption, { foreignKey: 'promo_code_id' });
PromoRedemption.belongsTo(PromoCode, { foreignKey: 'promo_code_id' });

User.hasMany(PromoRedemption, { foreignKey: 'user_id' });
PromoRedemption.belongsTo(User, { foreignKey: 'user_id' });

User.hasMany(Notification, { foreignKey: 'user_id' });
Notification.belongsTo(User, { foreignKey: 'user_id' });

User.hasMany(Transaction, { foreignKey: 'user_id' });
Transaction.belongsTo(User, { foreignKey: 'user_id' });

AuditLog.belongsTo(User, { foreignKey: 'user_id', as: 'actor', constraints: false });
AuditLog.belongsTo(User, { foreignKey: 'target_user_id', as: 'target', constraints: false });

Session.belongsTo(User, { foreignKey: 'user_id', constraints: false });

// Support Conversations & Messages
User.hasMany(SupportConversation, { foreignKey: 'user_id' });
SupportConversation.belongsTo(User, { foreignKey: 'user_id' });

SupportConversation.hasMany(SupportMessage, { foreignKey: 'conversation_id' });
SupportMessage.belongsTo(SupportConversation, { foreignKey: 'conversation_id' });

User.hasMany(SupportMessage, { foreignKey: 'sender_id' });
SupportMessage.belongsTo(User, { foreignKey: 'sender_id' });

const RANK_SEED = [
  { name: 'Green Horn',    min_balance: 7,     max_balance: 49,    daily_profit_pct: 1.67, copy_trades_limit: 1, color: '#4CAF50' },
  { name: 'Student Form',  min_balance: 50,    max_balance: 100,   daily_profit_pct: 2.0,  copy_trades_limit: 2, color: '#2196F3' },
  { name: 'Market Maven',  min_balance: 100,   max_balance: 500,   daily_profit_pct: 2.0,  copy_trades_limit: 3, color: '#9C27B0' },
  { name: 'Gunslinger',    min_balance: 500,   max_balance: 1500,  daily_profit_pct: 2.2,  copy_trades_limit: 4, color: '#FF9800' },
  { name: 'Whale',         min_balance: 1500,  max_balance: 5000,  daily_profit_pct: 2.5,  copy_trades_limit: 5, color: '#FFC107' },
  { name: 'Market Wizard', min_balance: 5000,  max_balance: null,  daily_profit_pct: 2.7,  copy_trades_limit: 6, color: '#FFD700' },
];

async function syncDatabase() {
  await sequelize.sync({ alter: false });
  const count = await Rank.count();
  if (count === 0) {
    await Rank.bulkCreate(RANK_SEED);
    console.log('[DB] Seeded ranks table');
  }
  const adminCount = await User.count({ where: { role: 'admin' } });
  if (adminCount === 0) {
    await User.create({
      id: 'admin',
      username: 'admin',
      email: process.env.ADMIN_EMAIL || 'bashirabdulganiyy9@gmail.com',
      role: 'admin',
      status: 'active',
    });
    console.log('[DB] Seeded admin user');
  }
}

export {
  sequelize, syncDatabase,
  User, Profile, Rank, Deposit, Withdrawal,
  CopyTrade, DailyReward, Referral,
  PromoCode, PromoRedemption, Notification, Transaction,
  AuditLog, Session, SupportConversation, SupportMessage,
};
