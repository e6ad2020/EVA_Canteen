const sqlite3 = require('sqlite3').verbose();
const path = require('path');

// Path to your database
const DB_PATH = path.join(__dirname, 'data', 'canteen.db');

// Connect to Database
const db = new sqlite3.Database(DB_PATH, sqlite3.OPEN_READWRITE, (err) => {
    if (err) {
        console.error('Error opening database:', err.message);
        process.exit(1);
    }
});

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
if (query.trim() === '.tables') {
    db.all("SELECT name FROM sqlite_master WHERE type='table'", [], (err, rows) => {
        if (err) console.error(err.message);
        else {
            console.log("Tables in database:");
            console.table(rows);
        }
        db.close();
    });
    return;
}

// Determine if it's a SELECT query (returns data) or others (RUN)
const isSelect = query.trim().toUpperCase().startsWith('SELECT');

if (isSelect) {
    db.all(query, [], (err, rows) => {
        if (err) {
            console.error("SQL Error:", err.message);
        } else {
            if (rows.length === 0) {
                console.log("No results found.");
            } else {
                console.table(rows); // Pretty print results as a table
            }
        }
        db.close();
    });
} else {
    db.run(query, function (err) {
        if (err) {
            console.error("SQL Error:", err.message);
        } else {
            console.log(`Query executed successfully.`);
            console.log(`Rows affected: ${this.changes}`);
            console.log(`Last Insert ID: ${this.lastID}`);
        }
        db.close();
    });
}
