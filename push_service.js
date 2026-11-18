/**
 * EVA Canteen - Push Notification Service (FCM HTTP v1 via firebase-admin)
 * Copyright (C) 2025 EVA International School
 */

const fs = require('fs');

const ANDROID_ORDER_READY_CHANNEL_ID = 'eva_order_ready_v1';
const MAX_MULTICAST_TOKENS = 500;
const INVALID_TOKEN_ERROR_CODES = new Set([
    'messaging/registration-token-not-registered',
    'messaging/invalid-registration-token'
]);

function extractPickupNumber(orderId) {
    const raw = typeof orderId === 'string' ? orderId.trim() : '';
    const match = /^ORD-(\d+)-/.exec(raw);
    if (match) {
        return `#${match[1]}`;
    }
    return raw || '#';
}

function normalizePushLocale(rawLocale) {
    if (typeof rawLocale === 'string' && rawLocale.trim().toLowerCase().startsWith('ar')) {
        return 'ar';
    }
    return 'en';
}

function buildOrderReadyLocalizedCopy(locale, pickupNumber) {
    if (normalizePushLocale(locale) === 'ar') {
        return {
            title: `طلبك رقم ${pickupNumber} جاهز للاستلام!`,
            body: 'طلبك جاهز الآن عند كاونتر كانتين إيفا.'
        };
    }

    return {
        title: `Order ${pickupNumber} is ready!`,
        body: 'Your order is ready for pickup at the EVA Canteen counter.'
    };
}

function resolvePublicAppOrigin(rawUrl) {
    if (typeof rawUrl !== 'string' || !rawUrl.trim()) {
        return null;
    }
    try {
        const parsed = new URL(rawUrl.trim());
        if (parsed.protocol !== 'https:' || !parsed.host) {
            return null;
        }
        return parsed.origin;
    } catch {
        return null;
    }
}

function buildOrderReadyMulticastMessage({
    order,
    tokens,
    locale,
    sentAt = new Date().toISOString(),
    publicAppUrl = null
}) {
    const orderId = String(order.id);
    const pickupNumber = extractPickupNumber(orderId);
    const normalizedLocale = normalizePushLocale(locale);
    const copy = buildOrderReadyLocalizedCopy(normalizedLocale, pickupNumber);
    const appOrigin = resolvePublicAppOrigin(publicAppUrl);

    const webpush = {
        headers: {
            Urgency: 'high',
            TTL: '3600'
        },
        notification: {
            tag: orderId,
            renotify: true,
            icon: '/icons/Icon-192.png'
        }
    };
    if (appOrigin) {
        webpush.fcmOptions = {
            link: `${appOrigin}/orders?orderId=${encodeURIComponent(orderId)}`
        };
    }

    return {
        tokens,
        notification: {
            title: copy.title,
            body: copy.body
        },
        data: {
            type: 'order_ready',
            orderId,
            pickupNumber,
            status: 'delivered',
            route: '/orders',
            sentAt
        },
        android: {
            priority: 'high',
            ttl: 3600 * 1000,
            notification: {
                channelId: ANDROID_ORDER_READY_CHANNEL_ID,
                tag: orderId,
                sound: 'default',
                defaultVibrateTimings: true,
                clickAction: 'FLUTTER_NOTIFICATION_CLICK'
            }
        },
        apns: {
            headers: {
                'apns-priority': '10',
                'apns-collapse-id': orderId
            },
            payload: {
                aps: {
                    sound: 'default'
                }
            }
        },
        webpush
    };
}

function resolveServiceAccountConfig(env = process.env) {
    const b64 = typeof env.FIREBASE_SERVICE_ACCOUNT_B64 === 'string'
        ? env.FIREBASE_SERVICE_ACCOUNT_B64.trim()
        : '';
    if (b64) {
        const decoded = Buffer.from(b64, 'base64').toString('utf8');
        return JSON.parse(decoded);
    }

    const rawJson = typeof env.FIREBASE_SERVICE_ACCOUNT_JSON === 'string'
        ? env.FIREBASE_SERVICE_ACCOUNT_JSON.trim()
        : '';
    if (rawJson) {
        return JSON.parse(rawJson);
    }

    const credPath = typeof env.GOOGLE_APPLICATION_CREDENTIALS === 'string'
        ? env.GOOGLE_APPLICATION_CREDENTIALS.trim()
        : '';
    if (credPath && fs.existsSync(credPath)) {
        return JSON.parse(fs.readFileSync(credPath, 'utf8'));
    }

    return null;
}

function chunkArray(items, chunkSize) {
    const chunks = [];
    for (let i = 0; i < items.length; i += chunkSize) {
        chunks.push(items.slice(i, i + chunkSize));
    }
    return chunks;
}

function createPushService({ db, messaging = null, logger = console, env = process.env }) {
    let messagingClient = messaging;
    let initialized = Boolean(messaging);

    function init() {
        if (initialized) {
            return Boolean(messagingClient);
        }
        initialized = true;

        let serviceAccount = null;
        try {
            serviceAccount = resolveServiceAccountConfig(env);
        } catch (err) {
            logger.error('Failed to parse Firebase service account credentials; push notifications disabled:', err.message);
            return false;
        }

        if (!serviceAccount) {
            logger.log(
                'Push notifications disabled (set FIREBASE_SERVICE_ACCOUNT_B64 or FIREBASE_SERVICE_ACCOUNT_JSON to enable FCM).'
            );
            return false;
        }

        try {
            const { cert, getApps, initializeApp } = require('firebase-admin/app');
            const { getMessaging } = require('firebase-admin/messaging');

            const app = getApps().length > 0
                ? getApps()[0]
                : initializeApp({ credential: cert(serviceAccount) });

            messagingClient = getMessaging(app);
            logger.log('Push notifications enabled (Firebase Cloud Messaging HTTP v1).');
            return true;
        } catch (err) {
            logger.error('Failed to initialize firebase-admin; push notifications disabled:', err.message);
            messagingClient = null;
            return false;
        }
    }

    function isEnabled() {
        if (!initialized) {
            init();
        }
        return Boolean(messagingClient);
    }

    async function pruneInvalidTokens(tokens) {
        if (!Array.isArray(tokens) || tokens.length === 0) {
            return 0;
        }
        const placeholders = tokens.map(() => '?').join(', ');
        const result = await db.run(
            `DELETE FROM device_push_tokens WHERE token IN (${placeholders})`,
            tokens
        );
        return result.changes || 0;
    }

    async function sendOrderReadyNotification(order) {
        if (!order || !order.id) {
            return { sent: 0, failed: 0, pruned: 0, skipped: 'invalid_order' };
        }

        const userEmail = typeof order.user?.email === 'string'
            ? order.user.email.trim().toLowerCase()
            : '';
        if (!userEmail || userEmail === 'guest') {
            return { sent: 0, failed: 0, pruned: 0, skipped: 'guest_order' };
        }

        if (!isEnabled()) {
            return { sent: 0, failed: 0, pruned: 0, skipped: 'disabled' };
        }

        const rows = await db.query(
            `SELECT token, locale
             FROM device_push_tokens
             WHERE LOWER(user_email) = ?`,
            [userEmail]
        );

        if (!rows || rows.length === 0) {
            return { sent: 0, failed: 0, pruned: 0, skipped: 'no_tokens' };
        }

        const tokensByLocale = new Map();
        for (const row of rows) {
            if (!row?.token) {
                continue;
            }
            const locale = normalizePushLocale(row.locale);
            if (!tokensByLocale.has(locale)) {
                tokensByLocale.set(locale, []);
            }
            tokensByLocale.get(locale).push(row.token);
        }

        const sentAt = new Date().toISOString();
        let sent = 0;
        let failed = 0;
        const staleTokens = [];

        for (const [locale, tokens] of tokensByLocale.entries()) {
            for (const batch of chunkArray(tokens, MAX_MULTICAST_TOKENS)) {
                const message = buildOrderReadyMulticastMessage({
                    order,
                    tokens: batch,
                    locale,
                    sentAt,
                    publicAppUrl: env.PUBLIC_APP_URL
                });

                const response = await messagingClient.sendEachForMulticast(message);
                sent += response.successCount || 0;
                failed += response.failureCount || 0;

                if (Array.isArray(response.responses)) {
                    response.responses.forEach((item, index) => {
                        if (!item.success) {
                            const code = item.error?.code;
                            if (INVALID_TOKEN_ERROR_CODES.has(code)) {
                                staleTokens.push(batch[index]);
                            } else if (code) {
                                logger.warn(`FCM send failure for order ${order.id} (${code}):`, item.error?.message);
                            }
                        }
                    });
                }
            }
        }

        const pruned = await pruneInvalidTokens(staleTokens);
        return { sent, failed, pruned, skipped: null };
    }

    return {
        init,
        isEnabled,
        sendOrderReadyNotification
    };
}

module.exports = {
    ANDROID_ORDER_READY_CHANNEL_ID,
    INVALID_TOKEN_ERROR_CODES,
    buildOrderReadyLocalizedCopy,
    buildOrderReadyMulticastMessage,
    createPushService,
    extractPickupNumber,
    normalizePushLocale,
    resolvePublicAppOrigin,
    resolveServiceAccountConfig
};
