const Database = require('better-sqlite3');
const path = require('path');

// Path to your database
const DB_PATH = path.join(__dirname, 'data', 'canteen.db');

let db;
try {
    db = new Database(DB_PATH);
} catch (err) {
    console.error('Error opening database:', err.message);
    process.exit(1);
}

// Get the SQL query from command line arguments
const query = process.argv[2];

if (!query) {
    console.log(`
Usage: node db_cli.js "<SQL_QUERY>"

Examples:
  node db_cli.js "SELECT * FROM users"
  node db_cli.js "SELECT * FROM orders LIMIT 5"
  node db_cli.js "UPDATE products SET price = 50 WHERE id = 'burger'"
  node db_cli.js ".tables"  (Lists all tables)
    `);
    process.exit(0);
}

// Handle special commands
try {
    if (query.trim() === '.tables') {
        const rows = db.prepare("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name").all();
        console.log("Tables in database:");
        console.table(rows);
        process.exit(0);
    }

    // Determine if it's a query that returns rows
    const returnsRows = /^\s*(SELECT|PRAGMA|WITH|EXPLAIN)\b/i.test(query);

    if (returnsRows) {
        const rows = db.prepare(query).all();
        if (rows.length === 0) {
            console.log("No results found.");
        } else {
            console.table(rows);
        }
    } else {
        const result = db.prepare(query).run();
        console.log(`Query executed successfully.`);
        console.log(`Rows affected: ${result.changes}`);
        console.log(`Last Insert ID: ${Number(result.lastInsertRowid)}`);
    }
} catch (err) {
    console.error("SQL Error:", err.message);
    process.exitCode = 1;
} finally {
    db.close();
}
