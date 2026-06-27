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
  await sequelize.sync();

  // Ensure all expected columns exist on profiles table (safe migration for SQLite)
  // SQLite doesn't support adding columns with constraints easily, so we check and add if missing
  const columnsToAdd = [
    { name: 'first_name', type: 'TEXT' },
    { name: 'last_name', type: 'TEXT' },
    { name: 'referred_by', type: 'TEXT' },
  ];

  for (const { name, type } of columnsToAdd) {
    try {
      await sequelize.query(`ALTER TABLE profiles ADD COLUMN "${name}" ${type}`);
      console.log(`[DB] Added column '${name}' to profiles table`);
    } catch (e) {
      // SQLITE_ERROR: duplicate column name means column already exists - this is expected
      if (e.message && e.message.includes('duplicate column name')) {
        console.log(`[DB] Column '${name}' already exists in profiles table (verified)`);
      } else {
        console.error(`[DB] Error adding column '${name}':`, e.message);
      }
    }
  }

  // Ensure close_at column exists on copy_trades table (safe migration for SQLite)
  try {
    await sequelize.query('ALTER TABLE copy_trades ADD COLUMN "close_at" DATETIME');
    console.log("[DB] Added column 'close_at' to copy_trades table");
  } catch (e) {
    if (e.message && (e.message.includes('duplicate column name') || e.message.includes('already exists'))) {
      console.log("[DB] Column 'close_at' already exists in copy_trades table (verified)");
    } else {
      console.error("[DB] Error adding column 'close_at' to copy_trades:", e.message);
    }
  }

  // Force Sequelize to re-sync deposits schema to clear schema cache
  try {
    await Deposit.sync({ alter: true });
    console.log('[DB] Deposits schema synced (alter applied if columns were missing)');
  } catch (e) {
    console.error('[DB] Error syncing deposits schema:', e.message);
  }

  // Verify the schema is correct after migration using raw SQLite
  try {
    const result = await sequelize.query('PRAGMA table_info(profiles)', { type: sequelize.QueryTypes.SELECT });
    const columnNames = result.map(row => row.name || row.cname || Object.values(row)[1]);
    const requiredColumns = ['first_name', 'last_name', 'referred_by'];
    const missing = requiredColumns.filter(col => !columnNames.includes(col));
    if (missing.length > 0) {
      console.error(`[DB] WARNING: Missing columns in profiles table: ${missing.join(', ')}`);
    } else {
      console.log('[DB] Profiles table schema verified - all required columns present');
    }
  } catch (e) {
    console.error('[DB] Error verifying profiles schema:', e.message);
  }

  // Ensure color column exists on ranks table (safe migration)
  try {
    await sequelize.query(`ALTER TABLE ranks ADD COLUMN "color" TEXT DEFAULT '#6366f1'`);
    console.log('[DB] Added column \'color\' to ranks table');
  } catch (e) {
    if (e.message && e.message.includes('duplicate column name')) {
      console.log('[DB] Column \'color\' already exists in ranks table (verified)');
    } else {
      console.error('[DB] Error adding column \'color\' to ranks:', e.message);
    }
  }

  // Update existing ranks with correct colors if they have the default/null color
  for (const seed of RANK_SEED) {
    await sequelize.query(
      `UPDATE ranks SET color = ? WHERE name = ? AND (color IS NULL OR color = '#6366f1' OR color = '')`,
      { replacements: [seed.color, seed.name] },
    );
  }

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
