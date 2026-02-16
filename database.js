const fs = require('fs');
const path = require('path');
const Database = require('better-sqlite3');

const DB_PATH = path.join(__dirname, 'data', 'canteen.db');

if (!fs.existsSync(path.dirname(DB_PATH))) {
    fs.mkdirSync(path.dirname(DB_PATH), { recursive: true });
}

const db = new Database(DB_PATH);
console.log('Connected to the SQLite database.');
db.pragma('foreign_keys = ON');
db.pragma('busy_timeout = 5000');
db.pragma('journal_mode = WAL');
db.pragma('synchronous = NORMAL');

function normalizeParams(params) {
    if (params === undefined || params === null) {
        return [];
    }
    return params;
}

function query(sql, params = []) {
    return Promise.resolve().then(() => {
        const stmt = db.prepare(sql);
        return stmt.all(normalizeParams(params));
    });
}

function run(sql, params = []) {
    return Promise.resolve().then(() => {
        const stmt = db.prepare(sql);
        const result = stmt.run(normalizeParams(params));
        return {
            changes: result.changes,
            lastID: Number(result.lastInsertRowid),
            lastInsertRowid: Number(result.lastInsertRowid)
        };
    });
}

function get(sql, params = []) {
    return Promise.resolve().then(() => {
        const stmt = db.prepare(sql);
        return stmt.get(normalizeParams(params));
    });
}

function close() {
    return Promise.resolve().then(() => {
        db.close();
    });
}

function assertIdentifier(identifier, label) {
    if (typeof identifier !== 'string' || !/^[a-zA-Z_][a-zA-Z0-9_]*$/.test(identifier)) {
        throw new Error(`Invalid ${label} identifier: ${identifier}`);
    }
}

async function withTransaction(work) {
    await run('BEGIN IMMEDIATE TRANSACTION');
    try {
        const result = await work();
        await run('COMMIT');
        return result;
    } catch (err) {
        try {
            await run('ROLLBACK');
        } catch (rollbackErr) {
            console.error('Failed to rollback transaction:', rollbackErr);
        }
        throw err;
    }
}

async function ensureColumnExists(tableName, columnName, definitionSql) {
    assertIdentifier(tableName, 'table');
    assertIdentifier(columnName, 'column');
    const columns = await query(`PRAGMA table_info(${tableName})`);
    const hasColumn = columns.some((column) => column.name === columnName);
    if (!hasColumn) {
        await run(`ALTER TABLE ${tableName} ADD COLUMN ${columnName} ${definitionSql}`);
    }
}

async function initDatabase() {
    const schemaStatements = [
        `CREATE TABLE IF NOT EXISTS users (
            email TEXT PRIMARY KEY,
            password_hash TEXT,
            profile_pic TEXT,
            role TEXT DEFAULT 'user',
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )`,
        `CREATE TABLE IF NOT EXISTS categories (
            key TEXT PRIMARY KEY,
            name_key TEXT,
            display_order INTEGER
        )`,
        `CREATE TABLE IF NOT EXISTS products (
            id TEXT PRIMARY KEY,
            name_key TEXT,
            description_key TEXT,
            price REAL,
            quantity INTEGER,
            image TEXT,
            category_key TEXT,
            FOREIGN KEY (category_key) REFERENCES categories(key) ON DELETE SET NULL
        )`,
        `CREATE TABLE IF NOT EXISTS orders (
            id TEXT PRIMARY KEY,
            user_email TEXT,
            total_amount REAL,
            status TEXT,
            payment_method TEXT,
            timestamp DATETIME,
            FOREIGN KEY (user_email) REFERENCES users(email) ON DELETE SET NULL
        )`,
        `CREATE TABLE IF NOT EXISTS order_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            order_id TEXT,
            product_id TEXT,
            quantity INTEGER,
            price_at_purchase REAL,
            is_discount INTEGER DEFAULT 0,
            name_key_at_purchase TEXT,
            FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
        )`,
        `CREATE TABLE IF NOT EXISTS translations (
            key TEXT PRIMARY KEY,
            en TEXT,
            ar TEXT,
            extra_languages_json TEXT DEFAULT '{}'
        )`,
        `CREATE TABLE IF NOT EXISTS settings (
            key TEXT PRIMARY KEY,
            value TEXT
        )`,
        `CREATE INDEX IF NOT EXISTS idx_orders_timestamp ON orders(timestamp)`,
        `CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status)`,
        `CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id)`,
        `CREATE INDEX IF NOT EXISTS idx_order_items_product_id ON order_items(product_id)`,
        `CREATE INDEX IF NOT EXISTS idx_products_category_key ON products(category_key)`,
        `CREATE INDEX IF NOT EXISTS idx_categories_display_order ON categories(display_order)`
    ];

    for (const statement of schemaStatements) {
        await run(statement);
    }

    await ensureColumnExists('translations', 'extra_languages_json', `TEXT DEFAULT '{}'`);

    await run(
        `INSERT OR IGNORE INTO settings (key, value) VALUES ('canteen_open', 'true')`
    );
}

module.exports = {
    close,
    db,
    get,
    initDatabase,
    query,
    run,
    withTransaction
};
