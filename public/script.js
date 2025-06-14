// Global variables
let ws = null;
let isCanteenOpen = false;
let isManagementClient = false;
let discoveryBackButton = null;

// Initialize UI elements
document.addEventListener('DOMContentLoaded', () => {
    // Initialize back button
    discoveryBackButton = document.querySelector('.discovery-back-button');
    if (discoveryBackButton) {
        discoveryBackButton.addEventListener('click', () => {
            // Add your back button logic here
            console.log('Back button clicked');
        });
    }

    // Connect to WebSocket
    connectWebSocket();
    
    // Load initial data
    loadTranslations();
    loadProducts();
    loadOrders();
});

// Load translations
function loadTranslations() {
    try {
        const storedTranslations = localStorage.getItem('translations');
        if (storedTranslations) {
            const translations = JSON.parse(storedTranslations);
            updateTranslations(translations);
        } else {
            console.log('Using default translations');
            // Add default translations here if needed
        }
    } catch (error) {
        console.error('Error loading translations:', error);
    }
}

// Update translations
function updateTranslations(translations) {
    // Add your translation update logic here
    console.log('Updating translations:', translations);
}

// Update canteen status
function updateCanteenStatus() {
    const statusElement = document.querySelector('.canteen-status');
    if (statusElement) {
        statusElement.textContent = isCanteenOpen ? 'Canteen is currently OPEN' : 'Canteen is currently CLOSED';
        statusElement.className = `canteen-status ${isCanteenOpen ? 'open' : 'closed'}`;
    }
}

// Handle WebSocket messages
function handleWebSocketMessage(data) {
    console.log('Received message:', data);
    switch (data.type) {
        case 'canteen_status':
            isCanteenOpen = data.isOpen;
            updateCanteenStatus();
            break;
        case 'admin_login_success':
            isManagementClient = true;
            // Add your admin login success logic here
            break;
        case 'admin_login_error':
            // Add your admin login error logic here
            break;
        default:
            console.log('Unknown message type:', data.type);
    }
}

// WebSocket connection
function connectWebSocket() {
    const wsUrl = 'wss://jet-rigorous-baseball.glitch.me/ws';
    ws = new WebSocket(wsUrl);
    
    ws.onopen = () => {
        console.log('WebSocket connected');
        isCanteenOpen = true;
        updateCanteenStatus();
    };
    
    ws.onerror = (error) => {
        console.error('WebSocket error:', error);
        isCanteenOpen = false;
        updateCanteenStatus();
    };
    
    ws.onclose = () => {
        console.log('WebSocket disconnected. Attempting to reconnect...');
        isCanteenOpen = false;
        updateCanteenStatus();
        setTimeout(connectWebSocket, 5000);
    };
    
    ws.onmessage = (event) => {
        try {
            const data = JSON.parse(event.data);
            handleWebSocketMessage(data);
        } catch (error) {
            console.error('Error parsing WebSocket message:', error);
        }
    };
}

// Load orders
function loadOrders() {
    try {
        const storedOrders = localStorage.getItem('orders');
        if (storedOrders) {
            const orders = JSON.parse(storedOrders);
            updateOrdersDisplay(orders);
        }
    } catch (error) {
        console.error('Error loading orders:', error);
    }
}

// Update orders display
function updateOrdersDisplay(orders) {
    // Add your orders display logic here
    console.log('Updating orders display:', orders);
}

// Load products
function loadProducts() {
    try {
        const storedProducts = localStorage.getItem('products');
        if (storedProducts) {
            const products = JSON.parse(storedProducts);
            updateProductsDisplay(products);
        } else {
            console.log('Using default products');
            // Add default products here if needed
        }
    } catch (error) {
        console.error('Error loading products:', error);
    }
}

// Update products display
function updateProductsDisplay(products) {
    // Add your products display logic here
    console.log('Updating products display:', products);
}
