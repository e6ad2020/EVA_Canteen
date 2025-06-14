const express = require('express');
const { createServer } = require('http');
const { initWebSocket } = require('./ws');

const app = express();
const server = createServer(app);

// Initialize WebSocket
initWebSocket(server);

// Basic route
app.get('/', (req, res) => {
  res.send('EVA Canteen API is running');
});

// Start server
const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});

module.exports = app; 