import { Sequelize } from 'sequelize';
import path from 'path';
import { fileURLToPath } from 'url';
import fs from 'fs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const dbDir = path.resolve(__dirname, '..', '..', '..', 'persistent_database');
if (!fs.existsSync(dbDir)) {
  fs.mkdirSync(dbDir, { recursive: true });
}

const dbPath = path.join(dbDir, 'bloomfx_dev.db');

// Delete stale database on startup to ensure schema matches current models
if (fs.existsSync(dbPath)) {
  try {
    fs.unlinkSync(dbPath);
    console.log('[DB] Deleted stale database — fresh schema will be created');
  } catch (e) {
    console.error('[DB] Could not delete stale database:', e.message);
  }
}

export const sequelize = new Sequelize({
  dialect: 'sqlite',
  storage: dbPath,
  logging: process.env.SEQUELIZE_LOGGING === 'true' ? console.log : false,
  define: {
    freezeTableName: false,
    timestamps: false,
  },
});

export default sequelize;
