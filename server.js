// تم إزالة Express server لأننا نستخدم Python HTTP server بدلاً منه
/**
 * EVA Canteen - WebSocket Server
 * Copyright (C) 2025 EVA International School
 */

const WebSocket = require('ws');
const path = require('path');
const bcrypt = require('bcrypt');
const express = require('express');
const http = require('http');
const os = require('os');
const db = require('./database'); // Import database module

const app = express();
const server = http.createServer(app);

// Serve static files
app.use(express.static(path.join(__dirname, '')));

// --- START: Admin Login Rate Limiting Variables ---
const failedAdminLoginAttempts = new Map();
const MAX_ADMIN_FAILED_ATTEMPTS = 5;
const ADMIN_LOCKOUT_DURATION_MS = 5 * 60 * 1000;
// --- END: Admin Login Rate Limiting Variables ---

// Attach WebSocket server
const wss = new WebSocket.Server({ server });

const PORT = process.env.PORT || 8080;

// Initialize Database before starting server
db.initDatabase().then(() => {
    console.log('Database initialized successfully.');
    server.listen(PORT, () => {
        const localIp = getLocalIpAddress();
        const separator = '===================================================';
        console.log('\n' + separator);
        console.log(`🚀  EVA Canteen Server Running (SQLite)!`);
        console.log(separator);
        console.log(`\n📍  Local:            http://localhost:${PORT}`);
        console.log(`🌐  On Your Network:  http://${localIp}:${PORT}`);
        console.log('\n' + separator + '\n');
    });
}).catch(err => {
    console.error('Failed to initialize database:', err);
    process.exit(1);
});

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

const clients = new Map();

wss.on('connection', async (ws, req) => {
    console.log('Client connected');
    let ip = 'unknown';
    try {
        ip = req.headers['x-forwarded-for']?.split(',').shift()?.trim() || req.socket.remoteAddress;
        if (ip === '::1') ip = '127.0.0.1';
        console.log(`👤 Client connected from IP: ${ip}`);
    } catch (e) { console.error("Error getting client IP:", e); }

    const clientInfo = { isManagement: false, ip: ip };
    clients.set(ws, clientInfo);

    try {
        // --- Fetch Initial Data from DB ---
        const translationsRows = await db.query('SELECT * FROM translations');
        const translations = {};
        translationsRows.forEach(row => translations[row.key] = { en: row.en, ar: row.ar });

        const canteenStatusRow = await db.get("SELECT value FROM settings WHERE key = 'canteen_open'");
        const canteenStatus = { isOpen: canteenStatusRow ? canteenStatusRow.value === 'true' : true }; // Default to true if missing

        const categoriesRows = await db.query('SELECT * FROM categories ORDER BY display_order');

        // Construct categories array with productIds (needed for frontend logic currently)
        // We'll fetch all products first
        const productsRows = await db.query('SELECT * FROM products');

        const categories = categoriesRows.map(cat => {
            const catProducts = productsRows.filter(p => p.category_key === cat.key).map(p => p.id);
            return {
                key: cat.key,
                name_key: cat.name_key,
                productIds: catProducts
            };
        });

        const products = productsRows.map(p => ({
            id: p.id,
            name_key: p.name_key,
            description_key: p.description_key,
            price: p.price,
            quantity: p.quantity,
            image: p.image,
            category: p.category_key
        }));

        // Send Initial Data
        ws.send(JSON.stringify({ type: 'initial_translations', payload: translations }));
        ws.send(JSON.stringify({ type: 'initial_canteen_status', payload: canteenStatus }));
        ws.send(JSON.stringify({ type: 'initial_products', payload: products }));
        ws.send(JSON.stringify({ type: 'initial_categories', payload: categories }));

    } catch (err) {
        console.error("Error sending initial data:", err);
    }

    ws.on('message', async (message) => {
        let parsedMessage;
        try {
            parsedMessage = JSON.parse(message);
            const clientInfo = clients.get(ws);
            if (!clientInfo) { ws.terminate(); return; }

            switch (parsedMessage.type) {
                case 'request_initial_data':
                    // Fetch fresh status to decide
                    const statusRow = await db.get("SELECT value FROM settings WHERE key = 'canteen_open'");
                    const isOpen = statusRow ? statusRow.value === 'true' : true;

                    if (isOpen) {
                        // Re-fetch products/categories (simplified: reusing logic could be better)
                        const productsRows = await db.query('SELECT * FROM products');
                        const categoriesRows = await db.query('SELECT * FROM categories ORDER BY display_order');
                        const categories = categoriesRows.map(cat => ({
                            key: cat.key, name_key: cat.name_key,
                            productIds: productsRows.filter(p => p.category_key === cat.key).map(p => p.id)
                        }));
                        const products = productsRows.map(p => ({
                            id: p.id, name_key: p.name_key, description_key: p.description_key, price: p.price,
                            quantity: p.quantity, image: p.image, category: p.category_key
                        }));

                        ws.send(JSON.stringify({ type: 'initial_products', payload: products }));
                        ws.send(JSON.stringify({ type: 'initial_categories', payload: categories }));
                    }
                    break;

                case 'identify_management':
                    console.log('Management client identified');
                    clientInfo.isManagement = true;
                    clients.set(ws, clientInfo);

                    // Send Orders
                    const allOrders = await getAllOrders();
                    ws.send(JSON.stringify({ type: 'initial_orders', payload: allOrders }));

                    // Send Products/Categories (Regardless of status)
                    const pRows = await db.query('SELECT * FROM products');
                    const cRows = await db.query('SELECT * FROM categories ORDER BY display_order');
                    const cats = cRows.map(cat => ({
                        key: cat.key, name_key: cat.name_key,
                        productIds: pRows.filter(p => p.category_key === cat.key).map(p => p.id)
                    }));
                    const prods = pRows.map(p => ({
                        id: p.id, name_key: p.name_key, description_key: p.description_key, price: p.price,
                        quantity: p.quantity, image: p.image, category: p.category_key
                    }));

                    ws.send(JSON.stringify({ type: 'initial_products', payload: prods }));
                    ws.send(JSON.stringify({ type: 'initial_categories', payload: cats }));
                    break;

                case 'update_order_status':
                    if (!clientInfo.isManagement) break;
                    const { orderId, newStatus } = parsedMessage.payload;
                    await db.run('UPDATE orders SET status = ? WHERE id = ?', [newStatus, orderId]);
                    console.log(`Order ${orderId} updated to ${newStatus}`);

                    // Fetch full updated order to broadcast
                    const updatedOrder = await getOrderById(orderId);
                    broadcastToManagement(JSON.stringify({
                        type: 'order_status_updated_broadcast',
                        payload: { orderId, newStatus, updatedOrder }
                    }));
                    break;

                case 'register_user':
                    const { email: rEmail, password: rPass, profilePic: rPic } = parsedMessage.payload;
                    if (!rEmail || !rPass) {
                        ws.send(JSON.stringify({ type: 'register_error', payload: { message: 'Missing details.' } }));
                        break;
                    }
                    const exists = await db.get('SELECT email FROM users WHERE email = ?', [rEmail]);
                    if (exists) {
                        ws.send(JSON.stringify({ type: 'register_error', payload: { message: 'Email already registered.' } }));
                        break;
                    }
                    const hash = await bcrypt.hash(rPass, 10);
                    const safePic = ["pic1", "pic2", "pic3"].includes(rPic) ? rPic : "pic2";
                    await db.run('INSERT INTO users (email, password_hash, profile_pic) VALUES (?, ?, ?)', [rEmail, hash, safePic]);
                    ws.send(JSON.stringify({ type: 'register_success', payload: { email: rEmail, profilePic: safePic } }));
                    break;

                case 'login_user':
                    const { email: lEmail, password: lPass } = parsedMessage.payload;
                    const user = await db.get('SELECT * FROM users WHERE email = ?', [lEmail]);
                    if (!user) {
                        ws.send(JSON.stringify({ type: 'login_error', payload: { message: 'Invalid credentials.' } }));
                        break;
                    }
                    const match = await bcrypt.compare(lPass, user.password_hash);
                    if (match) {
                        ws.send(JSON.stringify({ type: 'login_success', payload: { email: user.email, profilePic: user.profile_pic } }));
                    } else {
                        ws.send(JSON.stringify({ type: 'login_error', payload: { message: 'Invalid credentials.' } }));
                    }
                    break;

                case 'admin_login':
                    const { email: aEmail, password: aPass } = parsedMessage.payload;
                    // ... (Rate limiting logic can remain similar using map) ...

                    const SERVER_ADMIN_EMAIL = process.env.ADMIN_EMAIL || "admin@canteen.app";
                    const SERVER_ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || "admin123";

                    if (aEmail === SERVER_ADMIN_EMAIL && aPass === SERVER_ADMIN_PASSWORD) {
                        clientInfo.isManagement = true;
                        clients.set(ws, clientInfo);
                        ws.send(JSON.stringify({ type: 'admin_login_success', payload: { message: 'Success' } }));
                    } else {
                        ws.send(JSON.stringify({ type: 'admin_login_error', payload: { message: 'Invalid credentials' } }));
                    }
                    break;

                case 'place_order':
                    // Verify Status
                    const sRow = await db.get("SELECT value FROM settings WHERE key = 'canteen_open'");
                    const isCanteenOpen = sRow ? sRow.value === 'true' : true;
                    if (!isCanteenOpen && !clientInfo.isManagement) {
                        ws.send(JSON.stringify({ type: 'order_rejected', payload: { reason: 'Closed' } }));
                        break;
                    }

                    const newOrder = parsedMessage.payload;
                    const serverId = await generateOrderIdOnServer();
                    const now = new Date().toISOString();

                    // Insert Order
                    await db.run(
                        `INSERT INTO orders (id, user_email, total_amount, status, payment_method, timestamp) VALUES (?, ?, ?, ?, ?, ?)`,
                        [serverId, newOrder.user?.email, newOrder.totalAmount, 'pending', newOrder.paymentMethod, now]
                    );

                    // Insert Items & Update Stock
                    if (newOrder.items) {
                        for (const item of newOrder.items) {
                            await db.run(
                                `INSERT INTO order_items (order_id, product_id, quantity, price_at_purchase, is_discount, name_key_at_purchase) VALUES (?, ?, ?, ?, ?, ?)`,
                                [serverId, item.id, item.quantity, item.price, item.isDiscount ? 1 : 0, item.name_key]
                            );

                            if (!item.isDiscount) {
                                // Update Stock
                                const product = await db.get('SELECT quantity FROM products WHERE id = ?', [item.id]);
                                if (product && product.quantity !== 999) {
                                    const newQty = Math.max(0, product.quantity - item.quantity);
                                    await db.run('UPDATE products SET quantity = ? WHERE id = ?', [newQty, item.id]);
                                }
                            }
                        }
                    }

                    // Construct full order object to return
                    const fullOrder = await getOrderById(serverId);

                    // Broadcasts
                    broadcastToManagement(JSON.stringify({ type: 'new_order', payload: fullOrder }));

                    // Broadcast product update (since stock changed)
                    const updatedProducts = await getAllProducts();
                    broadcast(JSON.stringify({ type: 'products_updated', payload: updatedProducts }));

                    ws.send(JSON.stringify({ type: 'order_confirmed_by_server', payload: fullOrder }));
                    break;

                case 'get_analytics_data':
                    if (!clientInfo.isManagement) break;

                    // 1. Revenue
                    const revRow = await db.get('SELECT SUM(total_amount) as total FROM orders');
                    const totalRevenue = revRow.total || 0;

                    // 2. Total Orders
                    const countRow = await db.get('SELECT COUNT(*) as count FROM orders');
                    const totalOrders = countRow.count || 0;

                    // 3. Avg Value
                    const avgOrderValue = totalOrders > 0 ? totalRevenue / totalOrders : 0;

                    // 4. Product Sales (Top/Least)
                    // We need all products first to include those with 0 sales
                    const allProds = await db.query('SELECT id, name_key, image FROM products');

                    // Get sales counts
                    const salesRows = await db.query(`
                        SELECT product_id, SUM(quantity) as sold
                        FROM order_items
                        WHERE is_discount = 0
                        GROUP BY product_id
                    `);

                    const salesMap = {};
                    salesRows.forEach(r => salesMap[r.product_id] = r.sold);

                    const productStats = allProds.map(p => ({
                        id: p.id,
                        name_key: p.name_key,
                        image: p.image,
                        count: salesMap[p.id] || 0
                    }));

                    const topSellingItems = [...productStats].sort((a, b) => b.count - a.count).slice(0, 5);
                    const leastSellingItems = [...productStats].sort((a, b) => a.count - b.count).slice(0, 5);

                    // 5. Daily Orders
                    const nowDaily = new Date();
                    const monthStr = String(nowDaily.getMonth() + 1).padStart(2, '0');
                    const yearStr = nowDaily.getFullYear();
                    // SQLite strftime('%m', timestamp) ...

                    const dailyRows = await db.query(`
                        SELECT strftime('%d', timestamp) as day, COUNT(*) as count
                        FROM orders
                        WHERE strftime('%Y-%m', timestamp) = ?
                        GROUP BY day
                    `, [`${yearStr}-${monthStr}`]);

                    const dailyOrders = {};
                    const daysInMonth = new Date(yearStr, nowDaily.getMonth() + 1, 0).getDate();
                    for(let d=1; d<=daysInMonth; d++) dailyOrders[d] = 0;
                    dailyRows.forEach(r => dailyOrders[parseInt(r.day)] = r.count);

                    ws.send(JSON.stringify({ type: 'analytics_data', payload: {
                        totalRevenue, totalOrders, avgOrderValue, topSellingItems, leastSellingItems, dailyOrders
                    }}));
                    break;

                case 'verify_discovery_passcode':
                    const SERVER_DISCOVERY_PASSPHRASE = process.env.DISCOVERY_PASSPHRASE || "12345";
                    if (parsedMessage.payload.passcode === SERVER_DISCOVERY_PASSPHRASE) {
                        ws.send(JSON.stringify({ type: 'discovery_passcode_success' }));
                    } else {
                        ws.send(JSON.stringify({ type: 'discovery_passcode_error' }));
                    }
                    break;

                // --- Admin CRUD Handlers (Simplified) ---
                case 'admin_product_added':
                    if(!clientInfo.isManagement) break;
                    const { product, categoryKey, translations: newTrans } = parsedMessage.payload;

                    await db.run(
                        `INSERT INTO products (id, name_key, description_key, price, quantity, image, category_key) VALUES (?, ?, ?, ?, ?, ?, ?)`,
                        [product.id, product.name_key, product.description_key, product.price, product.quantity, product.image, categoryKey]
                    );

                    if(newTrans) await updateTranslations(newTrans);

                    await broadcastFullData();
                    break;

                case 'admin_product_updated':
                    if(!clientInfo.isManagement) break;
                    const { productId, updatedFields } = parsedMessage.payload;

                    await db.run(
                        `UPDATE products SET price=?, quantity=?, image=?, category_key=? WHERE id=?`,
                        [updatedFields.price, updatedFields.quantity, updatedFields.image, updatedFields.category, productId]
                    );

                    // Handle translation updates
                    const updates = {};
                    if(updatedFields.name_key) updates[updatedFields.name_key] = {en: updatedFields.name_en, ar: updatedFields.name_ar};
                    if(updatedFields.description_key) updates[updatedFields.description_key] = {en: updatedFields.description_en, ar: updatedFields.description_ar};
                    if(Object.keys(updates).length > 0) await updateTranslations(updates);

                    await broadcastFullData();
                    break;

                case 'admin_product_removed':
                    if(!clientInfo.isManagement) break;
                    await db.run('DELETE FROM products WHERE id = ?', [parsedMessage.payload.productId]);
                    await broadcastFullData();
                    break;

                case 'admin_category_added':
                    if(!clientInfo.isManagement) break;
                    const { category: cat, translations: catTrans } = parsedMessage.payload;

                    // Get next order
                    const maxOrderRow = await db.get('SELECT MAX(display_order) as max FROM categories');
                    const nextOrder = (maxOrderRow.max || 0) + 1;

                    await db.run(
                        `INSERT INTO categories (key, name_key, display_order) VALUES (?, ?, ?)`,
                        [cat.key, cat.name_key, nextOrder]
                    );
                    if(catTrans) await updateTranslations(catTrans);
                    await broadcastFullData();
                    break;

                case 'admin_category_deleted':
                    if(!clientInfo.isManagement) break;
                    // Check if empty
                    const countP = await db.get('SELECT COUNT(*) as c FROM products WHERE category_key = ?', [parsedMessage.payload.categoryKey]);
                    if (countP.c > 0) break; // Reject

                    await db.run('DELETE FROM categories WHERE key = ?', [parsedMessage.payload.categoryKey]);
                    await broadcastFullData();
                    break;

                case 'admin_set_canteen_status':
                    if(!clientInfo.isManagement) break;
                    const newStatusIsOpen = parsedMessage.payload.isOpen;
                    await db.run(`INSERT OR REPLACE INTO settings (key, value) VALUES ('canteen_open', ?)`, [newStatusIsOpen ? 'true' : 'false']);
                    broadcast(JSON.stringify({ type: 'canteen_status_updated', payload: { isOpen: newStatusIsOpen } }));
                    break;

                case 'admin_categories_reordered':
                    if(!clientInfo.isManagement) break;
                    const reorderedCats = parsedMessage.payload;
                    // reorderedCats is array of { key, ... } in desired order
                    for (let i = 0; i < reorderedCats.length; i++) {
                        await db.run('UPDATE categories SET display_order = ? WHERE key = ?', [i, reorderedCats[i].key]);
                    }
                    await broadcastFullData();
                    break;

                case 'admin_currency_updated':
                    if(!clientInfo.isManagement) break;
                    const curr = parsedMessage.payload.currency;
                    await updateTranslations({ 'currency_symbol': curr });
                    await broadcastFullData();
                    break;
            }
        } catch (e) {
            console.error("Error processing message:", e);
        }
    });

    ws.on('close', () => clients.delete(ws));
});

// --- Helpers ---

async function generateOrderIdOnServer() {
    const now = new Date();
    const day = String(now.getDate()).padStart(2, '0');
    const month = String(now.getMonth() + 1).padStart(2, '0');

    // Get max sequence for today
    const rows = await db.query(`SELECT id FROM orders WHERE strftime('%Y-%m-%d', timestamp) = ?`, [now.toISOString().split('T')[0]]);

    let maxSeq = 0;
    rows.forEach(r => {
        const parts = r.id.split('-');
        if (parts.length === 4) {
            const seq = parseInt(parts[1]);
            if (!isNaN(seq) && seq > maxSeq) maxSeq = seq;
        }
    });

    return `ORD-${maxSeq + 1}-${day}-${month}`;
}

async function getAllOrders() {
    const orders = await db.query('SELECT * FROM orders ORDER BY timestamp DESC');
    const items = await db.query('SELECT * FROM order_items');

    // Group items by order
    const itemsMap = {};
    items.forEach(item => {
        if (!itemsMap[item.order_id]) itemsMap[item.order_id] = [];
        itemsMap[item.order_id].push({
            id: item.product_id,
            quantity: item.quantity,
            price: item.price_at_purchase,
            isDiscount: !!item.is_discount,
            name_key: item.name_key_at_purchase
        });
    });

    // Merge
    return await Promise.all(orders.map(async o => {
        const user = o.user_email ? await db.get('SELECT email, profile_pic FROM users WHERE email=?', [o.user_email]) : null;
        return {
            id: o.id,
            totalAmount: o.total_amount,
            status: o.status,
            paymentMethod: o.payment_method,
            timestamp: new Date(o.timestamp), // Convert back to Date object
            items: itemsMap[o.id] || [],
            user: user ? { email: user.email, profilePic: user.profile_pic } : { email: 'Guest', profilePic: 'pic2' }
        };
    }));
}

async function getOrderById(id) {
    const o = await db.get('SELECT * FROM orders WHERE id = ?', [id]);
    if (!o) return null;
    const items = await db.query('SELECT * FROM order_items WHERE order_id = ?', [id]);
    const user = o.user_email ? await db.get('SELECT email, profile_pic FROM users WHERE email=?', [o.user_email]) : null;

    return {
        id: o.id,
        totalAmount: o.total_amount,
        status: o.status,
        paymentMethod: o.payment_method,
        timestamp: new Date(o.timestamp),
        items: items.map(i => ({
            id: i.product_id,
            quantity: i.quantity,
            price: i.price_at_purchase,
            isDiscount: !!i.is_discount,
            name_key: i.name_key_at_purchase
        })),
        user: user ? { email: user.email, profilePic: user.profile_pic } : { email: 'Guest', profilePic: 'pic2' }
    };
}

async function getAllProducts() {
    const rows = await db.query('SELECT * FROM products');
    return rows.map(p => ({
        id: p.id, name_key: p.name_key, description_key: p.description_key, price: p.price,
        quantity: p.quantity, image: p.image, category: p.category_key
    }));
}

async function updateTranslations(newTrans) {
    for (const [key, val] of Object.entries(newTrans)) {
        await db.run('INSERT OR REPLACE INTO translations (key, en, ar) VALUES (?, ?, ?)', [key, val.en, val.ar]);
    }
}

// Helper to broadcast everything updated (Products, Cats, Translations)
async function broadcastFullData() {
    const products = await getAllProducts();
    const cRows = await db.query('SELECT * FROM categories ORDER BY display_order');
    const categories = cRows.map(cat => ({
        key: cat.key, name_key: cat.name_key,
        productIds: products.filter(p => p.category === cat.key).map(p => p.id)
    }));

    const tRows = await db.query('SELECT * FROM translations');
    const translations = {};
    tRows.forEach(r => translations[r.key] = {en: r.en, ar: r.ar});

    broadcast(JSON.stringify({ type: 'products_updated', payload: products }));
    broadcast(JSON.stringify({ type: 'categories_updated', payload: categories }));
    broadcast(JSON.stringify({ type: 'translations_updated', payload: translations }));
}

function broadcast(message, excludeWs = null) {
    wss.clients.forEach(client => {
        if (client.readyState === WebSocket.OPEN && client !== excludeWs) {
            client.send(message);
        }
    });
}

function broadcastToManagement(message) {
    clients.forEach((info, ws) => {
        if (info.isManagement && ws.readyState === WebSocket.OPEN) {
            ws.send(message);
        }
    });
}
