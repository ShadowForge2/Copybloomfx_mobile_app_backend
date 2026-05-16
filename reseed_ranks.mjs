import { sequelize } from './src/config/database.js';
import { syncDatabase, Rank } from './src/models/index.js';

async function main() {
  await sequelize.sync();
  
  // Disable FK checks for SQLite
  await sequelize.query('PRAGMA foreign_keys = OFF');
  
  const count = await Rank.count();
  console.log('Current rank count:', count);
  
  // Set all profiles to null rank_id first
  await sequelize.query('UPDATE profiles SET rank_id = NULL');
  
  await Rank.destroy({ where: {}, truncate: true });
  console.log('Old ranks deleted');
  
  await syncDatabase();
  
  await sequelize.query('PRAGMA foreign_keys = ON');
  
  const newCount = await Rank.count();
  console.log('New rank count:', newCount);
  
  const ranks = await Rank.findAll({ order: [['min_balance', 'ASC']] });
  for (const r of ranks) {
    const maxStr = r.max_balance === null ? 'unlimited' : String(r.max_balance);
    console.log('  ' + r.id + ': ' + r.name + ' | $' + r.min_balance + '-' + maxStr + ' | ' + r.daily_profit_pct + '% | ' + r.copy_trades_limit + ' trades');
  }
  
  await sequelize.close();
}

main().catch(e => { console.error(e); process.exit(1); });
