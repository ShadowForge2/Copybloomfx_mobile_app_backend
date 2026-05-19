import fs from 'fs';
import path from 'path';
import { sequelize } from './config/database.js';

async function run() {
  const migrationsDir = path.resolve(process.cwd(), 'migrations');
  if (!fs.existsSync(migrationsDir)) {
    console.log('No migrations directory found:', migrationsDir);
    process.exit(0);
  }

  // Detect sqlite usage by checking dialect
  const dialect = sequelize.getDialect();
  if (dialect !== 'sqlite') {
    console.log('Non-sqlite database detected. This migrate runner only applies migrations for sqlite.');
    console.log('For Supabase/Postgres, run the SQL files with psql or the Supabase SQL editor. Files:');
    const files = fs.readdirSync(migrationsDir).filter((f) => f.endsWith('.sql')).sort();
    for (const f of files) console.log(' -', path.join('migrations', f));
    process.exit(0);
  }

  const files = fs.readdirSync(migrationsDir).filter((f) => f.endsWith('.sql')).sort();
  for (const file of files) {
    const fp = path.join(migrationsDir, file);
    const sql = fs.readFileSync(fp, 'utf8');
    console.log(`Applying ${file}...`);
    try {
      // sqlite accepts multiple statements in one query for sqlite3 driver
      await sequelize.query(sql);
      console.log(`Applied ${file}`);
    } catch (e) {
      console.error(`Failed to apply ${file}:`, e.message || e);
      process.exit(1);
    }
  }
  console.log('All migrations applied.');
  process.exit(0);
}

run();
