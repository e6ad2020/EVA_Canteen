const crypto = require('crypto');
const { promisify } = require('util');

const scryptAsync = promisify(crypto.scrypt);
const SCRYPT_N = 16384;
const SCRYPT_R = 8;
const SCRYPT_P = 1;
const SCRYPT_KEYLEN = 64;

let bcryptImpl = null;
let engineName = 'node:scrypt';
let warnedLegacyBcrypt = false;

if (process.env.EVA_PASSWORD_ENGINE !== 'scrypt') {
    for (const pkgName of ['bcrypt', 'bcryptjs']) {
        try {
            bcryptImpl = require(pkgName);
            engineName = pkgName;
            break;
        } catch {
            // Optional/native package unavailable on this platform; try next engine.
        }
    }
}

async function hashScrypt(password) {
    const salt = crypto.randomBytes(16).toString('base64');
    const derived = await scryptAsync(password, salt, SCRYPT_KEYLEN, {
        N: SCRYPT_N,
        r: SCRYPT_R,
        p: SCRYPT_P
    });
    return `$scrypt$${SCRYPT_N}$${SCRYPT_R}$${SCRYPT_P}$${salt}$${Buffer.from(derived).toString('base64')}`;
}

async function compareScrypt(password, storedHash) {
    const parts = String(storedHash || '').split('$');
    // ['', 'scrypt', N, r, p, salt, expectedB64]
    if (parts.length !== 7 || parts[1] !== 'scrypt') {
        return false;
    }
    const n = Number(parts[2]);
    const r = Number(parts[3]);
    const p = Number(parts[4]);
    const salt = parts[5];
    const expected = Buffer.from(parts[6], 'base64');

    if (!Number.isFinite(n) || !Number.isFinite(r) || !Number.isFinite(p) || !salt || expected.length === 0) {
        return false;
    }

    const derived = Buffer.from(
        await scryptAsync(password, salt, expected.length, { N: n, r, p })
    );
    if (derived.length !== expected.length) {
        return false;
    }
    return crypto.timingSafeEqual(derived, expected);
}

async function hashPassword(password, rounds = 10) {
    if (bcryptImpl) {
        return bcryptImpl.hash(password, rounds);
    }
    return hashScrypt(password);
}

async function comparePassword(password, storedHash) {
    if (typeof storedHash !== 'string' || !storedHash) {
        return false;
    }
    if (storedHash.startsWith('$scrypt$')) {
        return compareScrypt(password, storedHash);
    }
    if (bcryptImpl) {
        return bcryptImpl.compare(password, storedHash);
    }
    if (storedHash.startsWith('$2') && !warnedLegacyBcrypt) {
        warnedLegacyBcrypt = true;
        console.warn(
            'Legacy $2* bcrypt hash encountered without native bcrypt/bcryptjs installed; ' +
            're-register user or install optional pure-JS bcryptjs.'
        );
    }
    return false;
}

module.exports = {
    engineName,
    hashPassword,
    comparePassword
};
