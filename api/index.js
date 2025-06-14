const express = require('express');
const http = require('http');
const WebSocket = require('ws');
const path = require('path');
const cors = require('cors');
const compression = require('compression');

const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

// Enable CORS and compression
app.use(cors());
app.use(compression());

// Serve static files from public directory
app.use(express.static(path.join(__dirname, '../public')));

// WebSocket connection handling
wss.on('connection', (ws) => {
    console.log('New WebSocket connection');

    ws.on('message', (message) => {
        try {
            const data = JSON.parse(message);
            console.log('Received:', data);

            // Handle different message types
            switch (data.type) {
                case 'admin_login':
                    // Handle admin login
                    if (data.email === 'admin@canteen.app' && data.password === 'admin123') {
                        ws.send(JSON.stringify({ type: 'admin_login_success' }));
                    } else {
                        ws.send(JSON.stringify({ type: 'admin_login_error' }));
                    }
                    break;

                case 'canteen_status':
                    // Handle canteen status updates
                    ws.send(JSON.stringify({ type: 'canteen_status', isOpen: true }));
                    break;

                default:
                    console.log('Unknown message type:', data.type);
            }
        } catch (error) {
            console.error('Error processing message:', error);
        }
    });

    ws.on('close', () => {
        console.log('Client disconnected');
    });
});

// Main route
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, '../public/index.html'));
});

// Get port from environment variable or use default
const PORT = process.env.PORT || 3000;

server.listen(PORT, () => {
    console.log(`Server is running on port ${PORT}`);
});

module.exports = app; 