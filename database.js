const sqlite3 = require('sqlite3').verbose();
const path = require('path');
const fs = require('fs');

const DB_PATH = path.join(__dirname, 'data', 'canteen.db');

// Ensure data directory exists
if (!fs.existsSync(path.dirname(DB_PATH))) {
    fs.mkdirSync(path.dirname(DB_PATH), { recursive: true });
}

const db = new sqlite3.Database(DB_PATH, (err) => {
    if (err) {
        console.error('Error opening database:', err.message);
    } else {
        console.log('Connected to the SQLite database.');
        // Enable foreign keys
        db.run('PRAGMA foreign_keys = ON;');
    }
});

function initDatabase() {
    return new Promise((resolve, reject) => {
        db.serialize(() => {
            // Users Table
            db.run(`CREATE TABLE IF NOT EXISTS users (
                email TEXT PRIMARY KEY,
                password_hash TEXT,
                profile_pic TEXT,
                role TEXT DEFAULT 'user',
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )`);

            // Categories Table
            db.run(`CREATE TABLE IF NOT EXISTS categories (
                key TEXT PRIMARY KEY,
                name_key TEXT,
                display_order INTEGER
            )`);

            // Products Table
            db.run(`CREATE TABLE IF NOT EXISTS products (
                id TEXT PRIMARY KEY,
                name_key TEXT,
                description_key TEXT,
                price REAL,
                quantity INTEGER,
                image TEXT,
                category_key TEXT,
                FOREIGN KEY (category_key) REFERENCES categories(key) ON DELETE SET NULL
            )`);

            // Orders Table
            db.run(`CREATE TABLE IF NOT EXISTS orders (
                id TEXT PRIMARY KEY,
                user_email TEXT,
                total_amount REAL,
                status TEXT,
                payment_method TEXT,
                timestamp DATETIME,
                FOREIGN KEY (user_email) REFERENCES users(email) ON DELETE SET NULL
            )`);

            // Order Items Table
            db.run(`CREATE TABLE IF NOT EXISTS order_items (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                order_id TEXT,
                product_id TEXT,
                quantity INTEGER,
                price_at_purchase REAL,
                is_discount INTEGER DEFAULT 0,
                name_key_at_purchase TEXT,
                FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
                -- Note: We don't enforce FK on product_id strictly to allow keeping order history even if product is deleted physically,
                -- or we can enforce it but handle soft deletes. For simplicity here, we rely on the ID string.
            )`);

            // Translations Table (Key-Value for simpler lookups)
            db.run(`CREATE TABLE IF NOT EXISTS translations (
                key TEXT PRIMARY KEY,
                en TEXT,
                ar TEXT
            )`);

            // Settings Table (Key-Value)
            db.run(`CREATE TABLE IF NOT EXISTS settings (
                key TEXT PRIMARY KEY,
                value TEXT
            )`, (err) => {
                if (err) reject(err);
                else resolve();
            });
        });
    });
}

// Wrapper for db.all (Promise based)
function query(sql, params = []) {
    return new Promise((resolve, reject) => {
        db.all(sql, params, (err, rows) => {
            if (err) reject(err);
            else resolve(rows);
        });
    });
}

// Wrapper for db.run (Promise based)
function run(sql, params = []) {
    return new Promise((resolve, reject) => {
        db.run(sql, params, function (err) {
            if (err) reject(err);
            else resolve(this);
        });
    });
}

// Wrapper for db.get (Promise based)
function get(sql, params = []) {
    return new Promise((resolve, reject) => {
        db.get(sql, params, (err, row) => {
            if (err) reject(err);
            else resolve(row);
        });
    });
}

module.exports = {
    db,
    initDatabase,
    query,
    run,
    get
};
