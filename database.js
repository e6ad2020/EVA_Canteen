const fs = require('fs');
const path = require('path');

const DB_PATH = process.env.DB_PATH || path.join(__dirname, 'data', 'canteen.db');

if (!fs.existsSync(path.dirname(DB_PATH))) {
    fs.mkdirSync(path.dirname(DB_PATH), { recursive: true });
}

let db;
let sqliteEngine = 'better-sqlite3';

if (process.env.EVA_SQLITE_ENGINE === 'node:sqlite') {
    const { DatabaseSync } = require('node:sqlite');
    db = new DatabaseSync(DB_PATH);
    sqliteEngine = 'node:sqlite';
} else {
    try {
        const Database = require('better-sqlite3');
        db = new Database(DB_PATH);
    } catch (betterSqliteErr) {
        try {
            const { DatabaseSync } = require('node:sqlite');
            db = new DatabaseSync(DB_PATH);
            sqliteEngine = 'node:sqlite';
            console.warn(
                `better-sqlite3 native bindings unavailable (${betterSqliteErr.message}); using built-in node:sqlite fallback.`
            );
        } catch (nodeSqliteErr) {
            throw new Error(
                `Failed to open SQLite database with better-sqlite3 (${betterSqliteErr.message}) ` +
                `and node:sqlite (${nodeSqliteErr.message}).`
            );
        }
    }
}

console.log(`Connected to the SQLite database (${sqliteEngine}).`);
if (sqliteEngine === 'better-sqlite3') {
    db.pragma('foreign_keys = ON');
    db.pragma('busy_timeout = 5000');
    db.pragma('journal_mode = WAL');
    db.pragma('synchronous = NORMAL');
} else {
    db.exec('PRAGMA foreign_keys = ON;');
    db.exec('PRAGMA busy_timeout = 5000;');
    db.exec('PRAGMA journal_mode = WAL;');
    db.exec('PRAGMA synchronous = NORMAL;');
}

function normalizeParams(params) {
    if (params === undefined || params === null) {
        return [];
    }
    return params;
}

function normalizeSpreadParams(params) {
    const normalized = normalizeParams(params);
    const list = Array.isArray(normalized) ? normalized : [normalized];
    return list.map((value) => (value === undefined ? null : value));
}

function query(sql, params = []) {
    return Promise.resolve().then(() => {
        const stmt = db.prepare(sql);
        if (sqliteEngine === 'node:sqlite') {
            return stmt.all(...normalizeSpreadParams(params)).map((row) => ({ ...row }));
        }
        return stmt.all(normalizeParams(params));
    });
}

function run(sql, params = []) {
    return Promise.resolve().then(() => {
        const stmt = db.prepare(sql);
        const result = sqliteEngine === 'node:sqlite'
            ? stmt.run(...normalizeSpreadParams(params))
            : stmt.run(normalizeParams(params));
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
        if (sqliteEngine === 'node:sqlite') {
            const row = stmt.get(...normalizeSpreadParams(params));
            return row ? { ...row } : undefined;
        }
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
        `CREATE INDEX IF NOT EXISTS idx_categories_display_order ON categories(display_order)`,
        `CREATE TABLE IF NOT EXISTS wallet_transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_email TEXT NOT NULL,
            delta REAL NOT NULL,
            balance_after REAL NOT NULL,
            reason TEXT,
            actor TEXT DEFAULT 'system',
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_email) REFERENCES users(email) ON DELETE CASCADE
        )`,
        `CREATE INDEX IF NOT EXISTS idx_wallet_tx_email ON wallet_transactions(user_email, timestamp DESC)`,
        `CREATE TABLE IF NOT EXISTS bundles (
            id TEXT PRIMARY KEY,
            name_key TEXT NOT NULL,
            description_key TEXT NOT NULL,
            item_ids_json TEXT NOT NULL DEFAULT '[]',
            discount_percent REAL NOT NULL DEFAULT 0,
            is_suggestion INTEGER NOT NULL DEFAULT 0,
            active INTEGER NOT NULL DEFAULT 1,
            display_order INTEGER NOT NULL DEFAULT 0
        )`
    ];

    for (const statement of schemaStatements) {
        await run(statement);
    }

    await ensureColumnExists('translations', 'extra_languages_json', `TEXT DEFAULT '{}'`);
    await ensureColumnExists('users', 'balance', `REAL NOT NULL DEFAULT 0`);

    await run(
        `INSERT OR IGNORE INTO settings (key, value) VALUES ('canteen_open', 'true')`
    );
    await run(
        `INSERT OR IGNORE INTO settings (key, value) VALUES ('payment_methods', '{"cash":true,"card":true,"wallet":true}')`
    );

    const existingBundlesCount = await get(`SELECT COUNT(*) AS count FROM bundles`);
    if (!existingBundlesCount || existingBundlesCount.count === 0) {
        const defaultBundles = [
            {
                id: 'bundle-lunch-deal',
                nameKey: 'bundle_lunch_deal_name',
                descKey: 'bundle_lunch_deal_desc',
                itemIds: ['pizza', 'salad', 'soda'],
                discount: 15,
                isSuggestion: 0,
                order: 0,
                enName: 'Lunch Power Deal',
                arName: 'عرض الغداء القوي',
                enDesc: 'Grab a Pizza, Salad, and Soda together and save!',
                arDesc: 'احصل على بيتزا وسلطة وصودا معًا ووفر!'
            },
            {
                id: 'bundle-sweet-treat',
                nameKey: 'bundle_sweet_treat_name',
                descKey: 'bundle_sweet_treat_desc',
                itemIds: ['cake', 'coffee', 'croissant'],
                discount: 20,
                isSuggestion: 0,
                order: 1,
                enName: 'Sweet Treat Bundle',
                arName: 'حزمة الحلوى اللذيذة',
                enDesc: 'Indulge with Cake, Coffee, and a Croissant at a special price.',
                arDesc: 'دلل نفسك بالكيك والقهوة والكرواسون بسعر خاص.'
            },
            {
                id: 'sugg-1',
                nameKey: 'suggestion_burger_combo_name',
                descKey: 'suggestion_burger_combo_desc',
                itemIds: ['burger', 'fries', 'soda'],
                discount: 0,
                isSuggestion: 1,
                order: 2,
                enName: 'Classic Combo',
                arName: 'كومبو كلاسيك',
                enDesc: 'The perfect trio: Burger, Fries, and Soda.',
                arDesc: 'الثلاثي المثالي: برجر، بطاطس، وصودا.'
            },
            {
                id: 'sugg-2',
                nameKey: 'suggestion_coffee_break_name',
                descKey: 'suggestion_coffee_break_desc',
                itemIds: ['coffee', 'muffin'],
                discount: 0,
                isSuggestion: 1,
                order: 3,
                enName: 'Coffee Break',
                arName: 'استراحة قهوة',
                enDesc: 'Relax with a warm Coffee and a soft Muffin.',
                arDesc: 'استرخِ مع قهوة دافئة ومافن طري.'
            },
            {
                id: 'sugg-3',
                nameKey: 'suggestion_lunch_light_name',
                descKey: 'suggestion_lunch_light_desc',
                itemIds: ['salad', 'juice'],
                discount: 0,
                isSuggestion: 1,
                order: 4,
                enName: 'Light Lunch',
                arName: 'غداء خفيف',
                enDesc: 'A healthy and refreshing Salad paired with Juice.',
                arDesc: 'سلطة صحية ومنعشة مع عصير.'
            }
        ];

        for (const b of defaultBundles) {
            await run(
                `INSERT OR IGNORE INTO bundles (id, name_key, description_key, item_ids_json, discount_percent, is_suggestion, active, display_order)
                 VALUES (?, ?, ?, ?, ?, ?, 1, ?)`,
                [b.id, b.nameKey, b.descKey, JSON.stringify(b.itemIds), b.discount, b.isSuggestion, b.order]
            );
            await run(
                `INSERT OR IGNORE INTO translations (key, en, ar, extra_languages_json) VALUES (?, ?, ?, '{}')`,
                [b.nameKey, b.enName, b.arName]
            );
            await run(
                `INSERT OR IGNORE INTO translations (key, en, ar, extra_languages_json) VALUES (?, ?, ?, '{}')`,
                [b.descKey, b.enDesc, b.arDesc]
            );
        }
    }
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
