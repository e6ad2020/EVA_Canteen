/**
 * EVA Canteen - WebSocket + HTTP Server
 * Copyright (C) 2025 EVA International School
 */

const bcrypt = require('bcrypt');
const express = require('express');
const http = require('http');
const os = require('os');
const path = require('path');
const WebSocket = require('ws');

const db = require('./database');

const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({
    server,
    maxPayload: 64 * 1024
});

app.use(express.static(path.join(__dirname, '')));

const PORT = Number(process.env.PORT) || 8080;

const SERVER_ADMIN_EMAIL = process.env.ADMIN_EMAIL || 'admin@canteen.app';
const SERVER_ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'admin123';
const SERVER_DISCOVERY_PASSPHRASE = process.env.DISCOVERY_PASSPHRASE || '12345';

const MAX_ADMIN_FAILED_ATTEMPTS = 5;
const ADMIN_LOCKOUT_DURATION_MS = 5 * 60 * 1000;
const LANGUAGE_CODE_PATTERN = /^[a-z]{2,3}(?:-[a-z0-9]{2,8})*$/i;
const MAX_WS_MESSAGE_BYTES = 64 * 1024;
const WS_HEARTBEAT_INTERVAL_MS = 30 * 1000;

const VALID_ORDER_STATUSES = new Set(['pending', 'preparing', 'delivered']);
const VALID_PROFILE_PICS = new Set(['pic1', 'pic2', 'pic3']);

const clients = new Map();
const failedAdminLoginAttempts = new Map();

class ClientError extends Error {
    constructor(message, payload = {}) {
        super(message);
        this.name = 'ClientError';
        this.payload = payload;
    }
}

function getLocalIpAddress() {
    const interfaces = os.networkInterfaces();
    for (const name of Object.keys(interfaces)) {
        for (const iface of interfaces[name]) {
            if (iface.family === 'IPv4' && !iface.internal) {
                return iface.address;
            }
        }
    }
    return 'localhost';
}

function parseClientMessage(message) {
    try {
        const raw = Buffer.isBuffer(message) ? message.toString('utf8') : message;
        if (typeof raw !== 'string' || Buffer.byteLength(raw, 'utf8') > MAX_WS_MESSAGE_BYTES) {
            return null;
        }

        const parsed = JSON.parse(raw);
        const type = sanitizeString(parsed?.type, { maxLength: 64 });
        if (!parsed || typeof parsed !== 'object' || !type) {
            return null;
        }
        return {
            ...parsed,
            type
        };
    } catch {
        return null;
    }
}

function sendMessage(ws, type, payload) {
    if (!ws || ws.readyState !== WebSocket.OPEN) {
        return;
    }

    const message = payload === undefined ? { type } : { type, payload };

    try {
        ws.send(JSON.stringify(message));
    } catch (err) {
        console.error(`Failed to send "${type}" message:`, err);
    }
}

function broadcast(type, payload, excludeWs = null) {
    for (const client of wss.clients) {
        if (client.readyState === WebSocket.OPEN && client !== excludeWs) {
            sendMessage(client, type, payload);
        }
    }
}

function broadcastToManagement(type, payload) {
    for (const [ws, info] of clients.entries()) {
        if (info.isManagement && ws.readyState === WebSocket.OPEN) {
            sendMessage(ws, type, payload);
        }
    }
}

function sanitizeString(value, { trim = true, maxLength = 200 } = {}) {
    if (typeof value !== 'string') {
        return null;
    }

    const sanitized = trim ? value.trim() : value;
    if (!sanitized) {
        return null;
    }

    return sanitized.length > maxLength ? sanitized.slice(0, maxLength) : sanitized;
}

function sanitizeOptionalString(value, { trim = true, maxLength = 2000 } = {}) {
    if (value === null || value === undefined) {
        return null;
    }
    return sanitizeString(value, { trim, maxLength });
}

function sanitizeNumber(value, { min = Number.NEGATIVE_INFINITY, max = Number.POSITIVE_INFINITY } = {}) {
    const parsed = Number(value);
    if (!Number.isFinite(parsed)) {
        return null;
    }
    if (parsed < min || parsed > max) {
        return null;
    }
    return parsed;
}

function sanitizeInteger(value, { min = Number.MIN_SAFE_INTEGER, max = Number.MAX_SAFE_INTEGER } = {}) {
    const parsed = Number(value);
    if (!Number.isInteger(parsed)) {
        return null;
    }
    if (parsed < min || parsed > max) {
        return null;
    }
    return parsed;
}

function sanitizeEmail(value) {
    const email = sanitizeString(value, { maxLength: 320 });
    if (!email) {
        return null;
    }

    const normalized = email.toLowerCase();
    const simpleEmailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return simpleEmailPattern.test(normalized) ? normalized : null;
}

function isValidLanguageCode(code) {
    if (typeof code !== 'string') {
        return false;
    }
    return LANGUAGE_CODE_PATTERN.test(code.trim());
}

function normalizeTranslationValue(value) {
    if (typeof value === 'string') {
        const text = sanitizeString(value, { maxLength: 2000 });
        return text ? { en: text, ar: text } : null;
    }

    if (!value || typeof value !== 'object' || Array.isArray(value)) {
        return null;
    }

    const normalized = {};
    for (const [rawCode, rawText] of Object.entries(value)) {
        const code = typeof rawCode === 'string' ? rawCode.trim().toLowerCase() : '';
        if (!isValidLanguageCode(code)) {
            continue;
        }

        const text = sanitizeOptionalString(rawText, { maxLength: 2000 });
        if (text) {
            normalized[code] = text;
        }
    }

    if (Object.keys(normalized).length === 0) {
        return null;
    }

    return normalized;
}

function parseExtraLanguages(rawJson) {
    if (typeof rawJson !== 'string' || !rawJson.trim()) {
        return {};
    }

    try {
        const parsed = JSON.parse(rawJson);
        if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
            return {};
        }

        const extras = {};
        for (const [rawCode, rawText] of Object.entries(parsed)) {
            const code = typeof rawCode === 'string' ? rawCode.trim().toLowerCase() : '';
            if (!isValidLanguageCode(code) || code === 'en' || code === 'ar') {
                continue;
            }

            const text = sanitizeOptionalString(rawText, { maxLength: 2000 });
            if (text) {
                extras[code] = text;
            }
        }

        return extras;
    } catch {
        return {};
    }
}

function mapTranslationRow(row) {
    if (!row || typeof row !== 'object') {
        return {};
    }

    const mapped = {};
    const en = sanitizeOptionalString(row.en, { maxLength: 2000 });
    const ar = sanitizeOptionalString(row.ar, { maxLength: 2000 });

    if (en) {
        mapped.en = en;
    }
    if (ar) {
        mapped.ar = ar;
    }

    const extras = parseExtraLanguages(row.extra_languages_json);
    for (const [code, text] of Object.entries(extras)) {
        mapped[code] = text;
    }

    return mapped;
}

function splitTranslationForStorage(translationMap) {
    const normalizedMap = {};

    for (const [rawCode, rawText] of Object.entries(translationMap || {})) {
        const code = typeof rawCode === 'string' ? rawCode.trim().toLowerCase() : '';
        if (!isValidLanguageCode(code)) {
            continue;
        }

        const text = sanitizeOptionalString(rawText, { maxLength: 2000 });
        if (!text) {
            continue;
        }

        normalizedMap[code] = text;
    }

    const en = normalizedMap.en || '';
    const ar = normalizedMap.ar || '';
    delete normalizedMap.en;
    delete normalizedMap.ar;

    return {
        en,
        ar,
        extraLanguagesJson: JSON.stringify(normalizedMap)
    };
}

function normalizeOrderPayload(payload) {
    if (!payload || typeof payload !== 'object') {
        throw new ClientError('Invalid order payload.', { reason: 'InvalidOrder' });
    }

    const totalAmount = sanitizeNumber(payload.totalAmount, { min: 0 });
    if (totalAmount === null) {
        throw new ClientError('Invalid order total.', { reason: 'InvalidOrderTotal' });
    }

    const paymentMethod = sanitizeString(payload.paymentMethod, { maxLength: 24 }) || 'cash';
    const userEmail = sanitizeEmail(payload.user?.email);

    if (!Array.isArray(payload.items) || payload.items.length === 0) {
        throw new ClientError('Order has no items.', { reason: 'EmptyOrder' });
    }

    const items = payload.items.map((item, index) => {
        const id = sanitizeString(item?.id, { maxLength: 128 });
        const quantity = sanitizeInteger(item?.quantity, { min: 1, max: 9999 });
        const price = sanitizeNumber(item?.price, { min: 0, max: 1_000_000 });
        const nameKey = sanitizeOptionalString(item?.name_key, { maxLength: 256 }) || '';

        if (!id || quantity === null || price === null) {
            throw new ClientError('Invalid order item.', {
                reason: 'InvalidOrderItem',
                itemIndex: index
            });
        }

        return {
            id,
            quantity,
            price,
            isDiscount: Boolean(item?.isDiscount),
            name_key: nameKey
        };
    });

    return {
        items,
        paymentMethod,
        totalAmount,
        userEmail
    };
}

function normalizeProductPayload(rawProduct, fallbackCategoryKey = null) {
    const id = sanitizeString(rawProduct?.id, { maxLength: 128 });
    const nameKey = sanitizeString(rawProduct?.name_key, { maxLength: 256 });
    const descriptionKey = sanitizeString(rawProduct?.description_key, { maxLength: 256 });
    const price = sanitizeNumber(rawProduct?.price, { min: 0, max: 1_000_000 });
    const quantity = sanitizeInteger(rawProduct?.quantity, { min: 0, max: 999999 });
    const image = sanitizeOptionalString(rawProduct?.image, { maxLength: 2048 }) || '';

    const rawCategory =
        rawProduct?.category_key ??
        rawProduct?.category ??
        fallbackCategoryKey;
    const category = sanitizeOptionalString(rawCategory, { maxLength: 128 });

    if (!id || !nameKey || !descriptionKey || price === null || quantity === null) {
        return null;
    }

    return {
        id,
        name_key: nameKey,
        description_key: descriptionKey,
        price,
        quantity,
        image,
        category_key: category
    };
}

function normalizeCategoryPayload(rawCategory, displayOrder) {
    const key = sanitizeString(rawCategory?.key, { maxLength: 128 });
    const nameKey = sanitizeString(rawCategory?.name_key, { maxLength: 256 });
    const order = sanitizeInteger(displayOrder, { min: 0, max: 1000000 });

    if (!key || !nameKey || order === null) {
        return null;
    }

    return {
        key,
        name_key: nameKey,
        display_order: order
    };
}

function getAdminRateLimitState(ip) {
    const key = ip || 'unknown';
    const state = failedAdminLoginAttempts.get(key);
    if (!state) {
        return { count: 0, lockedUntil: 0 };
    }

    if (state.lockedUntil && Date.now() > state.lockedUntil) {
        failedAdminLoginAttempts.delete(key);
        return { count: 0, lockedUntil: 0 };
    }

    return state;
}

function recordAdminLoginFailure(ip) {
    const key = ip || 'unknown';
    const state = getAdminRateLimitState(key);
    const nextCount = state.count + 1;

    if (nextCount >= MAX_ADMIN_FAILED_ATTEMPTS) {
        const lockedUntil = Date.now() + ADMIN_LOCKOUT_DURATION_MS;
        failedAdminLoginAttempts.set(key, { count: 0, lockedUntil });
        return {
            locked: true,
            retryAfterSeconds: Math.ceil((lockedUntil - Date.now()) / 1000)
        };
    }

    failedAdminLoginAttempts.set(key, { count: nextCount, lockedUntil: 0 });

    return {
        locked: false,
        attemptsRemaining: MAX_ADMIN_FAILED_ATTEMPTS - nextCount
    };
}

function clearAdminLoginFailures(ip) {
    failedAdminLoginAttempts.delete(ip || 'unknown');
}

function getClientIp(req) {
    try {
        let ip =
            req.headers['x-forwarded-for']?.split(',').shift()?.trim() ||
            req.socket.remoteAddress ||
            'unknown';

        if (ip === '::1') {
            ip = '127.0.0.1';
        }

        return ip;
    } catch {
        return 'unknown';
    }
}

function mapProductRow(row) {
    return {
        id: row.id,
        name_key: row.name_key,
        description_key: row.description_key,
        price: row.price,
        quantity: row.quantity,
        image: row.image,
        category: row.category_key
    };
}

async function getAllProducts() {
    const rows = await db.query('SELECT * FROM products');
    return rows.map(mapProductRow);
}

async function getAllCategories(products = null) {
    const productList = products || (await getAllProducts());
    const rows = await db.query('SELECT * FROM categories ORDER BY display_order, key');
    const productIdsByCategory = new Map();

    for (const product of productList) {
        const categoryKey = sanitizeOptionalString(product?.category, { maxLength: 128 });
        if (!categoryKey) {
            continue;
        }

        if (!productIdsByCategory.has(categoryKey)) {
            productIdsByCategory.set(categoryKey, []);
        }

        productIdsByCategory.get(categoryKey).push(product.id);
    }

    return rows.map((cat) => ({
        key: cat.key,
        name_key: cat.name_key,
        productIds: productIdsByCategory.get(cat.key) || []
    }));
}

async function getProductsAndCategories() {
    const products = await getAllProducts();
    const categories = await getAllCategories(products);
    return { products, categories };
}

async function getTranslations() {
    const rows = await db.query('SELECT * FROM translations');
    const translations = {};

    for (const row of rows) {
        translations[row.key] = mapTranslationRow(row);
    }

    return translations;
}

async function getCanteenStatus() {
    const row = await db.get("SELECT value FROM settings WHERE key = 'canteen_open'");
    return {
        isOpen: row ? row.value === 'true' : true
    };
}

async function getAllOrders() {
    const orders = await db.query(
        `SELECT o.*, u.email AS resolved_user_email, u.profile_pic AS resolved_profile_pic
         FROM orders o
         LEFT JOIN users u ON o.user_email = u.email
         ORDER BY o.timestamp DESC`
    );

    const items = await db.query('SELECT * FROM order_items ORDER BY id ASC');
    const itemsByOrder = {};

    for (const item of items) {
        if (!itemsByOrder[item.order_id]) {
            itemsByOrder[item.order_id] = [];
        }

        itemsByOrder[item.order_id].push({
            id: item.product_id,
            quantity: item.quantity,
            price: item.price_at_purchase,
            isDiscount: Boolean(item.is_discount),
            name_key: item.name_key_at_purchase
        });
    }

    return orders.map((order) => ({
        id: order.id,
        totalAmount: order.total_amount,
        status: order.status,
        paymentMethod: order.payment_method,
        timestamp: order.timestamp,
        items: itemsByOrder[order.id] || [],
        user: order.resolved_user_email
            ? {
                email: order.resolved_user_email,
                profilePic: order.resolved_profile_pic || 'pic2'
            }
            : {
                email: 'Guest',
                profilePic: 'pic2'
            }
    }));
}

async function getOrderById(orderId) {
    const order = await db.get(
        `SELECT o.*, u.email AS resolved_user_email, u.profile_pic AS resolved_profile_pic
         FROM orders o
         LEFT JOIN users u ON o.user_email = u.email
         WHERE o.id = ?`,
        [orderId]
    );

    if (!order) {
        return null;
    }

    const items = await db.query('SELECT * FROM order_items WHERE order_id = ? ORDER BY id ASC', [orderId]);

    return {
        id: order.id,
        totalAmount: order.total_amount,
        status: order.status,
        paymentMethod: order.payment_method,
        timestamp: order.timestamp,
        items: items.map((item) => ({
            id: item.product_id,
            quantity: item.quantity,
            price: item.price_at_purchase,
            isDiscount: Boolean(item.is_discount),
            name_key: item.name_key_at_purchase
        })),
        user: order.resolved_user_email
            ? {
                email: order.resolved_user_email,
                profilePic: order.resolved_profile_pic || 'pic2'
            }
            : {
                email: 'Guest',
                profilePic: 'pic2'
            }
    };
}

async function updateTranslations(newTranslations) {
    if (!newTranslations || typeof newTranslations !== 'object') {
        return;
    }

    const sanitizedEntries = [];

    for (const [key, rawValue] of Object.entries(newTranslations)) {
        const sanitizedKey = sanitizeString(key, { maxLength: 256 });
        if (!sanitizedKey) {
            continue;
        }

        const value = normalizeTranslationValue(rawValue);
        if (!value) {
            continue;
        }

        sanitizedEntries.push({
            key: sanitizedKey,
            value
        });
    }

    if (sanitizedEntries.length === 0) {
        return;
    }

    const placeholders = sanitizedEntries.map(() => '?').join(', ');
    const existingRows = await db.query(
        `SELECT key, en, ar, extra_languages_json FROM translations WHERE key IN (${placeholders})`,
        sanitizedEntries.map((entry) => entry.key)
    );
    const existingRowsByKey = new Map(existingRows.map((row) => [row.key, row]));

    for (const entry of sanitizedEntries) {
        const existingRow = existingRowsByKey.get(entry.key);
        const mergedValue = {
            ...mapTranslationRow(existingRow),
            ...entry.value
        };
        const storageData = splitTranslationForStorage(mergedValue);

        await db.run(
            `INSERT INTO translations (key, en, ar, extra_languages_json)
             VALUES (?, ?, ?, ?)
             ON CONFLICT(key) DO UPDATE SET
                en = excluded.en,
                ar = excluded.ar,
                extra_languages_json = excluded.extra_languages_json`,
            [entry.key, storageData.en, storageData.ar, storageData.extraLanguagesJson]
        );
    }
}

async function broadcastFullData() {
    const { products, categories } = await getProductsAndCategories();
    const translations = await getTranslations();

    broadcast('products_updated', products);
    broadcast('categories_updated', categories);
    broadcast('translations_updated', translations);
}

async function sendInitialPublicData(ws) {
    const translations = await getTranslations();
    const status = await getCanteenStatus();
    const { products, categories } = await getProductsAndCategories();

    sendMessage(ws, 'initial_translations', translations);
    sendMessage(ws, 'initial_canteen_status', status);
    sendMessage(ws, 'initial_products', products);
    sendMessage(ws, 'initial_categories', categories);
}

async function sendInitialManagementData(ws) {
    const orders = await getAllOrders();
    const { products, categories } = await getProductsAndCategories();

    sendMessage(ws, 'initial_orders', orders);
    sendMessage(ws, 'initial_products', products);
    sendMessage(ws, 'initial_categories', categories);
}

async function generateOrderIdOnServer() {
    const now = new Date();
    const today = now.toISOString().split('T')[0];

    const rows = await db.query(
        `SELECT id FROM orders WHERE strftime('%Y-%m-%d', timestamp) = ?`,
        [today]
    );

    let maxSequence = 0;
    for (const row of rows) {
        const match = /^ORD-(\d+)-\d{2}-\d{2}(?:-\d{2,4})?$/.exec(String(row.id));
        const sequence = match ? Number.parseInt(match[1], 10) : Number.NaN;
        if (Number.isInteger(sequence) && sequence > maxSequence) {
            maxSequence = sequence;
        }
    }

    const day = String(now.getDate()).padStart(2, '0');
    const month = String(now.getMonth() + 1).padStart(2, '0');
    const year = String(now.getFullYear());

    return `ORD-${maxSequence + 1}-${day}-${month}-${year}`;
}

async function handleRequestInitialData(ws) {
    const status = await getCanteenStatus();
    if (!status.isOpen) {
        return;
    }

    const { products, categories } = await getProductsAndCategories();
    sendMessage(ws, 'initial_products', products);
    sendMessage(ws, 'initial_categories', categories);
}

async function handleIdentifyManagement(ws, clientInfo) {
    clientInfo.isManagement = true;
    clients.set(ws, clientInfo);

    console.log('Management client identified');
    await sendInitialManagementData(ws);
}

async function handleGetOrders(ws, clientInfo) {
    if (!clientInfo.isManagement) {
        return;
    }

    const orders = await getAllOrders();
    sendMessage(ws, 'initial_orders', orders);
}

async function handleUpdateOrderStatus(clientInfo, payload) {
    if (!clientInfo.isManagement) {
        return;
    }

    const orderId = sanitizeString(payload?.orderId, { maxLength: 128 });
    const newStatus = sanitizeString(payload?.newStatus, { maxLength: 32 });

    if (!orderId || !newStatus || !VALID_ORDER_STATUSES.has(newStatus)) {
        return;
    }

    await db.run('UPDATE orders SET status = ? WHERE id = ?', [newStatus, orderId]);
    const updatedOrder = await getOrderById(orderId);

    if (!updatedOrder) {
        return;
    }

    broadcastToManagement('order_status_updated_broadcast', {
        orderId,
        newStatus,
        updatedOrder
    });
}

async function handleRegisterUser(ws, payload) {
    const email = sanitizeEmail(payload?.email);
    const password = sanitizeString(payload?.password, { maxLength: 256 });

    if (!email || !password) {
        sendMessage(ws, 'register_error', { message: 'Missing details.' });
        return;
    }

    const existingUser = await db.get('SELECT email FROM users WHERE email = ?', [email]);
    if (existingUser) {
        sendMessage(ws, 'register_error', { message: 'Email already registered.' });
        return;
    }

    const profilePic = VALID_PROFILE_PICS.has(payload?.profilePic) ? payload.profilePic : 'pic2';
    const passwordHash = await bcrypt.hash(password, 10);

    await db.run(
        'INSERT INTO users (email, password_hash, profile_pic) VALUES (?, ?, ?)',
        [email, passwordHash, profilePic]
    );

    sendMessage(ws, 'register_success', {
        email,
        profilePic
    });
}

async function handleLoginUser(ws, payload) {
    const email = sanitizeEmail(payload?.email);
    const password = sanitizeString(payload?.password, { maxLength: 256 });

    if (!email || !password) {
        sendMessage(ws, 'login_error', { message: 'Invalid credentials.' });
        return;
    }

    const user = await db.get('SELECT * FROM users WHERE email = ?', [email]);
    if (!user) {
        sendMessage(ws, 'login_error', { message: 'Invalid credentials.' });
        return;
    }

    const isMatch = await bcrypt.compare(password, user.password_hash);
    if (!isMatch) {
        sendMessage(ws, 'login_error', { message: 'Invalid credentials.' });
        return;
    }

    sendMessage(ws, 'login_success', {
        email: user.email,
        profilePic: user.profile_pic
    });
}

async function handleAdminLogin(ws, clientInfo, payload) {
    const email = sanitizeEmail(payload?.email);
    const password = sanitizeString(payload?.password, { maxLength: 256 });

    if (!email || !password) {
        sendMessage(ws, 'admin_login_error', { message: 'Invalid credentials' });
        return;
    }

    const state = getAdminRateLimitState(clientInfo.ip);
    if (state.lockedUntil && Date.now() < state.lockedUntil) {
        sendMessage(ws, 'admin_login_error', {
            message: 'Too many failed attempts. Try again later.',
            retryAfterSeconds: Math.ceil((state.lockedUntil - Date.now()) / 1000)
        });
        return;
    }

    const isValidAdmin = email === SERVER_ADMIN_EMAIL && password === SERVER_ADMIN_PASSWORD;

    if (isValidAdmin) {
        clearAdminLoginFailures(clientInfo.ip);
        clientInfo.isManagement = true;
        clients.set(ws, clientInfo);

        sendMessage(ws, 'admin_login_success', { message: 'Success' });
        return;
    }

    const failureResult = recordAdminLoginFailure(clientInfo.ip);
    sendMessage(ws, 'admin_login_error', {
        message: failureResult.locked
            ? 'Too many failed attempts. Try again later.'
            : 'Invalid credentials',
        retryAfterSeconds: failureResult.retryAfterSeconds,
        attemptsRemaining: failureResult.attemptsRemaining
    });
}

async function handlePlaceOrder(ws, clientInfo, payload) {
    const status = await getCanteenStatus();
    if (!status.isOpen && !clientInfo.isManagement) {
        sendMessage(ws, 'order_rejected', { reason: 'Closed' });
        return;
    }

    let normalizedOrder;
    try {
        normalizedOrder = normalizeOrderPayload(payload);
    } catch (err) {
        if (err instanceof ClientError) {
            sendMessage(ws, 'order_rejected', err.payload);
            return;
        }
        throw err;
    }

    let orderId;

    try {
        await db.withTransaction(async () => {
            orderId = await generateOrderIdOnServer();
            const timestamp = new Date().toISOString();

            await db.run(
                `INSERT INTO orders (id, user_email, total_amount, status, payment_method, timestamp)
                 VALUES (?, ?, ?, ?, ?, ?)`,
                [
                    orderId,
                    normalizedOrder.userEmail,
                    normalizedOrder.totalAmount,
                    'pending',
                    normalizedOrder.paymentMethod,
                    timestamp
                ]
            );

            for (const item of normalizedOrder.items) {
                await db.run(
                    `INSERT INTO order_items (
                        order_id,
                        product_id,
                        quantity,
                        price_at_purchase,
                        is_discount,
                        name_key_at_purchase
                    ) VALUES (?, ?, ?, ?, ?, ?)`,
                    [
                        orderId,
                        item.id,
                        item.quantity,
                        item.price,
                        item.isDiscount ? 1 : 0,
                        item.name_key
                    ]
                );

                if (item.isDiscount) {
                    continue;
                }

                const product = await db.get('SELECT quantity FROM products WHERE id = ?', [item.id]);
                if (!product) {
                    throw new ClientError('Unavailable item.', {
                        reason: 'UnavailableItem',
                        itemId: item.id
                    });
                }

                if (product.quantity === 999) {
                    continue;
                }

                const currentQuantity = sanitizeInteger(product.quantity, { min: 0, max: 999999 });
                if (currentQuantity === null || currentQuantity < item.quantity) {
                    throw new ClientError('Insufficient stock.', {
                        reason: 'InsufficientStock',
                        itemId: item.id
                    });
                }

                await db.run(
                    'UPDATE products SET quantity = ? WHERE id = ?',
                    [currentQuantity - item.quantity, item.id]
                );
            }
        });
    } catch (err) {
        if (err instanceof ClientError) {
            sendMessage(ws, 'order_rejected', err.payload);
            return;
        }
        throw err;
    }

    const fullOrder = await getOrderById(orderId);
    const updatedProducts = await getAllProducts();

    if (fullOrder) {
        broadcastToManagement('new_order', fullOrder);
        sendMessage(ws, 'order_confirmed_by_server', fullOrder);
    }

    broadcast('products_updated', updatedProducts);
}

async function handleGetAnalyticsData(ws, clientInfo, payload) {
    if (!clientInfo.isManagement) {
        return;
    }

    const now = new Date();
    const requestedMonth = sanitizeInteger(payload?.month, { min: 1, max: 12 }) || now.getMonth() + 1;
    const requestedYear = sanitizeInteger(payload?.year, { min: 2000, max: 2100 }) || now.getFullYear();

    const monthString = String(requestedMonth).padStart(2, '0');
    const yearMonthFilter = `${requestedYear}-${monthString}`;

    const totalRevenueRow = await db.get(
        `SELECT SUM(total_amount) AS total FROM orders WHERE strftime('%Y-%m', timestamp) = ?`,
        [yearMonthFilter]
    );

    const totalOrdersRow = await db.get(
        `SELECT COUNT(*) AS count FROM orders WHERE strftime('%Y-%m', timestamp) = ?`,
        [yearMonthFilter]
    );

    const totalRevenue = totalRevenueRow?.total || 0;
    const totalOrders = totalOrdersRow?.count || 0;
    const avgOrderValue = totalOrders > 0 ? totalRevenue / totalOrders : 0;

    const products = await db.query('SELECT id, name_key, image FROM products');
    const salesRows = await db.query(
        `SELECT oi.product_id, SUM(oi.quantity) AS sold
         FROM order_items oi
         JOIN orders o ON oi.order_id = o.id
         WHERE oi.is_discount = 0 AND strftime('%Y-%m', o.timestamp) = ?
         GROUP BY oi.product_id`,
        [yearMonthFilter]
    );

    const salesByProductId = {};
    for (const row of salesRows) {
        salesByProductId[row.product_id] = row.sold;
    }

    const itemSalesRanking = products
        .map((product) => ({
            id: product.id,
            name_key: product.name_key,
            image: product.image,
            count: salesByProductId[product.id] || 0
        }))
        .sort((a, b) => b.count - a.count);

    const dailyRows = await db.query(
        `SELECT strftime('%d', timestamp) AS day, COUNT(*) AS count
         FROM orders
         WHERE strftime('%Y-%m', timestamp) = ?
         GROUP BY day`,
        [yearMonthFilter]
    );

    const dailyOrders = {};
    const daysInMonth = new Date(requestedYear, requestedMonth, 0).getDate();
    for (let day = 1; day <= daysInMonth; day += 1) {
        dailyOrders[day] = 0;
    }

    for (const row of dailyRows) {
        const day = Number.parseInt(row.day, 10);
        if (Number.isInteger(day) && dailyOrders[day] !== undefined) {
            dailyOrders[day] = row.count;
        }
    }

    const availableYearsRows = await db.query(
        `SELECT DISTINCT strftime('%Y', timestamp) AS year FROM orders ORDER BY year DESC`
    );

    const availableYears = availableYearsRows
        .map((row) => Number.parseInt(row.year, 10))
        .filter((year) => Number.isInteger(year));

    sendMessage(ws, 'analytics_data', {
        totalRevenue,
        totalOrders,
        avgOrderValue,
        itemSalesRanking,
        dailyOrders,
        selectedMonth: requestedMonth,
        selectedYear: requestedYear,
        availableYears
    });
}

function handleDiscoveryPasscode(ws, payload) {
    if (payload?.passcode === SERVER_DISCOVERY_PASSPHRASE) {
        sendMessage(ws, 'discovery_passcode_success');
        return;
    }

    sendMessage(ws, 'discovery_passcode_error');
}

async function handleAdminProductAdded(clientInfo, payload) {
    if (!clientInfo.isManagement) {
        return;
    }

    const product = normalizeProductPayload(payload?.product, payload?.categoryKey);
    if (!product) {
        return;
    }

    await db.run(
        `INSERT INTO products (id, name_key, description_key, price, quantity, image, category_key)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [
            product.id,
            product.name_key,
            product.description_key,
            product.price,
            product.quantity,
            product.image,
            product.category_key
        ]
    );

    if (payload?.translations) {
        await updateTranslations(payload.translations);
    }

    await broadcastFullData();
}

async function handleAdminProductUpdated(clientInfo, payload) {
    if (!clientInfo.isManagement) {
        return;
    }

    const productId = sanitizeString(payload?.productId, { maxLength: 128 });
    const updatedFields = payload?.updatedFields;

    if (!productId || !updatedFields || typeof updatedFields !== 'object') {
        return;
    }

    const price = sanitizeNumber(updatedFields.price, { min: 0, max: 1_000_000 });
    const quantity = sanitizeInteger(updatedFields.quantity, { min: 0, max: 999999 });
    const image = sanitizeOptionalString(updatedFields.image, { maxLength: 2048 }) || '';
    const category = sanitizeOptionalString(updatedFields.category, { maxLength: 128 });

    if (price === null || quantity === null) {
        return;
    }

    await db.run(
        `UPDATE products SET price = ?, quantity = ?, image = ?, category_key = ? WHERE id = ?`,
        [price, quantity, image, category, productId]
    );

    let translationUpdates = null;
    if (payload?.translations && typeof payload.translations === 'object' && !Array.isArray(payload.translations)) {
        translationUpdates = payload.translations;
    } else {
        translationUpdates = {};

        if (updatedFields.name_key) {
            translationUpdates[updatedFields.name_key] = {
                en: updatedFields.name_en,
                ar: updatedFields.name_ar
            };
        }

        if (updatedFields.description_key) {
            translationUpdates[updatedFields.description_key] = {
                en: updatedFields.description_en,
                ar: updatedFields.description_ar
            };
        }
    }

    if (translationUpdates && Object.keys(translationUpdates).length > 0) {
        await updateTranslations(translationUpdates);
    }

    await broadcastFullData();
}

async function handleAdminProductRemoved(clientInfo, payload) {
    if (!clientInfo.isManagement) {
        return;
    }

    const productId = sanitizeString(payload?.productId, { maxLength: 128 });
    if (!productId) {
        return;
    }

    await db.run('DELETE FROM products WHERE id = ?', [productId]);
    await broadcastFullData();
}

async function handleAdminCategoryAdded(clientInfo, payload) {
    if (!clientInfo.isManagement) {
        return;
    }

    const categoryKey = sanitizeString(payload?.category?.key, { maxLength: 128 });
    const categoryNameKey = sanitizeString(payload?.category?.name_key, { maxLength: 256 });
    if (!categoryKey || !categoryNameKey) {
        return;
    }

    const maxOrderRow = await db.get('SELECT COALESCE(MAX(display_order), -1) AS max_order FROM categories');
    const nextDisplayOrder = (maxOrderRow?.max_order ?? -1) + 1;

    await db.run(
        `INSERT INTO categories (key, name_key, display_order) VALUES (?, ?, ?)`,
        [categoryKey, categoryNameKey, nextDisplayOrder]
    );

    if (payload?.translations) {
        await updateTranslations(payload.translations);
    }

    await broadcastFullData();
}

async function handleAdminCategoryUpdated(clientInfo, payload) {
    if (!clientInfo.isManagement) {
        return;
    }

    const categoryKey = sanitizeString(payload?.categoryKey, { maxLength: 128 });
    const nameKey = sanitizeString(payload?.nameKey, { maxLength: 256 });

    if (!categoryKey || !nameKey) {
        return;
    }

    await db.run('UPDATE categories SET name_key = ? WHERE key = ?', [nameKey, categoryKey]);

    if (payload?.translations) {
        await updateTranslations(payload.translations);
    }

    await broadcastFullData();
}

async function handleAdminCategoryDeleted(clientInfo, payload) {
    if (!clientInfo.isManagement) {
        return;
    }

    const categoryKey = sanitizeString(payload?.categoryKey, { maxLength: 128 });
    if (!categoryKey) {
        return;
    }

    const countRow = await db.get(
        'SELECT COUNT(*) AS count FROM products WHERE category_key = ?',
        [categoryKey]
    );

    if ((countRow?.count || 0) > 0) {
        return;
    }

    await db.run('DELETE FROM categories WHERE key = ?', [categoryKey]);
    await broadcastFullData();
}

async function handleAdminSetCanteenStatus(clientInfo, payload) {
    if (!clientInfo.isManagement) {
        return;
    }

    const isOpen = Boolean(payload?.isOpen);

    await db.run(
        `INSERT OR REPLACE INTO settings (key, value) VALUES ('canteen_open', ?)`,
        [isOpen ? 'true' : 'false']
    );

    broadcast('canteen_status_updated', { isOpen });
}

async function handleAdminCategoriesReordered(clientInfo, payload) {
    if (!clientInfo.isManagement || !Array.isArray(payload)) {
        return;
    }

    await db.withTransaction(async () => {
        for (let index = 0; index < payload.length; index += 1) {
            const categoryKey = sanitizeString(payload[index]?.key, { maxLength: 128 });
            if (!categoryKey) {
                continue;
            }
            await db.run(
                'UPDATE categories SET display_order = ? WHERE key = ?',
                [index, categoryKey]
            );
        }
    });

    await broadcastFullData();
}

async function handleAdminCurrencyUpdated(clientInfo, payload) {
    if (!clientInfo.isManagement) {
        return;
    }

    await updateTranslations({ currency_symbol: payload?.currency });
    await broadcastFullData();
}

async function handleAdminConfigImported(clientInfo, payload) {
    if (!clientInfo.isManagement) {
        return;
    }

    if (!payload || typeof payload !== 'object') {
        return;
    }

    const rawCategories = Array.isArray(payload.categories) ? payload.categories : [];
    const rawProducts = Array.isArray(payload.products) ? payload.products : [];

    const categories = [];
    const categoryKeySet = new Set();

    for (let index = 0; index < rawCategories.length; index += 1) {
        const category = normalizeCategoryPayload(rawCategories[index], index);
        if (!category || categoryKeySet.has(category.key)) {
            continue;
        }

        categoryKeySet.add(category.key);
        categories.push(category);
    }

    const products = [];
    const productIdSet = new Set();

    for (const rawProduct of rawProducts) {
        const product = normalizeProductPayload(rawProduct);
        if (!product || productIdSet.has(product.id)) {
            continue;
        }

        if (!categoryKeySet.has(product.category_key)) {
            product.category_key = null;
        }

        productIdSet.add(product.id);
        products.push(product);
    }

    await db.withTransaction(async () => {
        await db.run('DELETE FROM products');
        await db.run('DELETE FROM categories');

        for (const category of categories) {
            await db.run(
                `INSERT INTO categories (key, name_key, display_order) VALUES (?, ?, ?)`,
                [category.key, category.name_key, category.display_order]
            );
        }

        for (const product of products) {
            await db.run(
                `INSERT INTO products (id, name_key, description_key, price, quantity, image, category_key)
                 VALUES (?, ?, ?, ?, ?, ?, ?)`,
                [
                    product.id,
                    product.name_key,
                    product.description_key,
                    product.price,
                    product.quantity,
                    product.image,
                    product.category_key
                ]
            );
        }

        if (payload.productRelatedTranslations && typeof payload.productRelatedTranslations === 'object') {
            await updateTranslations(payload.productRelatedTranslations);
        }
    });

    await broadcastFullData();
}

const messageHandlers = {
    request_initial_data: async ({ ws }) => handleRequestInitialData(ws),
    identify_management: async ({ ws, clientInfo }) => handleIdentifyManagement(ws, clientInfo),
    get_orders: async ({ ws, clientInfo }) => handleGetOrders(ws, clientInfo),
    update_order_status: async ({ clientInfo, payload }) => handleUpdateOrderStatus(clientInfo, payload),
    register_user: async ({ ws, payload }) => handleRegisterUser(ws, payload),
    login_user: async ({ ws, payload }) => handleLoginUser(ws, payload),
    admin_login: async ({ ws, clientInfo, payload }) => handleAdminLogin(ws, clientInfo, payload),
    place_order: async ({ ws, clientInfo, payload }) => handlePlaceOrder(ws, clientInfo, payload),
    get_analytics_data: async ({ ws, clientInfo, payload }) => handleGetAnalyticsData(ws, clientInfo, payload),
    verify_discovery_passcode: async ({ ws, payload }) => handleDiscoveryPasscode(ws, payload),
    admin_product_added: async ({ clientInfo, payload }) => handleAdminProductAdded(clientInfo, payload),
    admin_product_updated: async ({ clientInfo, payload }) => handleAdminProductUpdated(clientInfo, payload),
    admin_product_removed: async ({ clientInfo, payload }) => handleAdminProductRemoved(clientInfo, payload),
    admin_category_added: async ({ clientInfo, payload }) => handleAdminCategoryAdded(clientInfo, payload),
    admin_category_updated: async ({ clientInfo, payload }) => handleAdminCategoryUpdated(clientInfo, payload),
    admin_category_deleted: async ({ clientInfo, payload }) => handleAdminCategoryDeleted(clientInfo, payload),
    admin_set_canteen_status: async ({ clientInfo, payload }) => handleAdminSetCanteenStatus(clientInfo, payload),
    admin_categories_reordered: async ({ clientInfo, payload }) => handleAdminCategoriesReordered(clientInfo, payload),
    admin_currency_updated: async ({ clientInfo, payload }) => handleAdminCurrencyUpdated(clientInfo, payload),
    admin_config_imported: async ({ clientInfo, payload }) => handleAdminConfigImported(clientInfo, payload)
};

function markConnectionAlive() {
    this.isAlive = true;
}

const heartbeatInterval = setInterval(() => {
    for (const ws of wss.clients) {
        if (ws.readyState !== WebSocket.OPEN) {
            continue;
        }

        if (ws.isAlive === false) {
            ws.terminate();
            continue;
        }

        ws.isAlive = false;
        ws.ping();
    }
}, WS_HEARTBEAT_INTERVAL_MS);
heartbeatInterval.unref();

wss.on('connection', async (ws, req) => {
    const ip = getClientIp(req);
    const clientInfo = { isManagement: false, ip };
    clients.set(ws, clientInfo);
    ws.isAlive = true;
    ws.on('pong', markConnectionAlive);

    console.log(`Client connected from ${ip}`);

    try {
        await sendInitialPublicData(ws);
    } catch (err) {
        console.error('Failed to send initial data:', err);
    }

    ws.on('message', async (message) => {
        const parsed = parseClientMessage(message);
        if (!parsed) {
            sendMessage(ws, 'request_error', { message: 'Invalid message format.' });
            return;
        }

        const info = clients.get(ws);
        if (!info) {
            ws.terminate();
            return;
        }

        const handler = messageHandlers[parsed.type];
        if (!handler) {
            console.warn(`Unknown message type received: ${parsed.type}`);
            return;
        }

        try {
            await handler({ ws, clientInfo: info, payload: parsed.payload });
        } catch (err) {
            console.error(`Error processing message type "${parsed.type}":`, err);
            if (err instanceof ClientError) {
                sendMessage(ws, 'request_error', {
                    message: err.message,
                    ...err.payload
                });
            }
        }
    });

    ws.on('close', () => {
        clients.delete(ws);
    });

    ws.on('error', (err) => {
        console.error(`WebSocket error for ${ip}:`, err);
    });
});

wss.on('error', (err) => {
    console.error('WebSocket server error:', err);
});

server.on('error', (err) => {
    console.error('HTTP server error:', err);
    process.exit(1);
});

async function start() {
    try {
        await db.initDatabase();
        console.log('Database initialized successfully.');

        server.listen(PORT, () => {
            const localIp = getLocalIpAddress();
            const separator = '===================================================';

            console.log(`\n${separator}`);
            console.log('EVA Canteen Server Running (SQLite)');
            console.log(separator);
            console.log(`\nLocal:            http://localhost:${PORT}`);
            console.log(`On Your Network:  http://${localIp}:${PORT}`);
            console.log(`\n${separator}\n`);
        });
    } catch (err) {
        console.error('Failed to initialize database or start server:', err);
        process.exit(1);
    }
}

start();

function shutdown(signal) {
    console.log(`Received ${signal}, shutting down...`);
    clearInterval(heartbeatInterval);

    server.close(async () => {
        try {
            await db.close();
        } catch (err) {
            console.error('Failed to close database cleanly:', err);
        } finally {
            process.exit(0);
        }
    });

    setTimeout(() => process.exit(1), 10_000).unref();
}

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));
