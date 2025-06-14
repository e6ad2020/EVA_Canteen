// Global variables
let ws = null;
let isCanteenOpen = false;
let isManagementClient = false;
let discoveryBackButton = null;

// Default data
const defaultProducts = [
    {
        id: 1,
        name: { en: "Burger", ar: "برجر" },
        description: { en: "Delicious burger with cheese", ar: "برجر لذيذ مع الجبن" },
        price: 50,
        image: "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=220&h=165&fit=crop",
        category: "Fast Food"
    },
    {
        id: 2,
        name: { en: "Pizza", ar: "بيتزا" },
        description: { en: "Classic margherita pizza", ar: "بيتزا مارغريتا كلاسيكية" },
        price: 60,
        image: "https://images.unsplash.com/photo-1513104890138-7c749659a591?w=220&h=165&fit=crop",
        category: "Fast Food"
    }
];

const defaultTranslations = {
    welcome: { en: "Welcome to EVA Canteen", ar: "مرحباً بك في مطعم إيفا" },
    menu: { en: "Menu", ar: "القائمة" },
    cart: { en: "Cart", ar: "السلة" },
    total: { en: "Total", ar: "المجموع" },
    currency: { en: "L.E", ar: "ج.م" }
};

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
            updateTranslations(defaultTranslations);
            localStorage.setItem('translations', JSON.stringify(defaultTranslations));
        }
    } catch (error) {
        console.error('Error loading translations:', error);
    }
}

// Update translations
function updateTranslations(translations) {
    // Update welcome message
    const welcomeElement = document.querySelector('.welcome-message');
    if (welcomeElement) {
        welcomeElement.textContent = translations.welcome.en;
    }

    // Update menu text
    const menuElement = document.querySelector('.menu-text');
    if (menuElement) {
        menuElement.textContent = translations.menu.en;
    }

    // Update cart text
    const cartElement = document.querySelector('.cart-text');
    if (cartElement) {
        cartElement.textContent = translations.cart.en;
    }

    // Update total text
    const totalElement = document.querySelector('.total-text');
    if (totalElement) {
        totalElement.textContent = translations.total.en;
    }
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
    try {
        switch (data.type) {
            case 'canteen_status':
                isCanteenOpen = data.isOpen;
                updateCanteenStatus();
                break;
            case 'admin_login_success':
                isManagementClient = true;
                showAdminPanel();
                break;
            case 'admin_login_error':
                showError('Invalid admin credentials');
                break;
            default:
                console.log('Unknown message type:', data.type);
        }
    } catch (error) {
        console.error('Error handling WebSocket message:', error);
    }
}

// Show admin panel
function showAdminPanel() {
    const adminPanel = document.querySelector('.admin-panel');
    if (adminPanel) {
        adminPanel.style.display = 'block';
    }
}

// Show error message
function showError(message) {
    const errorElement = document.querySelector('.error-message');
    if (errorElement) {
        errorElement.textContent = message;
        errorElement.style.display = 'block';
        setTimeout(() => {
            errorElement.style.display = 'none';
        }, 3000);
    }
}

// WebSocket connection
function connectWebSocket() {
    const wsUrl = 'wss://jet-rigorous-baseball.glitch.me/ws';
    ws = new WebSocket(wsUrl);
    
    ws.onopen = () => {
        console.log('WebSocket connected');
        // Request initial status
        ws.send(JSON.stringify({ type: 'get_status' }));
    };
    
    ws.onerror = (error) => {
        console.error('WebSocket error:', error);
        isCanteenOpen = false;
        updateCanteenStatus();
        showError('Connection error. Retrying...');
    };
    
    ws.onclose = () => {
        console.log('WebSocket disconnected. Attempting to reconnect...');
        isCanteenOpen = false;
        updateCanteenStatus();
        showError('Connection lost. Reconnecting...');
        setTimeout(connectWebSocket, 5000);
    };
    
    ws.onmessage = (event) => {
        try {
            const data = JSON.parse(event.data);
            handleWebSocketMessage(data);
        } catch (error) {
            console.error('Error parsing WebSocket message:', error);
            showError('Error processing server response');
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
    const ordersContainer = document.querySelector('.orders-container');
    if (ordersContainer) {
        ordersContainer.innerHTML = orders.length ? 
            orders.map(order => `
                <div class="order-item">
                    <h3>Order #${order.id}</h3>
                    <p>Total: ${order.total} L.E</p>
                </div>
            `).join('') : 
            '<p>No orders yet</p>';
    }
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
            updateProductsDisplay(defaultProducts);
            localStorage.setItem('products', JSON.stringify(defaultProducts));
        }
    } catch (error) {
        console.error('Error loading products:', error);
    }
}

// Update products display
function updateProductsDisplay(products) {
    const productsContainer = document.querySelector('.products-container');
    if (productsContainer) {
        productsContainer.innerHTML = products.map(product => `
            <div class="product-card">
                <img src="${product.image}" alt="${product.name.en}" onerror="this.src='https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=220&h=165&fit=crop'">
                <h3>${product.name.en}</h3>
                <p>${product.description.en}</p>
                <p class="price">${product.price} L.E</p>
                <button onclick="addToCart(${product.id})">Add to Cart</button>
            </div>
        `).join('');
    }
}
