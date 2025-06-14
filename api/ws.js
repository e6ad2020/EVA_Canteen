const WebSocket = require('ws');
const { Server } = require('ws');

let wss;

function initWebSocket(server) {
  wss = new Server({ server });
  
  wss.on('connection', (ws) => {
    console.log('Client connected');
    
    ws.on('message', (message) => {
      try {
        const data = JSON.parse(message);
        console.log('Received:', data);
        
        // Handle different message types
        switch(data.type) {
          case 'admin_login':
            // Handle admin login
            break;
          case 'canteen_status':
            // Handle canteen status updates
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
}

module.exports = { initWebSocket }; 