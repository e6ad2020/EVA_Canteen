const assert = require('assert');
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
const WebSocket = require('ws');

const TEST_PORT = 18089;
const SRC_DB = path.join(__dirname, '..', 'data', 'canteen.db');
const TMP_DB = `/tmp/canteen_test_${Date.now()}.db`;

fs.copyFileSync(SRC_DB, TMP_DB);

function createClient() {
    return new Promise((resolve, reject) => {
        const ws = new WebSocket(`ws://127.0.0.1:${TEST_PORT}`);
        const inbox = [];
        const waiters = [];

        ws.on('message', (raw) => {
            const msg = JSON.parse(raw.toString('utf8'));
            const matchIdx = waiters.findIndex((w) => w.predicate(msg));
            if (matchIdx !== -1) {
                const [waiter] = waiters.splice(matchIdx, 1);
                clearTimeout(waiter.timer);
                waiter.resolve(msg);
            } else {
                inbox.push(msg);
            }
        });

        ws.waitFor = (type, timeoutMs = 4000) => {
            const bufferedIdx = inbox.findIndex((m) => m.type === type);
            if (bufferedIdx !== -1) {
                return Promise.resolve(inbox.splice(bufferedIdx, 1)[0]);
            }
            return new Promise((res, rej) => {
                const timer = setTimeout(() => rej(new Error(`Timeout waiting for ${type}`)), timeoutMs);
                waiters.push({
                    predicate: (m) => m.type === type,
                    resolve: res,
                    timer
                });
            });
        };

        ws.sendEvent = (type, payload) => {
            ws.send(JSON.stringify(payload === undefined ? { type } : { type, payload }));
        };

        ws.once('open', () => resolve(ws));
        ws.once('error', reject);
    });
}

async function main() {
    const serverProc = spawn('node', ['server.js'], {
        cwd: path.join(__dirname, '..'),
        env: {
            ...process.env,
            PORT: String(TEST_PORT),
            DB_PATH: TMP_DB
        },
        stdio: ['ignore', 'pipe', 'pipe']
    });

    await new Promise((resolve, reject) => {
        const timer = setTimeout(() => reject(new Error('Server startup timeout')), 6000);
        serverProc.stdout.on('data', (chunk) => {
            if (chunk.toString().includes('EVA Canteen Server Running')) {
                clearTimeout(timer);
                resolve();
            }
        });
        serverProc.on('exit', (code) => reject(new Error(`Server exited early: ${code}`)));
    });

    try {
        const attackerWs = await createClient();
        await attackerWs.waitFor('initial_bundles');
        await attackerWs.waitFor('initial_payment_methods');

        // 1. Verify unauthenticated identify_management is blocked
        attackerWs.sendEvent('identify_management');
        const blocked = await attackerWs.waitFor('admin_auth_required');
        assert.ok(blocked.payload.message, 'Unauthenticated identify_management must be rejected');

        // 2. Admin login + JWT token issuance
        const adminWs = await createClient();
        adminWs.sendEvent('admin_login', { email: 'admin@canteen.app', password: 'admin123' });
        const adminLogin = await adminWs.waitFor('admin_login_success');
        assert.ok(adminLogin.payload.token, 'Admin login must issue JWT token');

        // Ensure canteen is open
        adminWs.sendEvent('admin_set_canteen_status', { isOpen: true });
        await adminWs.waitFor('canteen_status_updated');

        // 3. Register student with legacy avatar URL -> normalized to pic3 + JWT
        const studentWs = await createClient();
        const studentEmail = `student_${Date.now()}@eva.edu`;
        studentWs.sendEvent('register_user', {
            email: studentEmail,
            password: 'secret123',
            profilePic: 'https://example.com/assets/pfp3.png'
        });
        const regOk = await studentWs.waitFor('register_success');
        assert.strictEqual(regOk.payload.profilePic, 'pic3', 'Avatar URL must normalize to pic3');
        assert.ok(regOk.payload.token, 'Student registration must return JWT token');

        // 4. Admin tops up student wallet -> student receives live wallet_balance_updated
        adminWs.sendEvent('admin_adjust_wallet', {
            email: studentEmail,
            mode: 'add',
            amount: 200,
            reason: 'Initial Campus Allowance'
        });
        const walletPush = await studentWs.waitFor('wallet_balance_updated');
        assert.strictEqual(walletPush.payload.balance, 200, 'Student wallet balance must be 200');

        // 5. Student places bundle order with negative discount item + wallet payment
        studentWs.sendEvent('place_order', {
            items: [
                { id: 'pizza', quantity: 1, price: 65, name_key: 'item_name_pizza' },
                { id: 'salad', quantity: 1, price: 35, name_key: 'item_name_salad' },
                { id: 'soda', quantity: 1, price: 15, name_key: 'item_name_soda' },
                {
                    id: 'discount-bundle-lunch-deal-1',
                    bundleId: 'bundle-lunch-deal',
                    quantity: 1,
                    price: -17,
                    isDiscount: true,
                    name_key: 'bundle_discount_applied'
                }
            ],
            totalAmount: 98,
            paymentMethod: 'wallet',
            user: { email: studentEmail, profilePic: 'pic3' }
        });

        const confirmed = await studentWs.waitFor('order_confirmed_by_server');
        assert.ok(confirmed.payload.id.startsWith('ORD-'), 'Order must receive sequential ORD-* ID');
        assert.strictEqual(confirmed.payload.paymentMethod, 'wallet');
        assert.ok(confirmed.payload.totalAmount > 0 && confirmed.payload.totalAmount < 115, 'Bundle discount must apply');

        const afterOrderWallet = await studentWs.waitFor('wallet_balance_updated');
        assert.strictEqual(
            afterOrderWallet.payload.balance,
            Number((200 - confirmed.payload.totalAmount).toFixed(2)),
            'Wallet balance must deduct authoritative order total'
        );

        // 6. Admin updates order status -> student receives live my_order_updated!
        adminWs.sendEvent('update_order_status', {
            orderId: confirmed.payload.id,
            newStatus: 'preparing'
        });
        const liveTrack = await studentWs.waitFor('my_order_updated');
        assert.strictEqual(liveTrack.payload.newStatus, 'preparing', 'Student must receive live status push');

        // 7. Verify HTTP image upload with Admin JWT
        const onePixelPng =
            'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
        const uploadRes = await fetch(`http://127.0.0.1:${TEST_PORT}/api/upload-image`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                Authorization: `Bearer ${adminLogin.payload.token}`
            },
            body: JSON.stringify({ dataUrl: onePixelPng })
        });
        assert.strictEqual(uploadRes.status, 200, 'Authorized image upload must return 200');
        const uploadJson = await uploadRes.json();
        assert.ok(uploadJson.url.startsWith('/uploads/prod-'), 'Upload must return /uploads/... path');
        // Clean up test upload file
        const uploadedFile = path.join(__dirname, '..', uploadJson.url);
        if (fs.existsSync(uploadedFile)) fs.unlinkSync(uploadedFile);

        // Helper to inspect TMP_DB state directly (WAL allows concurrent read)
        const { DatabaseSync } = require('node:sqlite');
        const readDb = new DatabaseSync(TMP_DB, { open: true });
        const readOne = (sql, ...params) => {
            const row = readDb.prepare(sql).get(...params);
            return row ? { ...row } : null;
        };
        const readAll = (sql, ...params) => readDb.prepare(sql).all(...params).map((r) => ({ ...r }));

        try {
            // 8. Push token registration, validation, multi-device, and account reassignment
            const unauthTokenRes = await fetch(`http://127.0.0.1:${TEST_PORT}/api/push-tokens`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    token: 'fcm_test_token_android_0001',
                    platform: 'android',
                    locale: 'en'
                })
            });
            assert.strictEqual(unauthTokenRes.status, 401, 'Unauthenticated push token registration must return 401');

            const badPlatformRes = await fetch(`http://127.0.0.1:${TEST_PORT}/api/push-tokens`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    Authorization: `Bearer ${regOk.payload.token}`
                },
                body: JSON.stringify({
                    token: 'fcm_test_token_android_0001',
                    platform: 'desktop',
                    locale: 'en'
                })
            });
            assert.strictEqual(badPlatformRes.status, 400, 'Invalid platform must return 400');

            const tokenAndroid = 'fcm_test_token_android_0001';
            const tokenWeb = 'fcm_test_token_web_0002';

            const regAndroidRes = await fetch(`http://127.0.0.1:${TEST_PORT}/api/push-tokens`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    Authorization: `Bearer ${regOk.payload.token}`
                },
                body: JSON.stringify({ token: tokenAndroid, platform: 'android', locale: 'en' })
            });
            assert.strictEqual(regAndroidRes.status, 200, 'Student Android push token registration must succeed');

            const regWebRes = await fetch(`http://127.0.0.1:${TEST_PORT}/api/push-tokens`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    Authorization: `Bearer ${regOk.payload.token}`
                },
                body: JSON.stringify({ token: tokenWeb, platform: 'web', locale: 'ar' })
            });
            assert.strictEqual(regWebRes.status, 200, 'Student Web push token registration must succeed');

            let studentATokens = readAll(
                'SELECT token, user_email, user_role, platform, locale FROM device_push_tokens WHERE user_email = ? ORDER BY token',
                studentEmail
            );
            assert.strictEqual(studentATokens.length, 2, 'Student must support multiple registered devices');
            assert.strictEqual(studentATokens[0].user_role, 'user');
            assert.strictEqual(studentATokens[1].locale, 'ar');

            // Register Student B and take over Android device token (shared-device switch)
            const studentBWs = await createClient();
            const studentBEmail = `student_b_${Date.now()}@eva.edu`;
            studentBWs.sendEvent('register_user', {
                email: studentBEmail,
                password: 'secret123',
                profilePic: 'pic1'
            });
            const regBOk = await studentBWs.waitFor('register_success');

            const reassignRes = await fetch(`http://127.0.0.1:${TEST_PORT}/api/push-tokens`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    Authorization: `Bearer ${regBOk.payload.token}`
                },
                body: JSON.stringify({ token: tokenAndroid, platform: 'android', locale: 'ar' })
            });
            assert.strictEqual(reassignRes.status, 200, 'Token reassignment to Student B must succeed');

            const reassignedRow = readOne(
                'SELECT user_email, locale FROM device_push_tokens WHERE token = ?',
                tokenAndroid
            );
            assert.strictEqual(reassignedRow.user_email, studentBEmail, 'Token must be reassigned to Student B');
            assert.strictEqual(reassignedRow.locale, 'ar', 'Reassigned token locale must update to ar');

            // Student A cannot delete Student B's token
            const crossDeleteRes = await fetch(`http://127.0.0.1:${TEST_PORT}/api/push-tokens`, {
                method: 'DELETE',
                headers: {
                    'Content-Type': 'application/json',
                    Authorization: `Bearer ${regOk.payload.token}`
                },
                body: JSON.stringify({ token: tokenAndroid })
            });
            assert.strictEqual(crossDeleteRes.status, 200);
            const crossDeleteJson = await crossDeleteRes.json();
            assert.strictEqual(crossDeleteJson.deleted, false, 'Student A must not delete Student B token');

            // Student B deletes their own token on logout
            const logoutDeleteRes = await fetch(`http://127.0.0.1:${TEST_PORT}/api/push-tokens`, {
                method: 'DELETE',
                headers: {
                    'Content-Type': 'application/json',
                    Authorization: `Bearer ${regBOk.payload.token}`
                },
                body: JSON.stringify({ token: tokenAndroid })
            });
            assert.strictEqual(logoutDeleteRes.status, 200);
            const logoutDeleteJson = await logoutDeleteRes.json();
            assert.strictEqual(logoutDeleteJson.deleted, true, 'Student B logout must delete their push token');
            assert.strictEqual(
                readOne('SELECT token FROM device_push_tokens WHERE token = ?', tokenAndroid),
                null,
                'Deleted token must no longer exist in SQLite'
            );
            studentBWs.close();

            // 9. Order Ready atomic transition guard, duplicate protection & explicit reopen
            let orderRow = readOne(
                'SELECT status, ready_notified_at FROM orders WHERE id = ?',
                confirmed.payload.id
            );
            assert.strictEqual(orderRow.status, 'preparing');
            assert.strictEqual(orderRow.ready_notified_at, null, 'Preparing order must not have ready_notified_at');

            // Transition preparing -> delivered ("Ready")
            adminWs.sendEvent('update_order_status', {
                orderId: confirmed.payload.id,
                newStatus: 'delivered'
            });
            const readyEvt = await studentWs.waitFor('my_order_updated');
            assert.strictEqual(readyEvt.payload.newStatus, 'delivered');

            orderRow = readOne(
                'SELECT status, ready_notified_at FROM orders WHERE id = ?',
                confirmed.payload.id
            );
            assert.ok(orderRow.ready_notified_at, 'Transition to delivered must populate ready_notified_at');
            const firstNotifiedAt = orderRow.ready_notified_at;

            // Duplicate delivered -> delivered must NOT overwrite ready_notified_at
            await new Promise((r) => setTimeout(r, 25));
            adminWs.sendEvent('update_order_status', {
                orderId: confirmed.payload.id,
                newStatus: 'delivered'
            });
            await studentWs.waitFor('my_order_updated');
            orderRow = readOne(
                'SELECT status, ready_notified_at FROM orders WHERE id = ?',
                confirmed.payload.id
            );
            assert.strictEqual(
                orderRow.ready_notified_at,
                firstNotifiedAt,
                'Duplicate delivered update must preserve ready_notified_at without re-notifying'
            );

            // Explicit reopen (delivered -> pending) must clear ready_notified_at
            adminWs.sendEvent('update_order_status', {
                orderId: confirmed.payload.id,
                newStatus: 'pending'
            });
            const reopenEvt = await studentWs.waitFor('my_order_updated');
            assert.strictEqual(reopenEvt.payload.newStatus, 'pending');
            orderRow = readOne(
                'SELECT status, ready_notified_at FROM orders WHERE id = ?',
                confirmed.payload.id
            );
            assert.strictEqual(orderRow.ready_notified_at, null, 'Explicit reopen to pending must clear ready_notified_at');

            // Concurrent double-tap pending -> delivered must serialize cleanly and claim once
            adminWs.sendEvent('update_order_status', {
                orderId: confirmed.payload.id,
                newStatus: 'delivered'
            });
            adminWs.sendEvent('update_order_status', {
                orderId: confirmed.payload.id,
                newStatus: 'delivered'
            });
            await studentWs.waitFor('my_order_updated');
            await studentWs.waitFor('my_order_updated');
            orderRow = readOne(
                'SELECT status, ready_notified_at FROM orders WHERE id = ?',
                confirmed.payload.id
            );
            assert.strictEqual(orderRow.status, 'delivered');
            assert.ok(orderRow.ready_notified_at, 'Re-marking ready after reopen must set ready_notified_at');
        } finally {
            readDb.close();
        }

        // 10. Unit-verify push_service.js bilingual multicast payload, APNs constraints & stale-token pruning
        const { createPushService, ANDROID_ORDER_READY_CHANNEL_ID } = require('../push_service');
        const fakeRows = [
            { token: 'tok_en_valid_000001', locale: 'en' },
            { token: 'tok_en_stale_000002', locale: 'en' },
            { token: 'tok_ar_valid_000003', locale: 'ar' }
        ];
        const deletedTokens = [];
        const sentMessages = [];
        const fakeDb = {
            query: async () => fakeRows,
            run: async (_sql, params) => {
                deletedTokens.push(...params);
                return { changes: params.length };
            }
        };
        const fakeMessaging = {
            sendEachForMulticast: async (message) => {
                sentMessages.push(message);
                const responses = message.tokens.map((t) =>
                    t === 'tok_en_stale_000002'
                        ? { success: false, error: { code: 'messaging/registration-token-not-registered', message: 'Unregistered' } }
                        : { success: true, messageId: `msg_${t}` }
                );
                return {
                    successCount: responses.filter((r) => r.success).length,
                    failureCount: responses.filter((r) => !r.success).length,
                    responses
                };
            }
        };

        const testPush = createPushService({ db: fakeDb, messaging: fakeMessaging, env: {} });
        const pushSummary = await testPush.sendOrderReadyNotification({
            id: 'ORD-42-18-11-2026',
            status: 'delivered',
            user: { email: studentEmail }
        });

        assert.strictEqual(pushSummary.sent, 2, 'Two valid tokens must succeed');
        assert.strictEqual(pushSummary.failed, 1, 'One stale token must fail');
        assert.strictEqual(pushSummary.pruned, 1, 'One stale token must be pruned');
        assert.deepStrictEqual(deletedTokens, ['tok_en_stale_000002'], 'Exact stale token must be deleted');
        assert.strictEqual(sentMessages.length, 2, 'Tokens must be grouped into EN and AR multicast batches');

        const enMsg = sentMessages.find((m) => m.tokens.includes('tok_en_valid_000001'));
        const arMsg = sentMessages.find((m) => m.tokens.includes('tok_ar_valid_000003'));
        assert.strictEqual(enMsg.notification.title, 'Order #42 is ready!');
        assert.strictEqual(arMsg.notification.title, 'طلبك رقم #42 جاهز للاستلام!');
        assert.strictEqual(enMsg.data.type, 'order_ready');
        assert.strictEqual(enMsg.data.orderId, 'ORD-42-18-11-2026');
        assert.strictEqual(enMsg.data.pickupNumber, '#42');
        assert.strictEqual(enMsg.data.route, '/orders');
        assert.strictEqual(enMsg.android.notification.channelId, ANDROID_ORDER_READY_CHANNEL_ID);
        assert.strictEqual(enMsg.apns.payload.aps.sound, 'default');
        assert.strictEqual(enMsg.apns.payload.aps.badge, undefined, 'APNs payload must not set badge');
        assert.strictEqual(
            enMsg.apns.payload.aps['interruption-level'],
            undefined,
            'APNs payload must not set interruption-level'
        );
        assert.strictEqual(
            enMsg.webpush.fcmOptions,
            undefined,
            'webpush.fcmOptions must be omitted when PUBLIC_APP_URL is unset'
        );

        const { buildOrderReadyMulticastMessage } = require('../push_service');
        const httpMsg = buildOrderReadyMulticastMessage({
            order: { id: 'ORD-42-18-11-2026' },
            tokens: ['tok_web_1'],
            locale: 'en',
            publicAppUrl: 'http://localhost:8080'
        });
        assert.strictEqual(
            httpMsg.webpush.fcmOptions,
            undefined,
            'webpush.fcmOptions must be omitted for non-HTTPS PUBLIC_APP_URL'
        );

        const httpsMsg = buildOrderReadyMulticastMessage({
            order: { id: 'ORD-42-18-11-2026' },
            tokens: ['tok_web_1'],
            locale: 'en',
            publicAppUrl: 'https://eva-canteen.app/subpath/'
        });
        assert.strictEqual(
            httpsMsg.webpush.fcmOptions.link,
            'https://eva-canteen.app/orders?orderId=ORD-42-18-11-2026',
            'webpush.fcmOptions.link must use full HTTPS origin when PUBLIC_APP_URL is valid'
        );

        attackerWs.close();
        adminWs.close();
        studentWs.close();
        console.log('ALL BACKEND V1.1 INTEGRATION TESTS PASSED!');
    } finally {
        serverProc.kill('SIGTERM');
        for (const suffix of ['', '-wal', '-shm']) {
            if (fs.existsSync(TMP_DB + suffix)) fs.unlinkSync(TMP_DB + suffix);
        }
    }
}

main().catch((err) => {
    console.error('Backend verification failed:', err);
    process.exit(1);
});
