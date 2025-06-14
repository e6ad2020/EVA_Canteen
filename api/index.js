const express = require('express');
const { createServer } = require('http');
const { initWebSocket } = require('./ws');
const path = require('path');

const app = express();
const server = createServer(app);

// Initialize WebSocket
initWebSocket(server);

// Serve static files from the public directory
app.use(express.static(path.join(__dirname, '../public')));

// Serve static files from the root directory
app.use(express.static(path.join(__dirname, '..')));

// Main route - serve index.html
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, '../index.html'));
});

// Start server
const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});

module.exports = app; 