// Global variables
let ws = null;
let isCanteenOpen = false;
let isManagementClient = false;
let discoveryBackButton = null;
// --- New DOM Elements Caching ---
const bodyElement = document.body;
const settingsPanel = document.getElementById('settings-panel');
const settingsBtn = document.getElementById('settings-btn');
const toggleFullscreenBtn = document.getElementById('toggle-fullscreen-btn');
const currentLanguageDisplay = document.getElementById('current-language-display');
const languageOptions = document.getElementById('language-options');
const currentLanguageText = document.getElementById('current-language-text');
const languageGroup = document.getElementById('language-group');
const currentThemeDisplay = document.getElementById('current-theme-display');
const themeOptions = document.getElementById('theme-options');
const themeGroup = document.getElementById('theme-group');
const userDisplayName = document.getElementById('user-display-name');
const userProfileImage = document.getElementById('user-profile-image-display');
const guestUserIcon = document.getElementById('guest-user-icon');
const discoverButton = document.getElementById('discover-button');
const checkoutButton = document.getElementById('checkout-button');
const addToCartPreviewButton = document.getElementById('add-to-cart-preview-button');
const orderPreviewContent = document.getElementById('order-preview-content');
const orderStatusControls = document.getElementById('order-status-controls');
const orderLogContainer = document.getElementById('order-log-container');
const passcodeModalOverlay = document.getElementById('passcode-modal-overlay');
const passcodeModalInput = document.getElementById('passcode-modal-input');
const passcodeModalError = document.getElementById('passcode-modal-error');
const passcodeModalOk = document.getElementById('passcode-modal-ok');
const passcodeModalCancel = document.getElementById('passcode-modal-cancel');
const customConfirmOverlay = document.getElementById('custom-confirm-overlay');
const customConfirmTitle = document.getElementById('custom-confirm-title');
const customConfirmMessage = document.getElementById('custom-confirm-message');
const customConfirmOkButton = document.getElementById('custom-confirm-ok-button');
const customConfirmCancelButton = document.getElementById('custom-confirm-cancel-button');
const customAlertOverlay = document.getElementById('custom-alert-overlay');
const customAlertTitle = document.getElementById('custom-alert-title');
const customAlertMessage = document.getElementById('custom-alert-message');
const customAlertCloseBtn = document.getElementById('custom-alert-close-btn');


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
    currency: { en: "L.E", ar: "ج.م" },
    checkout_success_title: { en: "Order Placed!", ar: "تم تأكيد الطلب!" },
    ok_button: { en: "OK", ar: "موافق" },
    login_error_invalid: {en: "Invalid credentials (use user@canteen.app / 123)", ar: "بيانات الاعتماد غير صالحة (استخدم user@canteen.app / 123)"},
    register_error_match: {en: "Passwords don't match or field empty.", ar: "كلمات المرور غير متطابقة أو الحقول فارغة."},
    admin_login_error: {en: "Invalid admin credentials.", ar: "بيانات المسؤول غير صالحة."},
    add_to_cart_button: { en: "Add to Cart", ar: "أضف إلى السلة" },
    added_to_cart_button: { en: "Added", ar: "أضيف" },
    item_desc_default: { en: "Delicious item from our canteen.", ar: "صنف لذيذ من مقصفنا." },
    order_preview_placeholder: { en: "Select an order from the log to view details.", ar: "اختر طلبًا من السجل لعرض التفاصيل." },
    confirm_action_title: { en: "Confirm Action", ar: "تأكيد الإجراء" },
    confirm_button: { en: "Confirm", ar: "تأكيد" },
    cancel_button: { en: "Cancel", ar: "إلغاء" },
    discovery_passcode_modal_title: { en: "Enter Passcode", ar: "أدخل كلمة المرور" },
    discovery_passcode_prompt: { en: "Enter discovery mode passcode", ar: "أدخل كلمة مرور وضع الاستكشاف" },
    discovery_passcode_incorrect_message: { en: "Incorrect passcode.", ar: "كلمة المرور غير صحيحة." },
    order_status_pending: { en: "Pending", ar: "قيد الانتظار" },
    order_status_preparing: { en: "Preparing", ar: "قيد التحضير" },
    order_status_delivered: { en: "Delivered", ar: "تم التسليم" },
    canteen_status_open: { en: "Open", ar: "مفتوح" },
    canteen_status_closed: { en: "Closed", ar: "مغلق" },
    product_management_title: { en: "Product Management", ar: "إدارة المنتجات" },
    manage_categories_title: { en: "Manage Categories", ar: "إدارة الفئات" },
    add_category_button: { en: "Add Category", ar: "إضافة فئة" },
    add_product_button: { en: "Add Product", ar: "إضافة منتج" },
    edit_category_title: { en: "Edit Category", ar: "تعديل فئة" },
    delete_category_confirm: { en: "Are you sure you want to delete this category? This will also delete all products in it.", ar: "هل أنت متأكد أنك تريد حذف هذه الفئة؟ سيؤدي هذا أيضًا إلى حذف جميع المنتجات الموجودة فيها." },
    edit_product_title: { en: "Edit Product", ar: "تعديل المنتج" },
    delete_product_confirm: { en: "Are you sure you want to delete this product?", ar: "هل أنت متأكد أنك تريد حذف هذا المنتج؟" },
    select_category_placeholder: { en: "Select Category", ar: "اختر فئة" },
    drag_categories_hint: { en: "Drag and drop to reorder categories.", ar: "اسحب وأفلت لإعادة ترتيب الفئات." },
    drag_products_hint: { en: "Drag and drop to reorder products.", ar: "اسحب وأفلت لإعادة ترتيب المنتجات." },
};

let currentScreen = null; // Initialize as null, not string
let currentUser = null;
let currentLanguage = localStorage.getItem('canteenAppLanguage') || 'en'; // Default to English
let currentTheme = localStorage.getItem('canteenAppTheme') || 'blue';     // Default to blue
let cart = []; // { id: productId, quantity: n }
let baseMenuData = []; // Initialized later with default data
let allOrders = [];
let translations = {}; // Initialized later with default translations
let categories = [];
let currentAdminOrderSelection = null;
let currentOrderLogView = 'current'; // New state variable for order log view: 'current' or 'archived'
let previewButtonTimeout = null; // Timeout for preview button state
let draggedElement = null; // For drag and drop
let currentProductMgmtCategory = null; // Track which category is being viewed in product management
let isDiscoveryModeActivated = localStorage.getItem('canteenDiscoveryMode') === 'true';
let selectedPaymentMethod = 'cash'; // Initialize default payment method state


// Flags for initial data loading from WebSocket
let isInitialProductsLoaded = false;
let isInitialCategoriesLoaded = false;
let isInitialTranslationsLoaded = false;

let suggestionButtonTimeouts = {}; // Added: For discovery mode button timeouts
let bundleButtonTimeouts = {};   // Added: For discovery mode button timeouts

// --- Function to render initial UI parts after essential data is loaded ---
function renderInitialUIIfNeeded() {
    if (isInitialProductsLoaded && isInitialCategoriesLoaded && isInitialTranslationsLoaded) {
        console.log("All initial data received, rendering main UI...");
        populateSortButtons();
        populateMenuGrid();
        updateLanguageUI();
        updateProductCategoryDropdowns();
        if (currentScreen?.id === 'screen-8') {
             populateDiscoveryMode();
        }
    }
}

// Helper function to send WebSocket messages
function sendWebSocketMessage(message) {
    if (ws && ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify(message));
    } else {
        console.warn('WebSocket not open. Message not sent:', message);
    }
}

// Function to identify client as management
function identifyAsManagementClient() {
    console.log('Identifying as management client...');
    sendWebSocketMessage({ type: 'identify_management_client' });
    isManagementClient = true;
}


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

    // Show the initial screen (e.g., screen-1 for login)
    showScreen('screen-1');

    // Add event listeners for buttons
    document.getElementById('login-submit').addEventListener('click', handleLogin);
    document.querySelector('.register-button').addEventListener('click', () => showScreen('screen-2'));
    document.getElementById('goto-admin-login-button').addEventListener('click', () => showScreen('screen-6'));
    document.getElementById('register-submit').addEventListener('click', handleRegister);
    document.querySelector('#screen-2 .back-button').addEventListener('click', () => showScreen('screen-1'));
    document.getElementById('admin-login-submit').addEventListener('click', handleAdminLogin);
    document.querySelector('#screen-6 .back-button').addEventListener('click', () => showScreen('screen-1'));

    // General navigation buttons (cart icon, menu button etc.)
    document.querySelector('.cart-icon-container[data-target="screen-4"]').addEventListener('click', () => showScreen('screen-4'));
    document.querySelector('#screen-4 .header-button[data-target="screen-3"]').addEventListener('click', () => showScreen('screen-3'));
    document.getElementById('logout-button').addEventListener('click', handleLogout);
    
    // Fullscreen and Settings buttons
    if (toggleFullscreenBtn) {
        toggleFullscreenBtn.addEventListener('click', toggleFullScreen);
    }
    if (settingsBtn) {
        settingsBtn.addEventListener('click', () => toggleSettingsPanel());
    }

    // Settings panel dropdowns (language & theme) - Event delegation for options
    if (languageOptions) {
        languageOptions.addEventListener('click', (e) => {
            const option = e.target.closest('.option-item');
            if (option && option.dataset.lang) {
                switchLanguage(option.dataset.lang);
                toggleSettingsDropdown(languageGroup); // Close dropdown
            }
        });
    }

    if (themeOptions) {
        themeOptions.addEventListener('click', (e) => {
            const option = e.target.closest('.option-item');
            if (option && option.dataset.theme) {
                applyTheme(option.dataset.theme);
                toggleSettingsDropdown(themeGroup); // Close dropdown
            }
        });
    }

    // Event listeners for settings dropdown controls (click on current display to open/close)
    if (currentLanguageDisplay) {
        currentLanguageDisplay.addEventListener('click', () => toggleSettingsDropdown(languageGroup));
    }
    if (currentThemeDisplay) {
        currentThemeDisplay.addEventListener('click', () => toggleSettingsDropdown(themeGroup));
    }

    // Add to cart button on item preview screen
    if (addToCartPreviewButton) {
        addToCartPreviewButton.addEventListener('click', (e) => {
            const itemId = parseInt(e.currentTarget.dataset.itemId);
            if (!isNaN(itemId)) {
                addToCart(itemId);
                setPreviewButtonState(true); // Indicate item is added
                setTimeout(() => setPreviewButtonState(false), 1500); // Reset state after 1.5s
            }
        });
    }

    // Checkout button
    if (checkoutButton) {
        checkoutButton.addEventListener('click', placeOrder);
    }

    // Order search button
    const orderSearchButton = document.getElementById('order-search-input'); // Changed to input
    if (orderSearchButton) {
        document.getElementById('order-search-button').addEventListener('click', handleOrderSearch); // Event on the button
    }
    
    // Canteen status toggle
    const canteenStatusToggle = document.getElementById('canteen-status-toggle');
    if (canteenStatusToggle) {
        canteenStatusToggle.addEventListener('change', (e) => {
            isCanteenOpen = e.target.checked;
            sendWebSocketMessage({ type: 'update_canteen_status', isOpen: isCanteenOpen });
            updateCanteenStatus();
        });
    }

    // Product management back button
    const productMgmtBackButton = document.getElementById('product-mgmt-back-button');
    if (productMgmtBackButton) {
        productMgmtBackButton.addEventListener('click', () => {
            showScreen('screen-5'); // Always go back to Order Management
        });
    }
    
    // Add New Product button
    const addNewProductButton = document.getElementById('add-new-product-button');
    if (addNewProductButton) {
        addNewProductButton.addEventListener('click', handleAddNewProduct);
    }

    // Add New Category button
    const addNewCategoryButton = document.getElementById('add-new-category-button');
    if (addNewCategoryButton) {
        addNewCategoryButton.addEventListener('click', handleAddCategory);
    }

    // Passcode modal buttons
    if (passcodeModalOk) {
        passcodeModalOk.addEventListener('click', handlePasscodeSubmit);
    }
    if (passcodeModalInput) {
        passcodeModalInput.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') {
                e.preventDefault();
                handlePasscodeSubmit();
            }
        });
    }
    if (passcodeModalCancel) {
        passcodeModalCancel.addEventListener('click', hidePasscodeModal);
    }

    // Discovery toggle from settings
    const discoveryModeToggle = document.getElementById('discovery-status-toggle');
    if (discoveryModeToggle) {
        const toggleAction = () => {
            if (isDiscoveryModeActivated) {
                isDiscoveryModeActivated = false;
                localStorage.setItem('canteenDiscoveryMode', isDiscoveryModeActivated);
                updateDiscoveryToggleVisualState();
                updateDiscoverButtonVisibility();
            } else {
                showPasscodeModal();
            }
        };
        discoveryModeToggle.addEventListener('click', toggleAction);
        discoveryModeToggle.addEventListener('keydown', (e) => {
            if (e.key === 'Enter' || e.key === ' ') {
                e.preventDefault();
                toggleAction();
            }
        });
    }
});

// Function to show a specific screen
function showScreen(screenId) {
    const screens = document.querySelectorAll('.screen');
    screens.forEach(screen => {
        screen.classList.remove('active');
    });
    const targetScreen = document.getElementById(screenId);
    if (targetScreen) {
        targetScreen.classList.add('active');
        // Update currentScreen global variable for WebSocket identification
        currentScreen = targetScreen; 
        // If transitioning to management screen, identify as management client
        if (screenId === 'screen-5' || screenId === 'screen-9') {
            identifyAsManagementClient();
        }
    }
}

// Load translations (from old script, adapted)
function loadTranslations() {
    try {
        const storedTranslations = localStorage.getItem('canteenAppTranslations'); // Updated key
        if (storedTranslations) {
            translations = JSON.parse(storedTranslations);
            updateLanguageUI();
        } else {
            console.log('Using default translations');
            translations = defaultTranslations; // Use default from this script
            saveTranslations();
        }
        isInitialTranslationsLoaded = true;
        renderInitialUIIfNeeded();
    } catch (error) {
        console.error('Error loading translations:', error);
    }
}

// Update translations (from old script, adapted)
function updateLanguageUI() {
    document.querySelectorAll('[data-lang-key]').forEach(element => {
        const key = element.dataset.langKey;
        if (translations[key] && translations[key][currentLanguage]) {
            element.textContent = translations[key][currentLanguage];
        }
    });
    // Update placeholders separately
    document.querySelectorAll('[data-lang-placeholder-key]').forEach(element => {
        const key = element.dataset.langPlaceholderKey;
        if (translations[key] && translations[key][currentLanguage]) {
            element.placeholder = translations[key][currentLanguage];
        }
    });
    // Update body language attribute
    bodyElement.setAttribute('lang', currentLanguage);
    updateLanguageDisplay(); // Update settings panel display
}

// Function to switch language (from old script)
function switchLanguage(lang) {
    if (currentLanguage !== lang) {
        currentLanguage = lang;
        localStorage.setItem('canteenAppLanguage', lang);
        updateLanguageUI();
        // Trigger a re-render of menu/products if they depend on language
        populateMenuGrid();
        populateDiscoveryMode();
        renderOrderLog(); // Re-render order log if it's open
        updateProductCategoryDropdowns(); // Update management dropdowns
        updateModalLanguage(); // Update custom alert/confirm modals
        updatePasscodeModalLanguage(); // Update passcode modal
        updateConfirmModalLanguage(); // Update confirm modal
        updateEditModalLanguage(); // Update edit product modal
        updateEditCategoryModalLanguage(); // Update edit category modal
    }
}

// Update canteen status (from old script)
function updateCanteenStatus() {
    const statusElement = document.querySelector('.canteen-status');
    if (statusElement) {
        statusElement.textContent = isCanteenOpen ? getText('canteen_status_open') : getText('canteen_status_closed');
        statusElement.className = `canteen-status ${isCanteenOpen ? 'open' : 'closed'}`;
    }
}

// Handle WebSocket messages (from old script, adapted)
function handleWebSocketMessage(data) {
    console.log('Received message:', data);
    try {
        switch (data.type) {
            case 'canteen_status':
                if (typeof data.isOpen === 'boolean') {
                    isCanteenOpen = data.isOpen;
                    updateCanteenStatus();
                    updateAdminStatusToggle(); // Update admin toggle if admin screen is loaded
                }
                break;
            case 'admin_login_success':
                isManagementClient = true;
                showScreen('screen-5'); // Go to order management screen
                break;
            case 'admin_login_error':
                showError(getText('admin_login_error'));
                break;
            case 'initial_products':
                if (Array.isArray(data.payload)) {
                    baseMenuData = data.payload;
                    isInitialProductsLoaded = true;
                    renderInitialUIIfNeeded();
                    populateMenuGrid(); // Ensure grid is populated after data
                } else {
                    console.error('Received non-array payload for initial_products:', data.payload);
                }
                break;
            case 'initial_categories':
                if (Array.isArray(data.payload)) {
                    categories = data.payload;
                    isInitialCategoriesLoaded = true;
                    renderInitialUIIfNeeded();
                    renderCategoryList(); // Ensure category list is populated
                } else {
                    console.error('Received non-array payload for initial_categories:', data.payload);
                }
                break;
            case 'initial_translations':
                 if (data.payload && typeof data.payload === 'object') {
                    for (const key in data.payload) {
                        if (data.payload.hasOwnProperty(key)) {
                            const incomingValue = data.payload[key];
                            if (translations.hasOwnProperty(key) && typeof translations[key] === 'object') {
                                if (typeof incomingValue === 'object') {
                                    Object.assign(translations[key], incomingValue);
                                } else {
                                    console.warn(`[initial_translations] Ignoring update for key '${key}' because existing is object but incoming is not. Incoming:`, incomingValue);
                                }
                            } else {
                                if (typeof incomingValue === 'object' || typeof incomingValue === 'string') {
                                    translations[key] = incomingValue;
                                } else {
                                    console.warn(`[initial_translations] Ignoring update for new/non-object key '${key}' because incoming type is not object/string. Incoming:`, incomingValue);
                                }
                            }
                        }
                    }
                    saveTranslations();
                    isInitialTranslationsLoaded = true;
                    updateLanguageUI();
                    renderInitialUIIfNeeded();
                 } else {
                     console.warn('Received invalid payload for initial_translations:', data.payload);
                 }
                 break;
            case 'initial_canteen_status':
                if (data.payload && typeof data.payload.isOpen === 'boolean') {
                    isCanteenOpen = data.payload.isOpen;
                    updateCanteenStatus();
                    updateAdminStatusToggle();
                } else {
                    console.warn('Invalid initial_canteen_status payload:', data.payload);
                }
                break;
            case 'initial_orders':
                if (isManagementClient) {
                    allOrders = data.payload;
                    renderOrderLog(allOrders);
                    if (currentAdminOrderSelection) {
                        showOrderDetails(currentAdminOrderSelection);
                    } else {
                        clearOrderPreview();
                    }
                }
                break;
            case 'new_order':
                if (isManagementClient) {
                    const newOrder = data.payload;
                    const existingOrderIndex = allOrders.findIndex(order => order.id === newOrder.id);
                    if (existingOrderIndex === -1) {
                        allOrders.unshift(newOrder);
                    }
                    renderOrderLog(allOrders);
                }
                break;
            case 'order_status_updated_broadcast':
                if (isManagementClient) {
                    const { orderId, updatedOrder } = data.payload;
                    if (updatedOrder) {
                        const orderIndex = allOrders.findIndex(o => o.id === orderId);
                        if (orderIndex !== -1) {
                            allOrders[orderIndex] = updatedOrder;
                            renderOrderLog();
                            if (currentAdminOrderSelection === orderId) {
                                showOrderDetails(orderId);
                            }
                        }
                    }
                }
                break;
            case 'product_updated_broadcast':
            case 'product_added_broadcast':
            case 'product_deleted_broadcast':
                if (data.payload) {
                    // Update baseMenuData based on broadcast
                    if (data.type === 'product_added_broadcast') {
                        baseMenuData.push(data.payload);
                    } else if (data.type === 'product_updated_broadcast') {
                        const index = baseMenuData.findIndex(p => p.id === data.payload.id);
                        if (index !== -1) baseMenuData[index] = data.payload;
                    } else if (data.type === 'product_deleted_broadcast') {
                        baseMenuData = baseMenuData.filter(p => p.id !== data.payload.id);
                    }
                    populateMenuGrid(); // Refresh public menu
                    updateProductCategoryDropdowns(); // Refresh admin product dropdowns
                    // If in product management screen, re-render the view
                    if (currentScreen?.id === 'screen-9' && currentProductMgmtCategory) {
                        renderProductGridForCategory(currentProductMgmtCategory);
                    }
                }
                break;
            case 'category_updated_broadcast':
            case 'category_added_broadcast':
            case 'category_deleted_broadcast':
            case 'categories_reordered_broadcast':
                if (data.payload) {
                    categories = data.payload; // Categories array is usually sent fully
                    renderCategoryList(); // Refresh category list
                    populateSortButtons(); // Refresh menu sort buttons
                    populateMenuGrid(); // Refresh menu grid
                    updateProductCategoryDropdowns(); // Refresh product dropdowns
                }
                break;
            default:
                console.log('Unknown message type:', data.type);
        }
    } catch (error) {
        console.error('Error handling WebSocket message:', error);
        showError('Error processing server response');
    }
}

// WebSocket connection (adapted from old script)
function connectWebSocket() {
    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const wsUrl = `${protocol}//${window.location.host}/ws`; // Use current host
    ws = new WebSocket(wsUrl);
    
    ws.onopen = () => {
        console.log('WebSocket connected');
        sendWebSocketMessage({ type: 'request_initial_data' }); // Request all initial data
        // If this is the management screen, identify itself
        if (currentScreen && (currentScreen.id === 'screen-5' || currentScreen.id === 'screen-9')) {
             identifyAsManagementClient();
        }
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

// Login, Register, Admin Login Handlers (adapted)
function handleLogin() {
    const email = document.getElementById('login-email').value;
    const password = document.getElementById('login-password').value;
    const loginError = document.getElementById('login-error');

    if (email && password) {
        // Send login credentials via WebSocket
        sendWebSocketMessage({
            type: 'user_login', // Changed to user_login for clarity
            email: email,
            password: password
        });
        // Dummy client-side login for now, if no server response
        if (email === 'user@canteen.app' && password === 'user123') {
            currentUser = { email: email, profilePic: 'https://via.placeholder.com/150' }; // Dummy user
            localStorage.setItem('canteenAppCurrentUser', JSON.stringify(currentUser));
            loginError.style.display = 'none';
            showScreen('screen-3'); // Go to menu screen
            updateUserInfoUI();
        } else {
            loginError.textContent = getText('login_error_invalid');
            loginError.style.display = 'block';
        }

    } else {
        loginError.textContent = 'Please enter email and password';
        loginError.style.display = 'block';
    }
}

function handleRegister() {
    const email = document.getElementById('register-email').value;
    const password = document.getElementById('register-password').value;
    const confirmPassword = document.getElementById('register-password-confirm').value;
    const registerError = document.getElementById('register-error');

    if (password !== confirmPassword) {
        registerError.textContent = getText('register_error_match');
        registerError.style.display = 'block';
    } else if (!email || !password) {
        registerError.textContent = 'Please fill all fields';
        registerError.style.display = 'block';
    } else {
        // Send registration data via WebSocket
        sendWebSocketMessage({
            type: 'register_user',
            email: email,
            password: password,
            profilePic: document.querySelector('.profile-pic.active')?.src || 'https://i.postimg.cc/XYGqh5B2/IMG.png'
        });
        // Dummy client-side registration
        registerError.style.display = 'none';
        alert('Registration successful (dummy)! Please login.');
        showScreen('screen-1'); // Go back to login screen
    }
}

function handleAdminLogin() {
    const email = document.getElementById('admin-email').value;
    const password = document.getElementById('admin-password').value;
    const adminLoginError = document.getElementById('admin-login-error');

    if (email && password) {
        sendWebSocketMessage({
            type: 'admin_login',
            email: email,
            password: password
        });
    } else {
        adminLoginError.textContent = 'Please enter admin email and password.';
        adminLoginError.style.display = 'block';
    }
}

function handleLogout() {
    currentUser = null;
    localStorage.removeItem('canteenAppCurrentUser');
    isManagementClient = false;
    showScreen('screen-1');
    updateUserInfoUI();
    console.log('User logged out.');
}

// Fullscreen Toggle (from old script)
function toggleFullScreen() {
    if (!document.fullscreenElement) {
        document.documentElement.requestFullscreen().then(() => {
            bodyElement.classList.add('full-screen-mode');
        }).catch(err => {
            console.error(`Error attempting to enable full-screen mode: ${err.message} (${err.name})`);
        });
    } else {
        document.exitFullscreen().then(() => {
            bodyElement.classList.remove('full-screen-mode');
        }).catch(err => {
            console.error(`Error attempting to exit full-screen mode: ${err.message} (${err.name})`);
        });
    }
}

// Settings Panel (from old script, adapted)
function toggleSettingsPanel(show) {
    if (!settingsPanel) return;
    const isVisible = settingsPanel.classList.contains('visible');
    if (typeof show === 'boolean') {
        if (show && !isVisible) {
            settingsPanel.classList.add('visible');
            document.addEventListener('click', handleOutsideSettingsClick, true);
            updateSettingsDisplays();
        } else if (!show && isVisible) {
            closeAllSettingsDropdowns();
            settingsPanel.classList.remove('visible');
            document.removeEventListener('click', handleOutsideSettingsClick, true);
        }
    } else {
        toggleSettingsPanel(!isVisible);
    }
}

function handleOutsideSettingsClick(e) {
    if (settingsPanel && !settingsPanel.contains(e.target) && settingsBtn && !settingsBtn.contains(e.target)) {
        toggleSettingsPanel(false);
    } else {
        const isDropdownControl = currentLanguageDisplay?.contains(e.target) || currentThemeDisplay?.contains(e.target);
        const isDropdownList = languageOptions?.contains(e.target) || themeOptions?.contains(e.target);
        if (settingsPanel && settingsPanel.contains(e.target) && !isDropdownControl && !isDropdownList) {
            closeAllSettingsDropdowns();
        }
    }
}

function toggleSettingsDropdown(group) {
    if (!group) return;
    const isOpen = group.classList.contains('open');
    const displayElement = group.querySelector('.settings-current-display');
    
    // Close other dropdown if open
    document.querySelectorAll('.settings-group.open').forEach(g => {
        if (g !== group) {
            g.classList.remove('open', 'open-upward');
            const d = g.querySelector('.settings-current-display');
            if (d) d.setAttribute('aria-expanded', 'false');
        }
    });

    if (!isOpen) { // Open dropdown
        // Check if there's enough space downwards, otherwise open upwards
        const rect = displayElement.getBoundingClientRect();
        const spaceBelow = window.innerHeight - rect.bottom - 10; // 10px margin
        const spaceAbove = rect.top - 10;
        const dropdownHeight = 150; // Approximate height of the dropdown list

        if (spaceBelow < dropdownHeight && spaceAbove > spaceBelow) {
            group.classList.add('open-upward');
        } else {
            group.classList.remove('open-upward');
        }
        group.classList.add('open');
        if (displayElement) displayElement.setAttribute('aria-expanded', 'true');
    } else { // Close dropdown
        group.classList.remove('open', 'open-upward');
        if (displayElement) displayElement.setAttribute('aria-expanded', 'false');
    }
}

function closeAllSettingsDropdowns() {
    document.querySelectorAll('.settings-group.open').forEach(group => {
        group.classList.remove('open', 'open-upward');
        const displayElement = group.querySelector('.settings-current-display');
        if (displayElement) displayElement.setAttribute('aria-expanded', 'false');
    });
}


function updateLanguageDisplay() {
    const selectedOption = languageOptions?.querySelector(`.option-item[data-lang="${currentLanguage}"]`);
    if (selectedOption && currentLanguageText) {
        currentLanguageText.textContent = selectedOption.querySelector('span').textContent;
        languageOptions?.querySelectorAll('.option-item').forEach(item => {
            const isActive = item.dataset.lang === currentLanguage;
            item.classList.toggle('active', isActive);
            item.setAttribute('aria-selected', isActive);
        });
    }
}

function updateThemeDisplay() {
    const selectedOption = themeOptions?.querySelector(`.option-item[data-theme="${currentTheme}"]`);
    if (selectedOption) {
        // Update display text (if any, e.g., 'Blue Theme')
        // Update theme swatches visibility if needed
        themeOptions?.querySelectorAll('.option-item').forEach(item => {
            const isActive = item.dataset.theme === currentTheme;
            item.classList.toggle('active', isActive);
            item.setAttribute('aria-selected', isActive);
        });
    }
}

function updateSettingsDisplays() {
    updateLanguageDisplay();
    updateThemeDisplay();
    // updateDiscoveryToggleVisualState(); // If discovery toggle exists
}

function applyTheme(themeName) {
    console.log("Applying theme:", themeName);
    bodyElement.dataset.theme = themeName;
    currentTheme = themeName;
    localStorage.setItem('canteenAppTheme', themeName);
    if (settingsPanel) updateThemeDisplay();
}

// Show admin panel (already exists)
function showAdminPanel() {
    const adminPanel = document.querySelector('.admin-panel');
    if (adminPanel) {
        adminPanel.style.display = 'block';
    }
}

// Show error message (already exists)
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


// Load orders (already exists)
function loadOrders() {
    try {
        const storedOrders = localStorage.getItem('canteenAppOrders'); // Updated key
        if (storedOrders) {
            allOrders = JSON.parse(storedOrders); // Direct assignment
            updateOrdersDisplay(allOrders); // Ensure display is updated
        } else {
            allOrders = []; // Initialize as empty array if nothing in localStorage
        }
    } catch (error) {
        console.error('Error loading orders:', error);
    }
}


// Update orders display (already exists)
function updateOrdersDisplay(orders) {
    const ordersContainer = document.querySelector('.orders-container');
    if (ordersContainer) {
        if (orders.length === 0) {
            ordersContainer.innerHTML = `<p class="no-orders-message">${getText('no_orders_message') || 'No orders yet.'}</p>`;
            return;
        }
        ordersContainer.innerHTML = orders.map(order => `
                <div class="order-item">
                    <h3>Order #${order.id}</h3>
                    <p>Total: ${order.total} ${getText('currency')}</p>
                </div>
            `).join('');
    }
}

// Load products (already exists, adapted)
function loadProducts() {
    try {
        const storedProducts = localStorage.getItem('canteenAppProductsData_v2'); // Updated key
        if (storedProducts) {
            baseMenuData = JSON.parse(storedProducts);
            populateMenuGrid(); // Populate after loading
        } else {
            console.log('Using default products');
            baseMenuData = defaultProducts; // Use default from this script
            saveProducts();
        }
        isInitialProductsLoaded = true;
        renderInitialUIIfNeeded();
    } catch (error) {
        console.error('Error loading products:', error);
    }
}

// Update products display / Populate Menu Grid (from old script, adapted)
function populateMenuGrid() {
    const productsContainer = document.querySelector('.products-container');
    if (productsContainer) {
        productsContainer.innerHTML = baseMenuData.map(product => `
            <div class="product-card" data-product-id="${product.id}">
                <img src="${product.image}" alt="${product.name[currentLanguage] || product.name.en}" onerror="this.src='https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=220&h=165&fit=crop'">
                <h3>${product.name[currentLanguage] || product.name.en}</h3>
                <p>${product.description[currentLanguage] || product.description.en}</p>
                <p class="price">${product.price} ${getText('currency')}</p>
                <button onclick="addToCart(${product.id})">${getText('add_to_cart_button')}</button>
            </div>
        `).join('');
        // Add event listeners to product cards for item preview
        productsContainer.querySelectorAll('.product-card').forEach(card => {
            card.addEventListener('click', (e) => {
                // Only trigger preview if not clicking the button inside
                if (!e.target.closest('button')) {
                    const productId = parseInt(card.dataset.productId);
                    if (!isNaN(productId)) {
                        showItemPreview(productId);
                    }
                }
            });
        });
    }
}

// Function to add item to cart (from old script)
function addToCart(productId) {
    const product = baseMenuData.find(p => p.id === productId);
    if (!product) return;

    const existingCartItem = cart.find(item => item.id === productId);
    if (existingCartItem) {
        existingCartItem.quantity++;
    } else {
        cart.push({ id: productId, quantity: 1 });
    }
    updateCartUI();
    saveCart();
}

// Function to remove item from cart (from old script)
function removeFromCart(productId) {
    cart = cart.filter(item => item.id !== productId);
    updateCartUI();
    saveCart();
}

// Update Cart UI (from old script)
function updateCartUI() {
    const cartItemsContainer = document.getElementById('cart-items-container');
    const totalCalculationDetails = document.getElementById('total-calculation-details');
    const checkoutButton = document.getElementById('checkout-button');
    let total = 0;

    if (cartItemsContainer) {
        if (cart.length === 0) {
            cartItemsContainer.innerHTML = `<p class="empty-cart-message">${getText('empty_cart_message') || 'Cart is empty!'}</p>`;
            totalCalculationDetails.innerHTML = '';
            if (checkoutButton) checkoutButton.textContent = `0 ${getText('currency')}`;
            updateCartBadge();
            return;
        }

        cartItemsContainer.innerHTML = cart.map(item => {
            const product = baseMenuData.find(p => p.id === item.id);
            if (!product) return '';
            const itemTotal = product.price * item.quantity;
            total += itemTotal;
            return `
                <div class="cart-item">
                    <img src="${product.image}" alt="${product.name[currentLanguage] || product.name.en}">
                    <div class="item-details">
                        <div class="item-info">
                            <p>${product.name[currentLanguage] || product.name.en}</p>
                            <span class="item-quantity">x${item.quantity}</span>
                        </div>
                        <button class="item-price-button">${itemTotal} ${getText('currency')}</button>
                    </div>
                    <button class="remove-item-button" onclick="removeFromCart(${product.id})"><i class="fas fa-times"></i></button>
                </div>
            `;
        }).join('');
    }

    if (totalCalculationDetails) {
        totalCalculationDetails.innerHTML = cart.map(item => {
            const product = baseMenuData.find(p => p.id === item.id);
            if (!product) return '';
            return `<p>${product.name[currentLanguage] || product.name.en} (${item.quantity}x) = ${product.price * item.quantity} ${getText('currency')}</p>`;
        }).join('');
    }

    if (checkoutButton) {
        checkoutButton.textContent = `${total} ${getText('currency')}`;
    }
    updateCartBadge();
}

// Save cart to local storage (from old script)
function saveCart() {
    localStorage.setItem('canteenAppCart', JSON.stringify(cart));
}

// Place order (from old script, dummy)
function placeOrder() {
    if (cart.length === 0) {
        showError('Cart is empty!');
        return;
    }
    // Dummy order placement
    showCustomAlert(getText('checkout_success_message'), getText('checkout_success_title'), 3000);
    cart = []; // Clear cart after placing order
    saveCart();
    updateCartUI(); // Update UI to reflect empty cart
    // In a real app, send order to server via WebSocket
    sendWebSocketMessage({ type: 'new_order', payload: { /* order data */ } });
}

// Update cart badge (from old script)
function updateCartBadge() {
    const badge = document.getElementById('cart-badge');
    const badgePreview = document.getElementById('cart-badge-preview');
    const totalItems = cart.reduce((sum, item) => sum + item.quantity, 0);

    if (badge) {
        badge.textContent = totalItems;
        badge.classList.toggle('visible', totalItems > 0);
    }
    if (badgePreview) {
        badgePreview.textContent = totalItems;
        badgePreview.classList.toggle('visible', totalItems > 0);
    }
}


// Other helper functions from old script.js (getText, getCurrency, formatPrice, etc.)
function getText(key, specificLang = null) {
    const lang = specificLang || currentLanguage;
    return translations[key]?.[lang] || defaultTranslations[key]?.[lang] || `[${key}]`;
}

function getCurrency() { return getText('currency'); }
function formatPrice(p) { return `${p} ${getCurrency()}`; }

// Update user info UI (from old script)
function updateUserInfoUI() {
    const storedUser = localStorage.getItem('canteenAppCurrentUser'); // Updated key
    currentUser = storedUser ? JSON.parse(storedUser) : null;

    if (currentUser) {
        const username = currentUser.email.split('@')[0];
        if(userDisplayName) userDisplayName.textContent = `@${username}`;
        if(userProfileImage) {
            userProfileImage.src = currentUser.profilePic || 'https://i.postimg.cc/XYGqh5B2/IMG.png'; // Fallback to default
            userProfileImage.alt = `${username}'s PP`;
            userProfileImage.style.display = 'block';
        }
        if(guestUserIcon) guestUserIcon.style.display = 'none';
    } else {
        if(userDisplayName) userDisplayName.textContent = '@guest';
        if(userProfileImage) {
            userProfileImage.src = '';
            userProfileImage.alt = 'User Profile';
            userProfileImage.style.display = 'none';
        }
        if(guestUserIcon) guestUserIcon.style.display = 'block';
    }
}

// Show item preview (from old script, adapted)
function showItemPreview(id, navigateToScreen = true) {
    const product = baseMenuData.find(p => p.id === id);
    if (!product || !document.getElementById('preview-item-image') || !document.getElementById('preview-item-name') || !document.getElementById('preview-item-description') || !document.getElementById('preview-item-price') || !addToCartPreviewButton) return;

    document.getElementById('preview-item-image').src = product.image;
    document.getElementById('preview-item-name').textContent = product.name[currentLanguage] || product.name.en;
    document.getElementById('preview-item-description').textContent = product.description[currentLanguage] || product.description.en;
    document.getElementById('preview-item-price').textContent = `${product.price} ${getText('currency')}`;
    addToCartPreviewButton.dataset.itemId = product.id;
    
    // Check if item is already in cart and update button state
    const isInCart = cart.some(item => item.id === product.id);
    setPreviewButtonState(isInCart);

    if (navigateToScreen) {
        showScreen('screen-7'); // Show item preview screen
    }
    updateCartBadge(); // Ensure cart badge is updated
}

// Set preview button state (from old script)
function setPreviewButtonState(isAdded) {
    if (!addToCartPreviewButton) return;
    addToCartPreviewButton.classList.toggle('added', isAdded);
    const buttonTextKey = isAdded ? 'added_to_cart_button' : 'add_to_cart_button';
    const buttonIconClass = isAdded ? 'fas fa-check' : 'fas fa-cart-plus';

    let span = addToCartPreviewButton.querySelector('span');
    if (!span) { span = document.createElement('span'); addToCartPreviewButton.appendChild(span); }
    span.dataset.langKey = buttonTextKey;
    span.textContent = getText(buttonTextKey);

    let icon = addToCartPreviewButton.querySelector('i');
    if (!icon) { icon = document.createElement('i'); addToCartPreviewButton.prepend(icon); }
    icon.className = buttonIconClass;
}

// Reset preview button state (from old script)
function resetPreviewButtonState() {
    setPreviewButtonState(false);
}

// Custom Alert/Confirm Modals (from old script)
function updateModalLanguage() {
    if (customAlertTitle) customAlertTitle.textContent = getText(customAlertTitle.dataset.langKey || 'checkout_success_title');
    if (customAlertCloseBtn) customAlertCloseBtn.textContent = getText('ok_button');
    
    if (customConfirmTitle) customConfirmTitle.textContent = getText(customConfirmTitle.dataset.langKey || 'confirm_action_title');
    if (customConfirmOkButton) customConfirmOkButton.textContent = getText(customConfirmOkButton.dataset.langKey || 'confirm_button');
    if (customConfirmCancelButton) customConfirmCancelButton.textContent = getText(customConfirmCancelButton.dataset.langKey || 'cancel_button');
}

function showCustomAlert(message, titleKey = 'checkout_success_title', autoHideDelay = null) {
    if (!customAlertOverlay || !customAlertTitle || !customAlertMessage || !customAlertCloseBtn) return;
    
    customAlertTitle.dataset.langKey = titleKey; // Set data-lang-key for translation
    updateModalLanguage(); // Apply translation
    customAlertMessage.textContent = message;

    customAlertOverlay.classList.add('visible');
    customAlertCloseBtn.focus();

    const closeHandler = () => {
        hideCustomAlert();
        customAlertCloseBtn.removeEventListener('click', closeHandler);
    };
    customAlertCloseBtn.addEventListener('click', closeHandler);

    if (autoHideDelay) {
        setTimeout(hideCustomAlert, autoHideDelay);
    }
}

function hideCustomAlert() {
    if (customAlertOverlay) customAlertOverlay.classList.remove('visible');
}

function showCustomConfirm(message, titleKey = 'confirm_action_title', confirmButtonKey = 'confirm_button', cancelButtonKey = 'cancel_button', onConfirm, onCancel) {
    if (!customConfirmOverlay || !customConfirmTitle || !customConfirmMessage || !customConfirmOkButton || !customConfirmCancelButton) return;

    customConfirmTitle.dataset.langKey = titleKey;
    customConfirmOkButton.dataset.langKey = confirmButtonKey;
    customConfirmCancelButton.dataset.langKey = cancelButtonKey;
    updateModalLanguage(); // Translate buttons
    customConfirmMessage.textContent = message;

    customConfirmOverlay.classList.add('visible');
    customConfirmOkButton.focus();

    const handleConfirm = () => {
        hideCustomConfirm();
        onConfirm();
        customConfirmOkButton.removeEventListener('click', handleConfirm);
        customConfirmCancelButton.removeEventListener('click', handleCancel);
    };
    const handleCancel = () => {
        hideCustomConfirm();
        if (onCancel) onCancel();
        customConfirmOkButton.removeEventListener('click', handleConfirm);
        customConfirmCancelButton.removeEventListener('click', handleCancel);
    };

    customConfirmOkButton.addEventListener('click', handleConfirm);
    customConfirmCancelButton.addEventListener('click', handleCancel);
}

function hideCustomConfirm() {
    if (customConfirmOverlay) customConfirmOverlay.classList.remove('visible');
}

// Dummy Passcode Modal (from old script) - will be implemented if needed
function updatePasscodeModalLanguage() {
    if(passcodeModalTitle) passcodeModalTitle.textContent = getText('discovery_passcode_modal_title');
    if(passcodeModalInput) passcodeModalInput.placeholder = getText('discovery_passcode_prompt');
    if(passcodeModalError) passcodeModalError.textContent = getText('discovery_passcode_incorrect_message');
    if(passcodeModalOk) passcodeModalOk.textContent = getText('ok_button');
    if(passcodeModalCancel) passcodeModalCancel.textContent = getText('cancel_button');
}

function showPasscodeModal() { 
    if (!passcodeModalOverlay) return; 
    updatePasscodeModalLanguage(); 
    if(passcodeModalInput) passcodeModalInput.value = ''; 
    if(passcodeModalError) passcodeModalError.style.display = 'none'; 
    requestAnimationFrame(() => { 
        passcodeModalOverlay.classList.add('visible'); 
        if(passcodeModalInput) passcodeModalInput.focus(); 
    }); 
}

function hidePasscodeModal() { 
    if (!passcodeModalOverlay) return; 
    passcodeModalOverlay.classList.remove('visible'); 
}

function handlePasscodeSubmit() {
    const passcode = passcodeModalInput.value;
    const DISCOVERY_PASSCODE = '1234'; // Define passcode here for client-side
    if (passcode === DISCOVERY_PASSCODE) {
        hidePasscodeModal();
        isDiscoveryModeActivated = true;
        localStorage.setItem('canteenDiscoveryMode', isDiscoveryModeActivated);
        updateDiscoveryToggleVisualState();
        updateDiscoverButtonVisibility();
        populateDiscoveryMode(); // Load discovery mode content
        showScreen('screen-8'); // Show discovery screen
    } else {
        passcodeModalError.style.display = 'block';
    }
}

// Initial Passcode Modal setup (event listeners)
if (passcodeModalOk) {
    passcodeModalOk.addEventListener('click', handlePasscodeSubmit);
}
if (passcodeModalInput) {
    passcodeModalInput.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') {
            e.preventDefault();
            handlePasscodeSubmit();
        }
    });
}
if (passcodeModalCancel) {
    passcodeModalCancel.addEventListener('click', hidePasscodeModal);
}
// Discovery toggle from settings (from old script)
// Assuming discoveryModeToggle exists somewhere in your HTML, add this logic:
const discoveryModeToggle = document.getElementById('discovery-status-toggle'); // Example ID
if (discoveryModeToggle) {
    const toggleAction = () => {
        if (isDiscoveryModeActivated) {
            isDiscoveryModeActivated = false;
            localStorage.setItem('canteenDiscoveryMode', isDiscoveryModeActivated);
            updateDiscoveryToggleVisualState();
            updateDiscoverButtonVisibility();
        } else {
            showPasscodeModal();
        }
    };
    discoveryModeToggle.addEventListener('click', toggleAction);
    discoveryModeToggle.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' || e.key === ' ') {
            e.preventDefault();
            toggleAction();
        }
    });
}

function updateDiscoveryToggleVisualState() {
    if (discoveryModeToggle) {
        discoveryModeToggle.checked = isDiscoveryModeActivated; // Set checkbox state
    }
}

function updateDiscoverButtonVisibility() {
    if (discoverButton) {
        discoverButton.style.display = isDiscoveryModeActivated ? 'inline-flex' : 'none';
    }
}


// Save/Load functions (from old script)
function saveTranslations() { try { localStorage.setItem('canteenAppTranslations', JSON.stringify(translations)); } catch (e) { console.error("Error saving translations:", e); } }
function saveProducts() { try { localStorage.setItem('canteenAppProductsData_v2', JSON.stringify(baseMenuData)); } catch (e) { console.error("Error saving products:", e); } }
function saveOrders() { try { localStorage.setItem('canteenAppOrders', JSON.stringify(allOrders)); } catch (e) { console.error("Error saving orders:", e); } }
function saveCategories() { try { localStorage.setItem('canteenAppCategories_v2', JSON.stringify(categories)); } catch (e) { console.error("Error saving categories:", e); } }

// Dummy functions for placeholders that exist in old script but not yet fully integrated/needed
function updateAdminStatusToggle() {
    const toggle = document.getElementById('canteen-status-toggle');
    if (toggle) {
        toggle.checked = isCanteenOpen;
    }
}
function updateProductCategoryDropdowns() {
    // This function would populate dropdowns in product management
    console.log('updateProductCategoryDropdowns called (dummy)');
}
function renderCategoryList() {
    // This function would render categories in management
    console.log('renderCategoryList called (dummy)');
}
function renderProductGridForCategory(categoryKey) {
    // This function would render products in a category in management
    console.log('renderProductGridForCategory called (dummy for:', categoryKey);
}
function handleAddNewProduct() {
    console.log('handleAddNewProduct called (dummy)');
    showCustomAlert('Add New Product functionality not yet implemented.', 'Feature Coming Soon');
}
function handleAddCategory() {
    console.log('handleAddCategory called (dummy)');
    showCustomAlert('Add Category functionality not yet implemented.', 'Feature Coming Soon');
}

function renderOrderLog(ordersToRender = null, viewModeToUse = 'current') {
    console.log('renderOrderLog called (dummy)');
    // This function would render the orders in the admin log
    // For now, just clear or show dummy message
    if (orderLogContainer) {
        orderLogContainer.innerHTML = `<p>${getText('no_orders_message') || 'No orders yet.'}</p>`;
    }
}

function clearOrderPreview() {
    if(!orderPreviewContent || !orderStatusControls) return;
    orderPreviewContent.innerHTML = `<p class="order-preview-placeholder">${getText('order_preview_placeholder')}</p>`;
    orderStatusControls.innerHTML = '';
    currentAdminOrderSelection = null;
    orderLogContainer?.querySelectorAll('.order-log-item.active').forEach(i => i.classList.remove('active'));
}

function showOrderDetails(id) {
    console.log('showOrderDetails called (dummy for:', id, ')');
    showCustomAlert('Order Details functionality not yet implemented.', 'Feature Coming Soon');
}

function handleOrderSearch() {
    console.log('handleOrderSearch called (dummy)');
    showCustomAlert('Order Search functionality not yet implemented.', 'Feature Coming Soon');
}

function populateSortButtons() {
    console.log('populateSortButtons called (dummy)');
    const sortButtonsContainer = document.getElementById('menu-sort-buttons');
    if (sortButtonsContainer) {
        sortButtonsContainer.innerHTML = ''; // Clear existing
        // Add "All" button
        const allBtn = document.createElement('button');
        allBtn.className = 'sort-button active';
        allBtn.dataset.category = 'all';
        allBtn.textContent = 'All'; // Should be translated
        allBtn.addEventListener('click', () => {
            sortButtonsContainer.querySelectorAll('.sort-button').forEach(btn => btn.classList.remove('active'));
            allBtn.classList.add('active');
            applyFilter('all');
        });
        sortButtonsContainer.appendChild(allBtn);

        // Add category buttons
        categories.forEach(category => {
            const btn = document.createElement('button');
            btn.className = 'sort-button';
            btn.dataset.category = category.key;
            btn.textContent = category.name[currentLanguage] || category.name.en; // Should be translated
            btn.addEventListener('click', () => {
                sortButtonsContainer.querySelectorAll('.sort-button').forEach(b => b.classList.remove('active'));
                btn.classList.add('active');
                applyFilter(category.key);
            });
            sortButtonsContainer.appendChild(btn);
        });
    }
}
function applyFilter(categoryKey) {
    const productsContainer = document.querySelector('.products-container');
    if (productsContainer) {
        productsContainer.querySelectorAll('.product-card').forEach(card => {
            const product = baseMenuData.find(p => p.id === parseInt(card.dataset.productId));
            if (product) {
                if (categoryKey === 'all' || product.category === categoryKey) {
                    card.style.display = 'flex'; // Show
                } else {
                    card.style.display = 'none'; // Hide
                }
            }
        });
    }
}
function populateDiscoveryMode() {
    console.log('populateDiscoveryMode called (dummy)');
    // Dummy implementation for discovery mode content
    const bundlesScroller = document.getElementById('discovery-bundles-scroller');
    if (bundlesScroller) {
        bundlesScroller.innerHTML = `<p>${getText('no_bundles_message') || 'No special bundles yet.'}</p>`;
    }
    const suggestionsGrid = document.getElementById('discovery-suggestions-grid');
    if (suggestionsGrid) {
        suggestionsGrid.innerHTML = `<p>${getText('no_suggestions_message') || 'No meal ideas yet.'}</p>`;
    }
    const categoriesContainer = document.getElementById('discovery-categories-container');
    if (categoriesContainer) {
        categoriesContainer.innerHTML = `<p>${getText('no_categories_message') || 'No categories to explore.'}</p>`;
    }
}
function updateModalLanguage() {
    // Already defined above. This is a duplicate.
}
function updateConfirmModalLanguage() {
    // Already defined above. This is a duplicate.
}
function updateEditModalLanguage() {
    console.log('updateEditModalLanguage called (dummy)');
}
function updateEditCategoryModalLanguage() {
    console.log('updateEditCategoryModalLanguage called (dummy)');
}
