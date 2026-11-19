/**
 * EVA Canteen - WebSocket + HTTP Server
 * Copyright (C) 2025 EVA International School
 */

const crypto = require('crypto');
const express = require('express');
const fs = require('fs');
const http = require('http');
const jwt = require('jsonwebtoken');
const os = require('os');
const path = require('path');
const WebSocket = require('ws');

const db = require('./database');
const { hashPassword, comparePassword } = require('./password_hash');
const { createPushService, normalizePushLocale } = require('./push_service');

const pushService = createPushService({ db });

const app = express();
app.set('trust proxy', 1);
const server = http.createServer(app);
const wss = new WebSocket.Server({
    server,
    maxPayload: 64 * 1024
});

const PORT = Number(process.env.PORT) || 8080;
const HOST = (process.env.HOST || '0.0.0.0').trim();

const SERVER_ADMIN_EMAIL = (process.env.ADMIN_EMAIL || 'admin@canteen.app').trim().toLowerCase();
const SERVER_ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'admin123';
const SERVER_DISCOVERY_PASSPHRASE = process.env.DISCOVERY_PASSPHRASE || '12345';
const JWT_SECRET =
    process.env.JWT_SECRET ||
    crypto
        .createHash('sha256')
        .update(`${SERVER_ADMIN_EMAIL}:${SERVER_ADMIN_PASSWORD}:eva-canteen-jwt-v1`)
        .digest('hex');

const UPLOADS_DIR = path.resolve(process.env.UPLOADS_DIR || path.join(__dirname, 'uploads'));
const FLUTTER_WEB_DIR = path.join(__dirname, 'flutter_app', 'build', 'web');
if (!fs.existsSync(UPLOADS_DIR)) {
    fs.mkdirSync(UPLOADS_DIR, { recursive: true });
}

function resolveWebMode() {
    const cliArgs = new Set(process.argv.slice(2).map((arg) => arg.trim().toLowerCase()));
    const envMode = (process.env.WEB_MODE || '').trim().toLowerCase();

    if (
        cliArgs.has('--web-flutter') ||
        cliArgs.has('web-flutter') ||
        cliArgs.has('start:web-flutter') ||
        envMode === 'flutter' ||
        envMode === 'web-flutter'
    ) {
        return 'flutter';
    }

    if (
        cliArgs.has('--old-web') ||
        cliArgs.has('old-web') ||
        cliArgs.has('start:old-web') ||
        envMode === 'old-web' ||
        envMode === 'legacy' ||
        process.env.SERVE_LEGACY_ROOT === 'true'
    ) {
        return 'old-web';
    }

    return 'none';
}

const WEB_MODE = resolveWebMode();

const MAX_ADMIN_FAILED_ATTEMPTS = 5;
const ADMIN_LOCKOUT_DURATION_MS = 5 * 60 * 1000;
const LANGUAGE_CODE_PATTERN = /^[a-z]{2,3}(?:-[a-z0-9]{2,8})*$/i;
const MAX_WS_MESSAGE_BYTES = 64 * 1024;
const WS_HEARTBEAT_INTERVAL_MS = 30 * 1000;
const SETTINGS_KEY_PRODUCT_ORDER_MAP = 'category_product_order_map';
const SETTINGS_KEY_PAYMENT_METHODS = 'payment_methods';

const VALID_ORDER_STATUSES = new Set(['pending', 'preparing', 'delivered']);
const VALID_PROFILE_PICS = new Set(['pic1', 'pic2', 'pic3']);
const VALID_PAYMENT_METHODS = new Set(['cash', 'card', 'wallet']);
const VALID_PUSH_PLATFORMS = new Set(['android', 'ios', 'web']);

const clients = new Map();
const failedAdminLoginAttempts = new Map();

function signAuthToken(claims) {
    return jwt.sign(claims, JWT_SECRET, { expiresIn: '30d' });
}

function verifyAuthToken(token) {
    if (typeof token !== 'string' || !token.trim()) {
        return null;
    }
    try {
        const decoded = jwt.verify(token.trim(), JWT_SECRET);
        return decoded && typeof decoded === 'object' ? decoded : null;
    } catch {
        return null;
    }
}

function normalizeProfilePic(rawPic) {
    if (typeof rawPic !== 'string' || !rawPic.trim()) {
        return 'pic2';
    }
    const trimmed = rawPic.trim();
    if (VALID_PROFILE_PICS.has(trimmed)) {
        return trimmed;
    }
    if (trimmed.includes('pfp1') || trimmed.includes('6pkqNQdB')) {
        return 'pic1';
    }
    if (trimmed.includes('pfp3') || trimmed.includes('sXy2v068')) {
        return 'pic3';
    }
    return 'pic2';
}

function extractBearerToken(req) {
    const authHeader = req.headers.authorization || '';
    return authHeader.startsWith('Bearer ') ? authHeader.slice(7).trim() : null;
}

app.use(express.json({ limit: '6mb' }));
app.use((req, res, next) => {
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, DELETE, OPTIONS');
    if (WEB_MODE === 'flutter') {
        res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
        res.setHeader('Cross-Origin-Embedder-Policy', 'credentialless');
    }
    if (req.method === 'OPTIONS') {
        res.sendStatus(204);
        return;
    }
    next();
});

app.get('/api/health', (_req, res) => {
    res.json({
        ok: true,
        version: '1.1.0',
        mode: WEB_MODE,
        pushEnabled: pushService.isEnabled()
    });
});

app.post('/api/push-tokens', async (req, res) => {
    try {
        const decoded = verifyAuthToken(extractBearerToken(req));
        const userRole = decoded?.role;
        const userEmail = sanitizeEmail(decoded?.email);
        if (!decoded || !userEmail || (userRole !== 'user' && userRole !== 'admin')) {
            res.status(401).json({ error: 'Unauthorized' });
            return;
        }

        if (userRole === 'user') {
            const existingUser = await db.get('SELECT email FROM users WHERE email = ?', [userEmail]);
            if (!existingUser) {
                res.status(401).json({ error: 'Account not found' });
                return;
            }
        }

        const rawToken = typeof req.body?.token === 'string' ? req.body.token.trim() : '';
        if (rawToken.length < 16 || rawToken.length > 4096) {
            res.status(400).json({ error: 'Invalid push token.' });
            return;
        }

        const rawPlatform = typeof req.body?.platform === 'string'
            ? req.body.platform.trim().toLowerCase()
            : '';
        if (!VALID_PUSH_PLATFORMS.has(rawPlatform)) {
            res.status(400).json({ error: 'Invalid platform. Expected android, ios, or web.' });
            return;
        }

        const locale = normalizePushLocale(req.body?.locale);

        await db.run(
            `INSERT INTO device_push_tokens (token, user_email, user_role, platform, locale, updated_at)
             VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
             ON CONFLICT(token) DO UPDATE SET
                user_email = excluded.user_email,
                user_role = excluded.user_role,
                platform = excluded.platform,
                locale = excluded.locale,
                updated_at = CURRENT_TIMESTAMP`,
            [rawToken, userEmail, userRole, rawPlatform, locale]
        );

        res.json({ ok: true });
    } catch (err) {
        console.error('Failed to register push token:', err);
        res.status(500).json({ error: 'Failed to register push token.' });
    }
});

app.delete('/api/push-tokens', async (req, res) => {
    try {
        const decoded = verifyAuthToken(extractBearerToken(req));
        const userRole = decoded?.role;
        const userEmail = sanitizeEmail(decoded?.email);
        if (!decoded || !userEmail || (userRole !== 'user' && userRole !== 'admin')) {
            res.status(401).json({ error: 'Unauthorized' });
            return;
        }

        const rawToken = typeof req.body?.token === 'string' ? req.body.token.trim() : '';
        if (rawToken.length < 16 || rawToken.length > 4096) {
            res.status(400).json({ error: 'Invalid push token.' });
            return;
        }

        const result = await db.run(
            'DELETE FROM device_push_tokens WHERE token = ? AND LOWER(user_email) = ?',
            [rawToken, userEmail]
        );

        res.json({ ok: true, deleted: (result.changes || 0) > 0 });
    } catch (err) {
        console.error('Failed to unregister push token:', err);
        res.status(500).json({ error: 'Failed to unregister push token.' });
    }
});

app.post('/api/upload-image', (req, res) => {
    const decoded = verifyAuthToken(extractBearerToken(req));
    if (!decoded || decoded.role !== 'admin') {
        res.status(401).json({ error: 'Unauthorized' });
        return;
    }

    const dataUrl = typeof req.body?.dataUrl === 'string' ? req.body.dataUrl.trim() : '';
    const match = /^data:image\/(png|jpeg|jpg|webp|gif);base64,([A-Za-z0-9+/=\s]+)$/i.exec(dataUrl);
    if (!match) {
        res.status(400).json({ error: 'Invalid image payload. Expected base64 data URL.' });
        return;
    }

    const rawExt = match[1].toLowerCase();
    const ext = rawExt === 'jpeg' ? 'jpg' : rawExt;
    const buffer = Buffer.from(match[2].replace(/\s+/g, ''), 'base64');
    if (buffer.length === 0 || buffer.length > 5 * 1024 * 1024) {
        res.status(400).json({ error: 'Image size must be between 1 byte and 5 MB.' });
        return;
    }

    const filename = `prod-${Date.now()}-${crypto.randomBytes(4).toString('hex')}.${ext}`;
    fs.writeFileSync(path.join(UPLOADS_DIR, filename), buffer);
    res.json({ url: `/uploads/${filename}` });
});

app.use('/uploads', express.static(UPLOADS_DIR));
app.use('/releases', express.static(path.join(__dirname, 'releases'), {
    setHeaders: (res, filePath) => {
        if (filePath.endsWith('.apk')) {
            res.setHeader('Content-Type', 'application/vnd.android.package-archive');
            res.setHeader('Content-Disposition', `attachment; filename="${path.basename(filePath)}"`);
        }
    }
}));
app.use('/assets', express.static(path.join(__dirname, 'assets')));

if (WEB_MODE === 'flutter') {
    app.use(express.static(FLUTTER_WEB_DIR));
    app.get('/{*splat}', (req, res, next) => {
        if (req.path.startsWith('/api/') || path.extname(req.path)) {
            next();
            return;
        }
        const flutterIndex = path.join(FLUTTER_WEB_DIR, 'index.html');
        if (fs.existsSync(flutterIndex)) {
            res.sendFile(flutterIndex);
            return;
        }
        res.status(503).json({
            ok: false,
            mode: 'flutter',
            error: 'Flutter web build not found at flutter_app/build/web. Run "npm run start:web-flutter" or "npm run build:flutter" first.'
        });
    });
} else if (WEB_MODE === 'old-web') {
    app.use('/fonts', express.static(path.join(__dirname, 'fonts')));
    app.use('/legacy', express.static(path.join(__dirname, '')));
    app.use(express.static(path.join(__dirname, '')));
} else {
    app.get('/', (_req, res) => {
        res.json({
            ok: true,
            mode: 'backend-only',
            message: 'EVA Canteen Backend Server is running. Use "npm run start:web-flutter" for Flutter Web (Wasm) or "npm run start:old-web" for the legacy web UI.'
        });
    });
}

class ClientError extends Error {
    constructor(message, payload = {}) {
        super(message);
        this.name = 'ClientError';
        this.payload = payload;
    }
}

function getLocalIpAddress() {
    try {
        const interfaces = os.networkInterfaces();
        for (const name of Object.keys(interfaces)) {
            for (const iface of interfaces[name] || []) {
                if (iface.family === 'IPv4' && !iface.internal) {
                    return iface.address;
                }
            }
        }
    } catch {
        // Android / Termux SELinux can restrict rtnetlink interface enumeration.
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

function sendToUser(email, type, payload) {
    const normalizedEmail = sanitizeEmail(email);
    if (!normalizedEmail) {
        return;
    }
    for (const [ws, info] of clients.entries()) {
        if (info.userEmail === normalizedEmail && ws.readyState === WebSocket.OPEN) {
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

function normalizeOrderPayload(payload, authenticatedEmail = null) {
    if (!payload || typeof payload !== 'object') {
        throw new ClientError('Invalid order payload.', { reason: 'InvalidOrder' });
    }

    const totalAmount = sanitizeNumber(payload.totalAmount, { min: 0 });
    if (totalAmount === null) {
        throw new ClientError('Invalid order total.', { reason: 'InvalidOrderTotal' });
    }

    const rawMethod = (sanitizeString(payload.paymentMethod, { maxLength: 24 }) || 'cash').toLowerCase();
    const paymentMethod = VALID_PAYMENT_METHODS.has(rawMethod) ? rawMethod : 'cash';
    const userEmail = sanitizeEmail(authenticatedEmail) || sanitizeEmail(payload.user?.email);

    if (!Array.isArray(payload.items) || payload.items.length === 0) {
        throw new ClientError('Order has no items.', { reason: 'EmptyOrder' });
    }

    const items = payload.items.map((item, index) => {
        const id = sanitizeString(item?.id, { maxLength: 128 });
        const quantity = sanitizeInteger(item?.quantity, { min: 1, max: 9999 });
        const isDiscount = Boolean(item?.isDiscount);
        const price = isDiscount
            ? sanitizeNumber(item?.price, { min: -1_000_000, max: 1_000_000 })
            : sanitizeNumber(item?.price, { min: 0, max: 1_000_000 });
        const nameKey = sanitizeOptionalString(item?.name_key, { maxLength: 256 }) || '';
        const bundleId = sanitizeOptionalString(item?.bundleId, { maxLength: 128 }) || null;

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
            isDiscount,
            bundleId,
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

function normalizeProductOrderMap(rawValue, categoryKeySet = null) {
    if (!rawValue || typeof rawValue !== 'object' || Array.isArray(rawValue)) {
        return {};
    }

    const normalized = {};

    for (const [rawCategoryKey, rawProductIds] of Object.entries(rawValue)) {
        const categoryKey = sanitizeString(rawCategoryKey, { maxLength: 128 });
        if (!categoryKey) {
            continue;
        }
        if (categoryKeySet && !categoryKeySet.has(categoryKey)) {
            continue;
        }
        if (!Array.isArray(rawProductIds)) {
            continue;
        }

        const productIdSet = new Set();
        const productIds = [];

        for (const rawProductId of rawProductIds) {
            const productId = sanitizeString(rawProductId, { maxLength: 128 });
            if (!productId || productIdSet.has(productId)) {
                continue;
            }

            productIdSet.add(productId);
            productIds.push(productId);
        }

        normalized[categoryKey] = productIds;
    }

    return normalized;
}

async function getStoredProductOrderMap() {
    const row = await db.get('SELECT value FROM settings WHERE key = ?', [SETTINGS_KEY_PRODUCT_ORDER_MAP]);
    if (!row?.value) {
        return {};
    }

    try {
        const parsed = JSON.parse(row.value);
        return normalizeProductOrderMap(parsed);
    } catch {
        return {};
    }
}

async function saveProductOrderMap(productOrderMap) {
    const sanitizedMap = normalizeProductOrderMap(productOrderMap);
    await db.run(
        `INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)`,
        [SETTINGS_KEY_PRODUCT_ORDER_MAP, JSON.stringify(sanitizedMap)]
    );
}

async function getAllCategories(products = null) {
    const productList = products || (await getAllProducts());
    const rows = await db.query('SELECT * FROM categories ORDER BY display_order, key');
    const storedProductOrderMap = await getStoredProductOrderMap();
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

    return rows.map((cat) => {
        const actualProductIds = productIdsByCategory.get(cat.key) || [];
        const actualProductIdSet = new Set(actualProductIds);
        const storedProductIds = Array.isArray(storedProductOrderMap[cat.key])
            ? storedProductOrderMap[cat.key]
            : [];

        const orderedProductIds = storedProductIds.filter((productId) => actualProductIdSet.has(productId));
        const orderedProductIdSet = new Set(orderedProductIds);

        for (const productId of actualProductIds) {
            if (!orderedProductIdSet.has(productId)) {
                orderedProductIds.push(productId);
            }
        }

        return {
            key: cat.key,
            name_key: cat.name_key,
            productIds: orderedProductIds
        };
    });
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

async function getPaymentMethods() {
    const row = await db.get('SELECT value FROM settings WHERE key = ?', [SETTINGS_KEY_PAYMENT_METHODS]);
    const defaults = { cash: true, card: true, wallet: true };
    if (!row?.value) {
        return defaults;
    }
    try {
        const parsed = JSON.parse(row.value);
        return {
            cash: parsed?.cash !== false,
            card: parsed?.card !== false,
            wallet: parsed?.wallet !== false
        };
    } catch {
        return defaults;
    }
}

async function getAllBundles({ activeOnly = false } = {}) {
    const sql = activeOnly
        ? 'SELECT * FROM bundles WHERE active = 1 ORDER BY display_order ASC, id ASC'
        : 'SELECT * FROM bundles ORDER BY display_order ASC, id ASC';
    const rows = await db.query(sql);
    return rows.map((row) => {
        let itemIds = [];
        try {
            const parsed = JSON.parse(row.item_ids_json || '[]');
            if (Array.isArray(parsed)) {
                itemIds = parsed
                    .map((id) => sanitizeString(id, { maxLength: 128 }))
                    .filter(Boolean);
            }
        } catch {
            itemIds = [];
        }
        return {
            id: row.id,
            name_key: row.name_key,
            description_key: row.description_key,
            itemIds,
            discountPercent: Number(row.discount_percent || 0),
            isSuggestion: Boolean(row.is_suggestion),
            active: Boolean(row.active),
            displayOrder: Number(row.display_order || 0)
        };
    });
}

function formatMappedOrders(orders, items) {
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
                email: order.user_email || 'Guest',
                profilePic: 'pic2'
            }
    }));
}

async function getAllOrders() {
    const orders = await db.query(
        `SELECT o.*, u.email AS resolved_user_email, u.profile_pic AS resolved_profile_pic
         FROM orders o
         LEFT JOIN users u ON o.user_email = u.email
         ORDER BY o.timestamp DESC`
    );

    const items = await db.query('SELECT * FROM order_items ORDER BY id ASC');
    return formatMappedOrders(orders, items);
}

async function getOrdersByUserEmail(email) {
    const normalizedEmail = sanitizeEmail(email);
    if (!normalizedEmail) {
        return [];
    }

    const orders = await db.query(
        `SELECT o.*, u.email AS resolved_user_email, u.profile_pic AS resolved_profile_pic
         FROM orders o
         LEFT JOIN users u ON o.user_email = u.email
         WHERE LOWER(o.user_email) = ?
         ORDER BY o.timestamp DESC`,
        [normalizedEmail]
    );
    if (orders.length === 0) {
        return [];
    }

    const placeholders = orders.map(() => '?').join(', ');
    const items = await db.query(
        `SELECT * FROM order_items WHERE order_id IN (${placeholders}) ORDER BY id ASC`,
        orders.map((o) => o.id)
    );
    return formatMappedOrders(orders, items);
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
    return formatMappedOrders([order], items)[0] || null;
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
    const activeBundles = await getAllBundles({ activeOnly: true });
    const allBundles = await getAllBundles({ activeOnly: false });

    broadcast('products_updated', products);
    broadcast('categories_updated', categories);
    broadcast('translations_updated', translations);
    broadcast('bundles_updated', activeBundles);
    broadcastToManagement('admin_bundles_updated', allBundles);
}

async function sendInitialPublicData(ws) {
    const translations = await getTranslations();
    const status = await getCanteenStatus();
    const { products, categories } = await getProductsAndCategories();
    const bundles = await getAllBundles({ activeOnly: true });
    const paymentMethods = await getPaymentMethods();

    sendMessage(ws, 'initial_translations', translations);
    sendMessage(ws, 'initial_canteen_status', status);
    sendMessage(ws, 'initial_products', products);
    sendMessage(ws, 'initial_categories', categories);
    sendMessage(ws, 'initial_bundles', bundles);
    sendMessage(ws, 'initial_payment_methods', paymentMethods);
}

async function sendInitialManagementData(ws) {
    const orders = await getAllOrders();
    const { products, categories } = await getProductsAndCategories();
    const allBundles = await getAllBundles({ activeOnly: false });
    const paymentMethods = await getPaymentMethods();

    sendMessage(ws, 'initial_orders', orders);
    sendMessage(ws, 'initial_products', products);
    sendMessage(ws, 'initial_categories', categories);
    sendMessage(ws, 'admin_bundles_updated', allBundles);
    sendMessage(ws, 'initial_payment_methods', paymentMethods);
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
    const { products, categories } = await getProductsAndCategories();
    const bundles = await getAllBundles({ activeOnly: true });
    const paymentMethods = await getPaymentMethods();
    sendMessage(ws, 'initial_products', products);
    sendMessage(ws, 'initial_categories', categories);
    sendMessage(ws, 'initial_bundles', bundles);
    sendMessage(ws, 'initial_payment_methods', paymentMethods);
}

async function handleIdentifyManagement(ws, clientInfo, payload) {
    if (!clientInfo.isManagement) {
        const decoded = verifyAuthToken(payload?.token);
        if (!decoded || decoded.role !== 'admin') {
            sendMessage(ws, 'admin_auth_required', {
                message: 'Valid management session token is required.'
            });
            return;
        }
        clientInfo.isManagement = true;
        clients.set(ws, clientInfo);
    }

    console.log('Management client identified');
    await sendInitialManagementData(ws);
}

async function handleAuthenticateSession(ws, clientInfo, payload) {
    const decoded = verifyAuthToken(payload?.token);
    if (!decoded) {
        sendMessage(ws, 'session_expired', { message: 'Session token expired or invalid.' });
        return;
    }

    if (decoded.role === 'admin') {
        clientInfo.isManagement = true;
        clients.set(ws, clientInfo);
        sendMessage(ws, 'session_restored', {
            role: 'admin',
            email: decoded.email || SERVER_ADMIN_EMAIL
        });
        await sendInitialManagementData(ws);
        return;
    }

    if (decoded.role === 'user' && decoded.email) {
        const user = await db.get('SELECT email, profile_pic, balance FROM users WHERE email = ?', [
            sanitizeEmail(decoded.email)
        ]);
        if (!user) {
            sendMessage(ws, 'session_expired', { message: 'Account not found.' });
            return;
        }

        clientInfo.userEmail = user.email;
        clients.set(ws, clientInfo);

        sendMessage(ws, 'session_restored', {
            role: 'user',
            email: user.email,
            profilePic: user.profile_pic || 'pic2',
            balance: Number(user.balance || 0)
        });

        const myOrders = await getOrdersByUserEmail(user.email);
        sendMessage(ws, 'my_orders', myOrders);
        return;
    }

    sendMessage(ws, 'session_expired', { message: 'Unrecognized session role.' });
}

async function handleGetMyOrders(ws, clientInfo, payload) {
    let email = clientInfo.userEmail;
    if (!email && payload?.token) {
        const decoded = verifyAuthToken(payload.token);
        if (decoded?.role === 'user' && decoded.email) {
            email = sanitizeEmail(decoded.email);
            clientInfo.userEmail = email;
            clients.set(ws, clientInfo);
        }
    }

    if (!email) {
        sendMessage(ws, 'my_orders', []);
        return;
    }

    const orders = await getOrdersByUserEmail(email);
    sendMessage(ws, 'my_orders', orders);
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

    let shouldNotifyReady = false;
    let foundOrder = false;

    await db.withTransaction(async () => {
        const existing = await db.get(
            'SELECT status, ready_notified_at FROM orders WHERE id = ?',
            [orderId]
        );
        if (!existing) {
            return;
        }
        foundOrder = true;

        await db.run('UPDATE orders SET status = ? WHERE id = ?', [newStatus, orderId]);

        if (existing.status !== 'delivered' && newStatus === 'delivered') {
            const claim = await db.run(
                'UPDATE orders SET ready_notified_at = ? WHERE id = ? AND ready_notified_at IS NULL',
                [new Date().toISOString(), orderId]
            );
            shouldNotifyReady = (claim.changes || 0) === 1;
        } else if (existing.status === 'delivered' && newStatus === 'pending') {
            await db.run('UPDATE orders SET ready_notified_at = NULL WHERE id = ?', [orderId]);
        }
    });

    if (!foundOrder) {
        return;
    }

    const updatedOrder = await getOrderById(orderId);
    if (!updatedOrder) {
        return;
    }

    const updatePayload = {
        orderId,
        newStatus,
        updatedOrder
    };

    broadcastToManagement('order_status_updated_broadcast', updatePayload);
    if (updatedOrder.user?.email && updatedOrder.user.email !== 'Guest') {
        sendToUser(updatedOrder.user.email, 'my_order_updated', updatePayload);

        if (shouldNotifyReady) {
            pushService
                .sendOrderReadyNotification(updatedOrder)
                .then((summary) => {
                    console.log(
                        `Order ready push for ${orderId}: sent=${summary.sent} failed=${summary.failed} pruned=${summary.pruned} skipped=${summary.skipped || 'none'}`
                    );
                })
                .catch((err) => {
                    console.error(`Failed to send order ready push for ${orderId}:`, err);
                });
        }
    }
}

async function handleRegisterUser(ws, clientInfo, payload) {
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

    const profilePic = normalizeProfilePic(payload?.profilePic);
    const passwordHash = await hashPassword(password, 10);

    await db.run(
        'INSERT INTO users (email, password_hash, profile_pic, balance) VALUES (?, ?, ?, 0)',
        [email, passwordHash, profilePic]
    );

    clientInfo.userEmail = email;
    clients.set(ws, clientInfo);
    const token = signAuthToken({ role: 'user', email });

    sendMessage(ws, 'register_success', {
        email,
        profilePic,
        balance: 0,
        token
    });
    sendMessage(ws, 'my_orders', []);
}

async function handleLoginUser(ws, clientInfo, payload) {
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

    const isMatch = await comparePassword(password, user.password_hash);
    if (!isMatch) {
        sendMessage(ws, 'login_error', { message: 'Invalid credentials.' });
        return;
    }

    clientInfo.userEmail = user.email;
    clients.set(ws, clientInfo);
    const token = signAuthToken({ role: 'user', email: user.email });

    sendMessage(ws, 'login_success', {
        email: user.email,
        profilePic: user.profile_pic || 'pic2',
        balance: Number(user.balance || 0),
        token
    });

    const myOrders = await getOrdersByUserEmail(user.email);
    sendMessage(ws, 'my_orders', myOrders);
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
        const token = signAuthToken({ role: 'admin', email: SERVER_ADMIN_EMAIL });

        sendMessage(ws, 'admin_login_success', {
            message: 'Success',
            email: SERVER_ADMIN_EMAIL,
            token
        });
        await sendInitialManagementData(ws);
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
        normalizedOrder = normalizeOrderPayload(payload, clientInfo.userEmail);
    } catch (err) {
        if (err instanceof ClientError) {
            sendMessage(ws, 'order_rejected', err.payload);
            return;
        }
        throw err;
    }

    const paymentMethods = await getPaymentMethods();
    if (!paymentMethods[normalizedOrder.paymentMethod]) {
        sendMessage(ws, 'order_rejected', {
            reason: 'PaymentMethodDisabled',
            paymentMethod: normalizedOrder.paymentMethod
        });
        return;
    }

    const regularItems = normalizedOrder.items.filter((item) => !item.isDiscount);
    if (regularItems.length === 0) {
        sendMessage(ws, 'order_rejected', { reason: 'EmptyOrder' });
        return;
    }

    let orderId;
    let updatedWalletBalance = null;

    try {
        await db.withTransaction(async () => {
            orderId = await generateOrderIdOnServer();
            const timestamp = new Date().toISOString();

            const productMap = new Map();
            const itemQtyByProductId = new Map();
            let authoritativeSubtotal = 0;

            for (const item of regularItems) {
                const product = await db.get('SELECT * FROM products WHERE id = ?', [item.id]);
                if (!product || product.category_key === 'archive') {
                    throw new ClientError('Unavailable item.', {
                        reason: 'UnavailableItem',
                        itemId: item.id
                    });
                }

                productMap.set(item.id, product);
                const aggregatedQty = (itemQtyByProductId.get(item.id) || 0) + item.quantity;
                itemQtyByProductId.set(item.id, aggregatedQty);

                if (product.quantity !== 999) {
                    const currentQuantity = sanitizeInteger(product.quantity, { min: 0, max: 999999 });
                    if (currentQuantity === null || currentQuantity < aggregatedQty) {
                        throw new ClientError('Insufficient stock.', {
                            reason: 'InsufficientStock',
                            itemId: item.id
                        });
                    }
                }

                authoritativeSubtotal += Number(product.price) * item.quantity;
            }

            const activeBundles = await getAllBundles({ activeOnly: true });
            const activeBundlesById = new Map(
                activeBundles.filter((b) => !b.isSuggestion && b.discountPercent > 0).map((b) => [b.id, b])
            );

            const appliedBundleIds = new Set();
            const validatedDiscountItems = [];
            let totalDiscountAmount = 0;

            for (const discountReq of normalizedOrder.items.filter((item) => item.isDiscount)) {
                let resolvedBundleId = discountReq.bundleId;
                if (!resolvedBundleId && discountReq.id.startsWith('discount-')) {
                    for (const candidateId of activeBundlesById.keys()) {
                        if (discountReq.id.startsWith(`discount-${candidateId}`)) {
                            resolvedBundleId = candidateId;
                            break;
                        }
                    }
                }

                const bundle = resolvedBundleId ? activeBundlesById.get(resolvedBundleId) : null;
                if (!bundle || appliedBundleIds.has(bundle.id) || bundle.itemIds.length === 0) {
                    continue;
                }

                let qualifyingSets = Number.POSITIVE_INFINITY;
                let singleBundleBaseSum = 0;
                let qualifies = true;

                for (const reqItemId of bundle.itemIds) {
                    const qtyInCart = itemQtyByProductId.get(reqItemId) || 0;
                    const prod = productMap.get(reqItemId);
                    if (qtyInCart < 1 || !prod) {
                        qualifies = false;
                        break;
                    }
                    qualifyingSets = Math.min(qualifyingSets, qtyInCart);
                    singleBundleBaseSum += Number(prod.price);
                }

                if (!qualifies || !Number.isFinite(qualifyingSets) || qualifyingSets < 1) {
                    continue;
                }

                const setsToApply = Math.max(1, Math.min(qualifyingSets, discountReq.quantity || 1));
                const singleDiscount = singleBundleBaseSum - Math.round(singleBundleBaseSum * ((100 - bundle.discountPercent) / 100));
                const discountValue = Math.max(0, Number((singleDiscount * setsToApply).toFixed(2)));

                if (discountValue > 0) {
                    appliedBundleIds.add(bundle.id);
                    totalDiscountAmount += discountValue;
                    validatedDiscountItems.push({
                        id: discountReq.id,
                        quantity: 1,
                        price: -discountValue,
                        isDiscount: true,
                        name_key: discountReq.name_key || 'bundle_discount_applied'
                    });
                }
            }

            const authoritativeTotal = Math.max(
                0,
                Number((authoritativeSubtotal - Math.min(authoritativeSubtotal, totalDiscountAmount)).toFixed(2))
            );

            let resolvedUserEmail = null;
            if (normalizedOrder.userEmail) {
                const existingUser = await db.get('SELECT email, balance FROM users WHERE email = ?', [
                    normalizedOrder.userEmail
                ]);
                if (existingUser) {
                    resolvedUserEmail = existingUser.email;

                    if (normalizedOrder.paymentMethod === 'wallet') {
                        const currentBalance = Number(existingUser.balance || 0);
                        if (currentBalance + 1e-9 < authoritativeTotal) {
                            throw new ClientError('Insufficient wallet balance.', {
                                reason: 'InsufficientBalance',
                                balance: Number(currentBalance.toFixed(2)),
                                required: authoritativeTotal
                            });
                        }

                        updatedWalletBalance = Number((currentBalance - authoritativeTotal).toFixed(2));
                        await db.run('UPDATE users SET balance = ? WHERE email = ?', [
                            updatedWalletBalance,
                            resolvedUserEmail
                        ]);
                        await db.run(
                            `INSERT INTO wallet_transactions (user_email, delta, balance_after, reason, actor, timestamp)
                             VALUES (?, ?, ?, ?, 'order', ?)`,
                            [
                                resolvedUserEmail,
                                -authoritativeTotal,
                                updatedWalletBalance,
                                `Order ${orderId}`,
                                timestamp
                            ]
                        );
                    }
                }
            }

            if (normalizedOrder.paymentMethod === 'wallet' && !resolvedUserEmail) {
                throw new ClientError('Wallet payment requires a signed-in student account.', {
                    reason: 'AuthRequiredForWallet'
                });
            }

            await db.run(
                `INSERT INTO orders (id, user_email, total_amount, status, payment_method, timestamp)
                 VALUES (?, ?, ?, ?, ?, ?)`,
                [
                    orderId,
                    resolvedUserEmail,
                    authoritativeTotal,
                    'pending',
                    normalizedOrder.paymentMethod,
                    timestamp
                ]
            );

            for (const item of regularItems) {
                const product = productMap.get(item.id);
                await db.run(
                    `INSERT INTO order_items (
                        order_id,
                        product_id,
                        quantity,
                        price_at_purchase,
                        is_discount,
                        name_key_at_purchase
                    ) VALUES (?, ?, ?, ?, 0, ?)`,
                    [
                        orderId,
                        item.id,
                        item.quantity,
                        Number(product.price),
                        product.name_key || item.name_key
                    ]
                );
            }

            for (const [prodId, totalOrderedQty] of itemQtyByProductId.entries()) {
                const product = productMap.get(prodId);
                if (product.quantity === 999) {
                    continue;
                }
                const currentQuantity = sanitizeInteger(product.quantity, { min: 0, max: 999999 });
                await db.run('UPDATE products SET quantity = ? WHERE id = ?', [
                    currentQuantity - totalOrderedQty,
                    prodId
                ]);
            }

            for (const discountItem of validatedDiscountItems) {
                await db.run(
                    `INSERT INTO order_items (
                        order_id,
                        product_id,
                        quantity,
                        price_at_purchase,
                        is_discount,
                        name_key_at_purchase
                    ) VALUES (?, ?, ?, ?, 1, ?)`,
                    [
                        orderId,
                        discountItem.id,
                        discountItem.quantity,
                        discountItem.price,
                        discountItem.name_key
                    ]
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

        if (fullOrder.user?.email && fullOrder.user.email !== 'Guest') {
            const myOrders = await getOrdersByUserEmail(fullOrder.user.email);
            sendToUser(fullOrder.user.email, 'my_orders', myOrders);
        }

        if (updatedWalletBalance !== null && fullOrder.user?.email) {
            sendToUser(fullOrder.user.email, 'wallet_balance_updated', {
                email: fullOrder.user.email,
                balance: updatedWalletBalance
            });
        }
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

    const totalRevenue = Number((totalRevenueRow?.total || 0).toFixed(2));
    const totalOrders = totalOrdersRow?.count || 0;
    const avgOrderValue = totalOrders > 0 ? Number((totalRevenue / totalOrders).toFixed(2)) : 0;

    const products = await db.query('SELECT id, name_key, image, quantity, price, category_key FROM products');
    const salesRows = await db.query(
        `SELECT oi.product_id, SUM(oi.quantity) AS sold, SUM(oi.quantity * oi.price_at_purchase) AS revenue
         FROM order_items oi
         JOIN orders o ON oi.order_id = o.id
         WHERE oi.is_discount = 0 AND strftime('%Y-%m', o.timestamp) = ?
         GROUP BY oi.product_id`,
        [yearMonthFilter]
    );

    const salesByProductId = {};
    const revenueByProductId = {};
    for (const row of salesRows) {
        salesByProductId[row.product_id] = row.sold;
        revenueByProductId[row.product_id] = Number((row.revenue || 0).toFixed(2));
    }

    const itemSalesRanking = products
        .filter((product) => product.category_key !== 'archive')
        .map((product) => ({
            id: product.id,
            name_key: product.name_key,
            image: product.image,
            quantity: product.quantity,
            price: product.price,
            count: salesByProductId[product.id] || 0,
            revenue: revenueByProductId[product.id] || 0
        }))
        .sort((a, b) => b.count - a.count);

    const lowStockProducts = products
        .filter((p) => p.category_key !== 'archive' && p.quantity !== 999 && p.quantity <= 5)
        .map((p) => ({
            id: p.id,
            name_key: p.name_key,
            image: p.image,
            quantity: p.quantity
        }))
        .sort((a, b) => a.quantity - b.quantity);

    const dailyRows = await db.query(
        `SELECT strftime('%d', timestamp) AS day, COUNT(*) AS count, SUM(total_amount) AS revenue
         FROM orders
         WHERE strftime('%Y-%m', timestamp) = ?
         GROUP BY day`,
        [yearMonthFilter]
    );

    const dailyOrders = {};
    const dailyRevenue = {};
    const daysInMonth = new Date(requestedYear, requestedMonth, 0).getDate();
    for (let day = 1; day <= daysInMonth; day += 1) {
        dailyOrders[day] = 0;
        dailyRevenue[day] = 0;
    }

    for (const row of dailyRows) {
        const day = Number.parseInt(row.day, 10);
        if (Number.isInteger(day) && dailyOrders[day] !== undefined) {
            dailyOrders[day] = row.count;
            dailyRevenue[day] = Number((row.revenue || 0).toFixed(2));
        }
    }

    const statusRows = await db.query(
        `SELECT status, COUNT(*) AS count FROM orders WHERE strftime('%Y-%m', timestamp) = ? GROUP BY status`,
        [yearMonthFilter]
    );
    const ordersByStatus = { pending: 0, preparing: 0, delivered: 0 };
    for (const row of statusRows) {
        if (row.status && ordersByStatus[row.status] !== undefined) {
            ordersByStatus[row.status] = row.count;
        }
    }

    const methodRows = await db.query(
        `SELECT payment_method, SUM(total_amount) AS total, COUNT(*) AS count
         FROM orders WHERE strftime('%Y-%m', timestamp) = ? GROUP BY payment_method`,
        [yearMonthFilter]
    );
    const revenueByPaymentMethod = {};
    for (const row of methodRows) {
        const key = row.payment_method || 'cash';
        revenueByPaymentMethod[key] = {
            revenue: Number((row.total || 0).toFixed(2)),
            orders: row.count || 0
        };
    }

    const availableYearsRows = await db.query(
        `SELECT DISTINCT strftime('%Y', timestamp) AS year FROM orders ORDER BY year DESC`
    );

    const availableYears = availableYearsRows
        .map((row) => Number.parseInt(row.year, 10))
        .filter((year) => Number.isInteger(year));
    if (!availableYears.includes(now.getFullYear())) {
        availableYears.unshift(now.getFullYear());
    }

    sendMessage(ws, 'analytics_data', {
        totalRevenue,
        totalOrders,
        avgOrderValue,
        itemSalesRanking,
        lowStockProducts,
        dailyOrders,
        dailyRevenue,
        ordersByStatus,
        revenueByPaymentMethod,
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

    const existingOrderMap = await getStoredProductOrderMap();
    const updatedOrderMap = { ...existingOrderMap };

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

            if (Array.isArray(payload[index]?.productIds)) {
                updatedOrderMap[categoryKey] = payload[index].productIds
                    .map((id) => sanitizeString(id, { maxLength: 128 }))
                    .filter(Boolean);
            }
        }

        await saveProductOrderMap(updatedOrderMap);
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

async function handleAdminBundleSaved(clientInfo, payload) {
    if (!clientInfo.isManagement || !payload || typeof payload !== 'object') {
        return;
    }

    const bundleRaw = payload.bundle || payload;
    const id = sanitizeString(bundleRaw.id, { maxLength: 128 });
    const nameKey = sanitizeString(bundleRaw.name_key, { maxLength: 256 }) || `bundle_name_${id}`;
    const descKey = sanitizeString(bundleRaw.description_key, { maxLength: 256 }) || `bundle_desc_${id}`;
    const rawItems = Array.isArray(bundleRaw.itemIds) ? bundleRaw.itemIds : [];
    const itemIds = rawItems.map((itemId) => sanitizeString(itemId, { maxLength: 128 })).filter(Boolean);
    const isSuggestion = Boolean(bundleRaw.isSuggestion);
    const discountPercent = isSuggestion
        ? 0
        : sanitizeNumber(bundleRaw.discountPercent, { min: 1, max: 90 }) ?? 15;
    const active = bundleRaw.active !== false;
    const displayOrder = sanitizeInteger(bundleRaw.displayOrder, { min: 0, max: 10000 }) ?? 0;

    if (!id || itemIds.length === 0) {
        return;
    }

    await db.run(
        `INSERT INTO bundles (id, name_key, description_key, item_ids_json, discount_percent, is_suggestion, active, display_order)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)
         ON CONFLICT(id) DO UPDATE SET
            name_key = excluded.name_key,
            description_key = excluded.description_key,
            item_ids_json = excluded.item_ids_json,
            discount_percent = excluded.discount_percent,
            is_suggestion = excluded.is_suggestion,
            active = excluded.active,
            display_order = excluded.display_order`,
        [id, nameKey, descKey, JSON.stringify(itemIds), discountPercent, isSuggestion ? 1 : 0, active ? 1 : 0, displayOrder]
    );

    if (payload.translations && typeof payload.translations === 'object') {
        await updateTranslations(payload.translations);
    }

    await broadcastFullData();
}

async function handleAdminBundleDeleted(clientInfo, payload) {
    if (!clientInfo.isManagement) {
        return;
    }

    const bundleId = sanitizeString(payload?.bundleId || payload?.id, { maxLength: 128 });
    if (!bundleId) {
        return;
    }

    await db.run('DELETE FROM bundles WHERE id = ?', [bundleId]);
    await broadcastFullData();
}

async function handleAdminPaymentMethodsUpdated(ws, clientInfo, payload) {
    if (!clientInfo.isManagement || !payload || typeof payload !== 'object') {
        return;
    }

    const nextMethods = {
        cash: payload.cash !== false,
        card: payload.card !== false,
        wallet: payload.wallet !== false
    };

    if (!nextMethods.cash && !nextMethods.card && !nextMethods.wallet) {
        sendMessage(ws, 'request_error', {
            message: 'At least one payment method must remain enabled.'
        });
        return;
    }

    await db.run(
        'INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)',
        [SETTINGS_KEY_PAYMENT_METHODS, JSON.stringify(nextMethods)]
    );

    broadcast('payment_methods_updated', nextMethods);
}

function formatWalletUserRow(u) {
    return {
        email: u.email,
        profilePic: u.profile_pic || 'pic2',
        balance: Number((u.balance || 0).toFixed(2)),
        createdAt: u.created_at,
        orderCount: u.order_count || 0,
        totalSpent: Number((u.total_spent || 0).toFixed(2))
    };
}

function formatWalletTxRow(tx) {
    return {
        id: tx.id,
        email: tx.user_email,
        delta: Number((tx.delta || 0).toFixed(2)),
        balanceAfter: Number((tx.balance_after || 0).toFixed(2)),
        reason: tx.reason || '',
        actor: tx.actor || 'admin',
        timestamp: tx.timestamp
    };
}

async function getRecentWalletTransactions(limit = 30) {
    const recentTransactions = await db.query(
        `SELECT id, user_email, delta, balance_after, reason, actor, timestamp
         FROM wallet_transactions
         ORDER BY id DESC
         LIMIT ?`,
        [limit]
    );
    return recentTransactions.map(formatWalletTxRow);
}

async function getWalletUserSummary(email) {
    const row = await db.get(
        `SELECT u.email, u.profile_pic, u.balance, u.created_at,
                COUNT(o.id) AS order_count,
                COALESCE(SUM(o.total_amount), 0) AS total_spent
         FROM users u
         LEFT JOIN orders o ON LOWER(o.user_email) = LOWER(u.email)
         WHERE u.email = ?
         GROUP BY u.email`,
        [email]
    );
    return row ? formatWalletUserRow(row) : null;
}

async function getAdminWalletsSnapshot(options = {}) {
    const rawQuery = typeof options.query === 'string' ? options.query.trim().slice(0, 120) : '';
    const hasLimit = options.limit !== undefined && options.limit !== null;
    const rawLimit = Number(options.limit);
    const limit = hasLimit && Number.isFinite(rawLimit)
        ? Math.min(Math.max(Math.trunc(rawLimit), 1), 50)
        : 5;
    const rawOffset = Number(options.offset);
    const offset = Number.isFinite(rawOffset) && rawOffset > 0 ? Math.trunc(rawOffset) : 0;

    const totalAccountsRow = await db.get('SELECT COUNT(*) AS count FROM users');
    const totalAccounts = Number(totalAccountsRow?.count || 0);

    let whereClause = '';
    const filterParams = [];
    if (rawQuery.length > 0) {
        const escapedQuery = rawQuery.toLowerCase().replace(/[\\%_]/g, '\\$&');
        whereClause = "WHERE LOWER(u.email) LIKE ? ESCAPE '\\'";
        filterParams.push(`%${escapedQuery}%`);
    }

    const filteredCountRow = whereClause
        ? await db.get(`SELECT COUNT(*) AS count FROM users u ${whereClause}`, filterParams)
        : totalAccountsRow;
    const totalUsers = Number(filteredCountRow?.count || 0);

    const safeOffset = offset >= totalUsers && totalUsers > 0
        ? Math.max(0, Math.floor((totalUsers - 1) / limit) * limit)
        : offset;

    const users = await db.query(
        `SELECT u.email, u.profile_pic, u.balance, u.created_at,
                COUNT(o.id) AS order_count,
                COALESCE(SUM(o.total_amount), 0) AS total_spent
         FROM users u
         LEFT JOIN orders o ON LOWER(o.user_email) = LOWER(u.email)
         ${whereClause}
         GROUP BY u.email
         ORDER BY u.created_at DESC, u.email ASC
         LIMIT ? OFFSET ?`,
        [...filterParams, limit, safeOffset]
    );

    const recentTransactions = await getRecentWalletTransactions(30);

    return {
        users: users.map(formatWalletUserRow),
        totalUsers,
        totalAccounts,
        limit,
        offset: safeOffset,
        hasMore: safeOffset + users.length < totalUsers,
        query: rawQuery,
        isBroadcastRefresh: options.isBroadcastRefresh === true,
        recentTransactions
    };
}

async function handleAdminGetUsersWallets(ws, clientInfo, payload) {
    if (!clientInfo.isManagement) {
        return;
    }

    const snapshot = await getAdminWalletsSnapshot({
        query: payload && typeof payload === 'object' ? payload.query : '',
        limit: payload && typeof payload === 'object' && payload.limit !== undefined ? payload.limit : 5,
        offset: payload && typeof payload === 'object' ? payload.offset : 0
    });
    sendMessage(ws, 'admin_wallets_data', snapshot);
}

async function handleAdminAdjustWallet(ws, clientInfo, payload) {
    if (!clientInfo.isManagement) {
        return;
    }

    const email = sanitizeEmail(payload?.email);
    const mode = sanitizeString(payload?.mode, { maxLength: 16 }) || 'add';
    const amount = sanitizeNumber(payload?.amount, { min: 0, max: 1_000_000 });
    const reason = sanitizeOptionalString(payload?.reason, { maxLength: 200 }) || `Admin ${mode}`;

    if (!email || amount === null || !['add', 'deduct', 'set'].includes(mode)) {
        sendMessage(ws, 'request_error', { message: 'Invalid wallet adjustment parameters.' });
        return;
    }

    let nextBalance = 0;

    try {
        await db.withTransaction(async () => {
            const user = await db.get('SELECT email, balance FROM users WHERE email = ?', [email]);
            if (!user) {
                throw new ClientError('Student account not found.', { reason: 'UserNotFound' });
            }

            const prevBalance = Number(user.balance || 0);
            if (mode === 'add') {
                nextBalance = Number((prevBalance + amount).toFixed(2));
            } else if (mode === 'deduct') {
                nextBalance = Math.max(0, Number((prevBalance - amount).toFixed(2)));
            } else {
                nextBalance = Number(amount.toFixed(2));
            }

            const delta = Number((nextBalance - prevBalance).toFixed(2));
            await db.run('UPDATE users SET balance = ? WHERE email = ?', [nextBalance, email]);
            await db.run(
                `INSERT INTO wallet_transactions (user_email, delta, balance_after, reason, actor, timestamp)
                 VALUES (?, ?, ?, ?, 'admin', ?)`,
                [email, delta, nextBalance, reason, new Date().toISOString()]
            );
        });
    } catch (err) {
        if (err instanceof ClientError) {
            sendMessage(ws, 'request_error', { message: err.message, ...err.payload });
            return;
        }
        throw err;
    }

    const [updatedUser, recentTransactions, snapshot] = await Promise.all([
        getWalletUserSummary(email),
        getRecentWalletTransactions(30),
        getAdminWalletsSnapshot({ limit: 5, offset: 0, isBroadcastRefresh: true })
    ]);
    if (updatedUser) {
        broadcastToManagement('admin_wallet_entry_updated', {
            user: updatedUser,
            recentTransactions
        });
    }
    broadcastToManagement('admin_wallets_data', snapshot);
    sendToUser(email, 'wallet_balance_updated', {
        email,
        balance: nextBalance
    });
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
    const importedProductOrderMap = {};

    for (let index = 0; index < rawCategories.length; index += 1) {
        const category = normalizeCategoryPayload(rawCategories[index], index);
        if (!category || categoryKeySet.has(category.key)) {
            continue;
        }

        categoryKeySet.add(category.key);
        categories.push(category);

        const rawProductIds = Array.isArray(rawCategories[index]?.productIds)
            ? rawCategories[index].productIds
            : [];
        importedProductOrderMap[category.key] = rawProductIds;
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

        await saveProductOrderMap(normalizeProductOrderMap(importedProductOrderMap, categoryKeySet));

        if (payload.productRelatedTranslations && typeof payload.productRelatedTranslations === 'object') {
            await updateTranslations(payload.productRelatedTranslations);
        }

        if (payload.currency && typeof payload.currency === 'object' && !Array.isArray(payload.currency)) {
            await updateTranslations({ currency_symbol: payload.currency });
        }
    });

    await broadcastFullData();
}

const messageHandlers = {
    request_initial_data: async ({ ws }) => handleRequestInitialData(ws),
    authenticate_session: async ({ ws, clientInfo, payload }) => handleAuthenticateSession(ws, clientInfo, payload),
    identify_management: async ({ ws, clientInfo, payload }) => handleIdentifyManagement(ws, clientInfo, payload),
    get_orders: async ({ ws, clientInfo }) => handleGetOrders(ws, clientInfo),
    get_my_orders: async ({ ws, clientInfo, payload }) => handleGetMyOrders(ws, clientInfo, payload),
    update_order_status: async ({ clientInfo, payload }) => handleUpdateOrderStatus(clientInfo, payload),
    register_user: async ({ ws, clientInfo, payload }) => handleRegisterUser(ws, clientInfo, payload),
    login_user: async ({ ws, clientInfo, payload }) => handleLoginUser(ws, clientInfo, payload),
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
    admin_config_imported: async ({ clientInfo, payload }) => handleAdminConfigImported(clientInfo, payload),
    admin_bundle_saved: async ({ clientInfo, payload }) => handleAdminBundleSaved(clientInfo, payload),
    admin_bundle_deleted: async ({ clientInfo, payload }) => handleAdminBundleDeleted(clientInfo, payload),
    admin_payment_methods_updated: async ({ ws, clientInfo, payload }) =>
        handleAdminPaymentMethodsUpdated(ws, clientInfo, payload),
    admin_get_users_wallets: async ({ ws, clientInfo, payload }) =>
        handleAdminGetUsersWallets(ws, clientInfo, payload),
    admin_adjust_wallet: async ({ ws, clientInfo, payload }) => handleAdminAdjustWallet(ws, clientInfo, payload)
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
        pushService.init();

        server.listen(PORT, HOST, () => {
            const localIp = getLocalIpAddress();
            const separator = '===================================================';
            const modeLabel =
                WEB_MODE === 'flutter'
                    ? 'Flutter Web (Wasm / COOP+COEP enabled)'
                    : WEB_MODE === 'old-web'
                      ? 'Legacy HTML/JS Web (old-web)'
                      : 'Backend Only (WebSocket + REST API)';

            console.log(`\n${separator}`);
            console.log('EVA Canteen Server Running (SQLite)');
            console.log(separator);
            console.log(`\nMode:             ${modeLabel}`);
            console.log(`Bind:             ${HOST}:${PORT}`);
            console.log(`Local:            http://localhost:${PORT}`);
            console.log(`On Your Network:  http://${localIp}:${PORT}`);
            console.log(`\n${separator}\n`);
        });
    } catch (err) {
        console.error('Failed to initialize database or start server:', err);
        process.exit(1);
    }
}

start();

let isShuttingDown = false;

function shutdown(signal) {
    if (isShuttingDown) {
        return;
    }
    isShuttingDown = true;
    console.log(`Received ${signal}, shutting down...`);
    clearInterval(heartbeatInterval);

    for (const client of wss.clients) {
        try {
            client.close(1001, 'Server restarting');
        } catch {
            client.terminate();
        }
    }

    wss.close(() => {
        server.close(async () => {
            try {
                await db.close();
            } catch (err) {
                console.error('Failed to close database cleanly:', err);
            } finally {
                process.exit(0);
            }
        });
        server.closeAllConnections?.();
    });

    setTimeout(() => process.exit(1), 10_000).unref();
}

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));
