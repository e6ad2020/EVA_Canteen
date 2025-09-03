const bcrypt = require('bcrypt');
const readline = require('readline');

const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
});

function hashPassword(password) {
    bcrypt.hash(password, 10, (err, hash) => {
        if (err) {
            console.error('Error hashing password:', err);
            rl.close();
            return;
        }
        console.log('Hashed password:', hash);
        rl.close();
    });
}

function comparePassword(password, hash) {
    bcrypt.compare(password, hash, (err, result) => {
        if (err) {
            console.error('Error comparing password:', err);
            rl.close();
            return;
        }
        if (result) {
            console.log('Passwords match!');
        } else {
            console.log('Passwords do not match.');
        }
        rl.close();
    });
}

console.log('Password and Hash Tool');
console.log('-----------------------');
rl.question('Choose an option: (1) Hash a password, (2) Compare a password to a hash\n> ', (choice) => {
    if (choice === '1') {
        rl.question('Enter the password to hash: ', (password) => {
            hashPassword(password);
        });
    } else if (choice === '2') {
        rl.question('Enter the hash to compare against: ', (hash) => {
            rl.question('Enter the password to compare: ', (password) => {
                comparePassword(password, hash);
            });
        });
    } else {
        console.log('Invalid choice. Please run the tool again and choose 1 or 2.');
        rl.close();
    }
});