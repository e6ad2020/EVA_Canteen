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
