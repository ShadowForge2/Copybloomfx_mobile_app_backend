const sqlite3 = require('sqlite3');
const path = require('path');
const dbPath = path.resolve(__dirname, '..', 'persistent_database', 'bloomfx_dev.db');
const db = new sqlite3.Database(dbPath, sqlite3.OPEN_READONLY);

db.all("SELECT name FROM sqlite_master WHERE type='table'", (err, rows) => {
  if (err) { console.error(err); return; }
  console.log('Tables:', rows.map(r => r.name).join(', '));
  let pending = rows.length;
  rows.forEach(t => {
    db.all('PRAGMA table_info(' + t.name + ')', (e2, cols) => {
      console.log('\n' + t.name + ':');
      cols.forEach(c => console.log('  ' + c.name + ' (' + c.type + ')'));
      if (--pending === 0) {
        rows.forEach(t => {
          db.all('SELECT COUNT(*) as cnt FROM ' + t.name, (e3, cntRows) => {
            if (cntRows) console.log(t.name + ' row count: ' + cntRows[0].cnt);
          });
        });
        setTimeout(() => db.close(), 500);
      }
    });
  });
});
setTimeout(() => db.close(), 2000);
