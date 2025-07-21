let connectingScreenEverTimedOut = false;
document.addEventListener('DOMContentLoaded', () => {

    setTimeout(() => {
        const loader = document.getElementById('loader-overlay');
        if (loader) loader.remove();
    }, 5000);
    // --- Cookie Helpers ---
    function setCookie(name, value, days) {
        let expires = '';
        if (days) {
            const date = new Date();
            date.setTime(date.getTime() + (days*24*60*60*1000));
            expires = '; expires=' + date.toUTCString();
        }
        document.cookie = name + '=' + encodeURIComponent(value) + expires + '; path=/';
        console.log('[setCookie]', name, value, days, '->', document.cookie);
    }
    function getCookie(name) {
        const nameEQ = name + '=';
        const ca = document.cookie.split(';');
        for(let i=0;i < ca.length;i++) {
            let c = ca[i];
            while (c.charAt(0)==' ') c = c.substring(1,c.length);
            if (c.indexOf(nameEQ) == 0) return decodeURIComponent(c.substring(nameEQ.length,c.length));
        }
        return null;
    }
    function eraseCookie(name) {
        document.cookie = name+'=; Max-Age=-99999999; path=/';
    }

    // --- On page load, check for user cookie ---
    let currentUser = null;
    let previousScreenId = null;
    const userCookie = getCookie('canteenUser');
    console.log('[auto-login] userCookie:', userCookie);
    if (userCookie) {
        try {
            const userObj = JSON.parse(userCookie);
            if (userObj && userObj.email) {
                currentUser = userObj;
                console.log('[auto-login] currentUser set from cookie:', currentUser);
            }
        } catch (e) { console.log('[auto-login] error parsing cookie', e); }
    }

    // --- Constants & State ---
    const LS_KEYS = {
        LANGUAGE: 'canteenAppLanguage',
        THEME: 'canteenAppTheme',
        CURRENT_USER: 'canteenAppCurrentUser',
        CART: 'canteenAppCart',
        ORDERS: 'canteenAppOrders',
        PRODUCTS: 'canteenAppProductsData_v2', // Updated key for new structure
        CATEGORIES: 'canteenAppCategories_v2', // Updated key for new structure
        LAST_ORDER_DATE: 'canteenAppLastOrderDate',
        LAST_ORDER_SEQUENCE: 'canteenAppLastOrderSequence',
        ADMIN_LOGGED_IN: 'canteenAdminLoggedIn_v2', // Updated for clarity
        DISCOVERY_MODE: 'canteenDiscoveryMode',
        CANTEEN_OPEN: 'canteenIsOpen_v2' // For server-driven status
    };
    // --- User Profile Pictures Mapping ---
    const PROFILE_PICS = {
      pic1: "https://i.postimg.cc/6pkqNQdB/file-000000005f5052309370194ce0d09274-conversation-id-67e85992-b064-8005-abf6-a96aee541aaf-message-i.png",
      pic2: "IMG.png",
      pic3: "https://i.postimg.cc/sXy2v068/file-000000000cb852309a865637b17bf852-conversation-id-67e85992-b064-8005-abf6-a96aee541aaf-message-i.png"
    };
    const DEFAULT_PROFILE_PIC = PROFILE_PICS.pic2;
    // REMOVED: Hardcoded admin credentials
    // const ADMIN_EMAIL = "admin@canteen.app";

    let currentScreen = null; // Initialize as null, not string
    let currentLanguage = localStorage.getItem(LS_KEYS.LANGUAGE) || 'en'; // Default to English
    let currentTheme = localStorage.getItem(LS_KEYS.THEME) || 'blue';     // Default to blue
    let cart = []; // { id: productId, quantity: n }
    // Initialize with default structure/values
    let baseMenuData = []; // Initialized later with default data
    let allOrders = [];
    let translations = {}; // Initialized later with default translations
    let categories = [];
    let currentAdminOrderSelection = null;
    let currentOrderLogView = 'current'; // New state variable for order log view: 'current' or 'archived'
    let previewButtonTimeout = null; // Timeout for preview button state
    let draggedElement = null; // For drag and drop
    let currentProductMgmtCategory = null; // Track which category is being viewed in product management
    let isDiscoveryModeActivated = localStorage.getItem(LS_KEYS.DISCOVERY_MODE) === 'true';
    let selectedPaymentMethod = 'cash'; // Initialize default payment method state
    let isCanteenOpen = false; // <<< CHANGE DEFAULT TO FALSE

    // Flags for initial data loading from WebSocket
    let isInitialProductsLoaded = false;
    let isInitialCategoriesLoaded = false;
    let isInitialTranslationsLoaded = false;

    const DEFAULT_PRODUCTS = []; // Add this line

    let suggestionButtonTimeouts = {}; // Added: For discovery mode button timeouts
    let bundleButtonTimeouts = {};   // Added: For discovery mode button timeouts

    // --- DOM Elements Caching ---
    // Cache frequently accessed DOM elements
    // const bodyElement = document.body; // Remove this duplicate declaration

    // --- Function to render initial UI parts after essential data is loaded --- 
    // Moved inside DOMContentLoaded scope to access flags
    function renderInitialUIIfNeeded() {
        if (isInitialProductsLoaded && isInitialCategoriesLoaded && isInitialTranslationsLoaded) {
            // إخفاء مؤشر التحميل إذا كان موجود
            const loader = document.getElementById('loader-overlay');
            if(loader) loader.style.display = 'none';
            console.log("All initial data received, rendering main UI...");
            // Now we can safely render UI elements that depend on this data
            populateSortButtons();
            populateMenuGrid();
            updateLanguageUI(); // Run again to ensure everything is translated correctly
            // Any other UI updates that depend on products/categories/translations
            updateProductCategoryDropdowns();
            if (currentScreen?.id === 'screen-8') {
                 populateDiscoveryMode(); // Refresh discovery if it was the initial screen
            }
             // Reset flags if needed, although likely not necessary for initial load
             // isInitialProductsLoaded = false; 
             // isInitialCategoriesLoaded = false;
             // isInitialTranslationsLoaded = false;
        } else {
             // console.log("Waiting for more initial data..."); // Optional debugging
        }
    }

    // --- WebSocket Setup ---
    let ws = null;
    // *** Using Local Network IP for testing on the same LAN ***
    // Ensure server.js is running on the machine with this IP (192.168.1.14)
    // and the firewall allows connections on port 8080.
    // const WS_URL = 'ws://192.168.1.10:8080'; // <-- Local Network IP
    const WS_URL = 'ws://' + location.hostname + ':8080/';
    let reconnectInterval = 5000; // Reconnect every 5 seconds
    let isManagementClient = false; // Flag to track if this instance is management

    function connectWebSocket() {
        ws = new WebSocket(WS_URL);

        ws.onopen = () => {
            console.log('[DEBUG] ws.onopen - connection established');
            isWebSocketConnected = true;
            hideConnectingScreen();
            console.log('WebSocket connected');
            // Request initial data from server upon connection
            sendWebSocketMessage({ type: 'request_initial_data' });
            console.log('Sent request_initial_data to server.');

            // If this is the management screen, identify itself AFTER requesting general data
            if (currentScreen && (currentScreen.id === 'screen-5' || currentScreen.id === 'screen-9')) {
                identifyAsManagementClient();
            }
            // Reset reconnect interval on successful connection
            reconnectInterval = 5000;
            // If user is auto-logged-in and on loading screen, show main menu now
            if (currentUser && currentScreen && currentScreen.id === 'screen-0') {
                updateUserInfoUI();
                showScreen('screen-3');
            }
        };

        ws.onmessage = (event) => {
            try {
                const message = JSON.parse(event.data);
                // console.log('WebSocket message received:', message); // Keep this commented for cleaner logs now

                let productsJustLoaded = false;
                let categoriesJustLoaded = false;

                switch (message.type) {
                    case 'initial_products':
                        // *** ADDED CHECK: Ensure payload is an array ***
                        if (Array.isArray(message.payload)) {
                            console.log('Received initial products', message.payload.length);
                            baseMenuData = message.payload;
                            isInitialProductsLoaded = true;
                            renderInitialUIIfNeeded(); // Call check after update
                        } else {
                            console.error('Received non-array payload for initial_products:', message.payload);
                            // Optionally fallback to defaults or request again?
                        }
                        break;
                    case 'initial_categories':
                        // *** ADDED CHECK: Ensure payload is an array ***
                        if (Array.isArray(message.payload)) {
                            console.log('Received initial categories', message.payload.length);
                            categories = message.payload;
                            isInitialCategoriesLoaded = true;
                            renderInitialUIIfNeeded(); // Call check after update
                        } else {
                            console.error('Received non-array payload for initial_categories:', message.payload);
                        }
                        break;
                    case 'initial_translations':
                         if (message.payload && typeof message.payload === 'object') {
                            // translations = message.payload; // OLD: Direct assignment overwrites defaults
                            // NEW: Merge server translations into existing defaults/localStorage translations
                            console.log('[WebSocket] Merging initial_translations from server into existing translations.');
                            for (const key in message.payload) {
                                if (message.payload.hasOwnProperty(key)) {
                                    const incomingValue = message.payload[key];
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
                            // After merging, ensure translations are saved to local storage so they persist
                            // if the server is later offline, and also so that they are the base for next session.
                            saveTranslations(); 

                            isInitialTranslationsLoaded = true; 
                            updateLanguageUI(); 
                            renderInitialUIIfNeeded(); 
                         } else {
                             console.warn('Received invalid payload for initial_translations:', message.payload);
                         }
                         break;
                    case 'initial_canteen_status': // <<< Handle initial status
                        console.log('Received initial canteen status', message.payload);
                        if (message.payload && typeof message.payload.isOpen === 'boolean') {
                            isCanteenOpen = message.payload.isOpen;
                            console.log('[Log] isCanteenOpen set by initial_canteen_status to:', isCanteenOpen); // <-- Log Added
                            updateCanteenStatusIndicator(); // Update indicator on welcome screen
                            updateAdminStatusToggle(); // Update admin toggle if admin screen is loaded first
                        } else {
                            console.warn('[Log] Invalid initial_canteen_status payload:', message.payload); // <-- Log Added
                        }
                        break;
                    case 'initial_orders':
                        // Only process if we are on the management screen
                        if (isManagementClient) {
                            console.log('Received initial orders from server:', message.payload);
                            // Replace local orders with server orders if management
                            // Be careful with merging strategies if needed
                            allOrders = message.payload;
                            // Optionally save to local storage as well? Or rely solely on server?
                            // saveOrders(); // Decide if needed
                            renderOrderLog(allOrders); // Re-render the log
                            if (currentAdminOrderSelection) {
                                // If an order was selected, re-show its details
                                showOrderDetails(currentAdminOrderSelection);
                            } else {
                                clearOrderPreview();
                            }
                        }
                        break;
                    case 'new_order':
                        // Only process if we are on the management screen
                        if (isManagementClient) {
                            console.log('New order received from server:', message.payload);
                            const newOrder = message.payload;
                            // *** Check if order already exists ***
                            const existingOrderIndex = allOrders.findIndex(order => order.id === newOrder.id);
                            if (existingOrderIndex === -1) {
                                // Add the new order only if it doesn't exist
                                allOrders.unshift(newOrder);
                                console.log(`Added new order ${newOrder.id} to the log.`);
                                // Optionally save to local storage? (Probably not needed if relying on server)
                                // saveOrders();
                            } else {
                                // Order already exists, maybe update its data if necessary?
                                // For now, just log that it was ignored to prevent duplication.
                                console.log(`Order ${newOrder.id} already exists in the log. Ignoring duplicate add.`);
                                // Optionally update the existing order: allOrders[existingOrderIndex] = newOrder;
                            }
                            // Update UI regardless (in case an existing order was updated, or just to ensure render)
                            renderOrderLog(allOrders); // Refresh the log display
                            // Maybe show a notification?
                        }
                        break;
                    case 'order_status_updated_broadcast':
                        if (isManagementClient) {
                            console.log('Received order_status_updated_broadcast:', message.payload);
                            const { orderId, newStatus, updatedOrder } = message.payload;
                            if (updatedOrder) {
                                const orderIndex = allOrders.findIndex(o => o.id === orderId);
                                if (orderIndex !== -1) {
                                    allOrders[orderIndex] = updatedOrder; // Update the local order data
                                    renderOrderLog(); // Re-render the entire order log based on current view mode
                                    // If the updated order is the one currently being previewed, refresh the preview
                                    if (currentAdminOrderSelection === orderId) {
                                        showOrderDetails(orderId);
                                    }
                                    console.log(`Order ${orderId} updated locally from broadcast.`);
                                } else {
                                    console.warn(`Received broadcast for an order ${orderId} not found locally.`);
                                    // Optionally, add it if it was missing, though this implies a sync issue
                                }
                            } else {
                                console.warn('Received order_status_updated_broadcast without full updatedOrder payload.');
                            }
                        }
                        break;
                    // Add cases for other messages like 'order_status_updated' if implemented

                    // --- START: Handling Server Broadcasts for Data Updates ---
                    case 'products_updated':
                        console.log('Received updated products from server:', message.payload.length, 'items');
                        // Log quantity of a specific item for debugging (e.g., coffee)
                        const oldCoffeeQty = baseMenuData.find(p => p.id === 'coffee')?.quantity;
                        baseMenuData = message.payload;
                        const newCoffeeQty = baseMenuData.find(p => p.id === 'coffee')?.quantity;
                        console.log(`Coffee quantity updated: ${oldCoffeeQty} -> ${newCoffeeQty}`); // Example log
                        // saveProducts(); // Optional: Decide if client should still save locally or rely on server
                        // Refresh UI elements that depend on product data
                        populateMenuGrid(); // Refresh main menu
                        if (currentScreen?.id === 'screen-8') {
                            populateDiscoveryMode(); // Refresh discovery view if active
                        }
                        if (currentScreen?.id === 'screen-9' && currentMgmtView === 'products' && currentMgmtCategory) {
                            renderProductGridForCategory(currentMgmtCategory); // Refresh product management grid if active
                        }
                         // Maybe refresh item preview if it's showing a now-updated item?
                         // if (currentScreen?.id === 'screen-7') { ... }
                         // Re-sync categories in case product category assignments changed
                         syncCategoriesWithBaseData();
                         // Refresh category dependant UI too
                         populateSortButtons();
                         updateProductCategoryDropdowns();
                         updateCartUI(); // Refresh cart in case prices changed
                        break;

                    case 'categories_updated':
                        console.log('Received updated categories from server:', message.payload.length, 'categories');
                        categories = message.payload;
                        // saveCategories(); // Optional: Client save
                        // Refresh UI elements that depend on categories
                        populateSortButtons(); // Update sort buttons
                        populateMenuGrid();    // Refresh menu grid (uses categories)
                        if (currentScreen?.id === 'screen-9') {
                            if (currentMgmtView === 'categories') {
                                renderCategoryList(); // Refresh category list view
                            } else if (currentMgmtView === 'products' && currentMgmtCategory) {
                                // Check if the currently viewed category still exists
                                if (!categories.some(c => c.key === currentMgmtCategory)) {
                                     console.log(`Currently viewed category ${currentMgmtCategory} no longer exists, switching to category list.`);
                                     showScreen9View('categories');
                                } else {
                                    renderProductGridForCategory(currentMgmtCategory); // Refresh products in current category
                                }
                            }
                        }
                        updateProductCategoryDropdowns(); // Update dropdowns in modals
                        if (currentScreen?.id === 'screen-8') {
                            populateDiscoveryMode(); // Refresh discovery view
                        }
                        break;

                    case 'translations_updated':
                        console.log('Received updated translations from server', message.payload); // Log payload too
                        if (message.payload && typeof message.payload === 'object') {
                            // Merge received translations into the existing object
                            // This prevents accidentally wiping out translations if payload is empty or partial
                            // Object.assign(translations, message.payload); // OLD LINE
                            for (const key in message.payload) {
                                if (message.payload.hasOwnProperty(key)) {
                                    const incomingValue = message.payload[key];
                                    // If the existing translation is an object (i.e., {en: ..., ar: ...})
                                    // only accept an incoming value if it's also an object.
                                    if (translations.hasOwnProperty(key) && typeof translations[key] === 'object') {
                                        if (typeof incomingValue === 'object') {
                                            Object.assign(translations[key], incomingValue); // Merge into the existing language object
                                        } else {
                                            console.warn(`[translations_updated] Ignoring update for key '${key}' because existing is an object but incoming is not. Incoming:`, incomingValue);
                                        }
                                    } else {
                                        // If existing is not an object or doesn't exist, accept object or string.
                                        if (typeof incomingValue === 'object' || typeof incomingValue === 'string') {
                                            translations[key] = incomingValue;
                                        } else {
                                            console.warn(`[translations_updated] Ignoring update for new/non-object key '${key}' because incoming type is not object/string. Incoming:`, incomingValue);
                                        }
                                    }
                                }
                            }
                            console.log('Translations merged from server.');
                            saveTranslations(); // Re-enable saving after server update
                            updateLanguageUI(); // Refresh UI with potentially updated translations
                        } else {
                             console.warn('Received invalid payload for translations_updated:', message.payload);
                        }
                        break;
                    case 'canteen_status_updated':
                        const previousStatus = isCanteenOpen; // Store previous status
                        isCanteenOpen = message.payload.isOpen;
                        console.log(`[WebSocket] Canteen status received/updated. isCanteenOpen = ${isCanteenOpen}`);
                        updateCanteenStatusIndicator();
                        updateAdminStatusToggle(); // Ensure admin toggle reflects the broadcasted state too

                        // --- Force logout if canteen closed and user is on a regular screen ---
                        if (!isCanteenOpen && previousStatus === true) { // Only trigger if status changed to closed
                             const regularUserScreens = ['screen-3', 'screen-4', 'screen-7', 'screen-8'];
                             if (currentScreen && regularUserScreens.includes(currentScreen.id)) {
                                 console.log(`[Force Logout] Canteen closed. User on screen ${currentScreen.id}. Logging out.`);
                                 // Use existing logout logic
                                 if (logoutButton) {
                                     logoutButton.click(); // This navigates to screen-1 and resets state
                                     // Show alert *after* navigation starts or is complete
                                     setTimeout(() => {
                                          // console.log("[Debug] Translations object before force logout alert:", translations); // <<< REMOVE LOG
                                          showCustomAlert(getText('force_logout_canteen_closed'), 'info_title'); // Use a specific title key
                                     }, 100); // Small delay to ensure navigation starts
                                 }
                             }
                        }
                        // --- End Force logout ---
                        break;
                    // --- END: Handling Server Broadcasts for Data Updates ---

                    // <<< Add Case for Server Order Confirmation >>>
                    case 'order_confirmed_by_server':
                        console.log('Received order confirmation from server:', message.payload);
                        const confirmedOrder = message.payload;
                        if (confirmedOrder && confirmedOrder.id) {
                            // Show confirmation alert using the ID from the server
                            const confirmationMsg = `${getText('checkout_success_id')} ${confirmedOrder.id}\n${getText('checkout_success_total')} ${formatPrice(confirmedOrder.totalAmount)}\n(${getText('checkout_success_method')} ${getText('payment_' + confirmedOrder.paymentMethod)})`;
                            showCustomAlert(confirmationMsg, 'checkout_success_title');

                            // Clear cart and update UI AFTER showing confirmation
                            cart = [];
                            updateCartUI();
                            updateCartBadge();
                            resetPreviewButtonState(); // Reset state on item preview screen if open

                            // Navigate back to the menu AFTER showing confirmation
                            setTimeout(() => showScreen('screen-3'), 500); 
                        } else {
                            console.warn('Received invalid order confirmation payload:', message.payload);
                            // Maybe show a generic success or error message as fallback
                            showCustomAlert('Order placed, but confirmation details missing.', 'info_title');
                        }
                        break;
                    // --- End Server Order Confirmation Case ---

                    // --- NEW: Handle Auth Responses ---
                    case 'register_success':
                        console.log('Registration successful:', message.payload);
                        currentUser = message.payload;
                        // Convert profilePic to key if it's a URL
                        if(currentUser.profilePic && currentUser.profilePic.startsWith('http')) {
                          // Try to find the key by value
                          const foundKey = Object.keys(PROFILE_PICS).find(k => PROFILE_PICS[k] === currentUser.profilePic);
                          if(foundKey) currentUser.profilePic = foundKey;
                          else currentUser.profilePic = 'pic1';
                        }
                        setCookie('canteenUser', JSON.stringify(currentUser), 7);
                        console.log('[register_success] setCookie called', currentUser);
                        // Clear registration form fields
                        if(registerEmailInput) registerEmailInput.value = '';
                        if(registerPasswordInput) registerPasswordInput.value = '';
                        if(registerPasswordConfirmInput) registerPasswordConfirmInput.value = '';
                        if(registerErrorMsg) registerErrorMsg.style.display = 'none';
                        // Update UI and navigate
                        updateUserInfoUI();
                        showScreen('screen-3');
                        break;
                    case 'register_error':
                        console.error('Registration error:', message.payload.message);
                        if (registerErrorMsg) {
                            // Attempt to translate server message key, fallback to raw message
                            const serverMsg = message.payload.message;
                            registerErrorMsg.textContent = getText(serverMsg) || serverMsg;
                            registerErrorMsg.style.display = 'block';
                        }
                        break;
                    case 'login_success':
                        console.log('Login successful:', message.payload);
                        currentUser = message.payload;
                        if(currentUser.profilePic && currentUser.profilePic.startsWith('http')) {
                          const foundKey = Object.keys(PROFILE_PICS).find(k => PROFILE_PICS[k] === currentUser.profilePic);
                          if(foundKey) currentUser.profilePic = foundKey;
                          else currentUser.profilePic = 'pic1';
                        }
                        setCookie('canteenUser', JSON.stringify(currentUser), 7);
                        console.log('[login_success] setCookie called', currentUser);
                        // Clear login form fields
                        if(loginEmailInput) loginEmailInput.value = '';
                        if(loginPasswordInput) loginPasswordInput.value = '';
                        if(loginErrorMsg) loginErrorMsg.style.display = 'none';
                        // Update UI and navigate
                        updateUserInfoUI();
                        showScreen('screen-3');
                        break;
                    case 'login_error':
                        console.error('Login error:', message.payload.message);
                        if (loginErrorMsg) {
                             // Attempt to translate server message key, fallback to raw message
                             const serverMsg = message.payload.message;
                            loginErrorMsg.textContent = getText(serverMsg) || serverMsg;
                            loginErrorMsg.style.display = 'block';
                        }
                        break;
                    // --- END: Handle Auth Responses ---

                    // --- START: Handle Admin Auth Responses ---
                    case 'admin_login_success':
                        console.log("Admin login successful (verified by server):", message.payload.message);
                        identifyAsManagementClient(); // Sets isManagementClient = true and informs server (server might ignore if already knows)
                        if(adminLoginErrorMsg) adminLoginErrorMsg.style.display = 'none';
                        // Clear admin login fields on success
                        if(adminPasswordInput) adminPasswordInput.value = '';
                        eraseCookie('canteenUser'); // Remove user cookie for admin
                        showScreen('screen-5'); // Navigate to the admin screen
                        break;
                    case 'admin_login_error':
                        console.error('Admin login error from server:', message.payload);
                        if (adminLoginErrorMsg) {
                            const payload = message.payload;
                            let errorText = '';

                            if (payload && payload.errorCode) {
                                switch (payload.errorCode) {
                                    case 'ATTEMPTS_REMAINING':
                                        const invalidCredsPart = getText('admin_login_error_invalid_creds') || "Invalid admin email or password.";
                                        const attempts = payload.attemptsRemaining;
                                        const attemptsPart = attempts === 1 ?
                                            getText('admin_login_attempts_singular') || "1 attempt remaining." :
                                            (getText('admin_login_attempts_plural') || "{attempts} attempts remaining.").replace('{attempts}', attempts);
                                        errorText = `${invalidCredsPart} ${attemptsPart}`;
                                        break;
                                    case 'ACCOUNT_LOCKED':
                                        const prefix = getText('admin_login_prefix_too_many_attempts') || "Too many failed attempts.";
                                        const lockedPart = (getText('admin_login_locked') || "Account locked. Try again in {minutes} minute(s).").replace('{minutes}', payload.lockoutMinutes);
                                        errorText = `${prefix} ${lockedPart}`;
                                        break;
                                    case 'MISSING_DETAILS':
                                        errorText = getText('admin_login_missing_details') || payload.message || "Missing admin login details.";
                                        break;
                                    case 'SERVER_ERROR':
                                        errorText = getText('admin_login_server_error') || payload.message || "Server error during admin login.";
                                        break;
                                    default:
                                        errorText = payload.defaultMessage || payload.message || getText('admin_login_error'); // Fallback to default message from server or generic client key
                                }
                            } else {
                                // Fallback for older message format or if errorCode is missing
                                errorText = payload.message || getText('admin_login_error');
                            }
                            adminLoginErrorMsg.textContent = errorText;
                            adminLoginErrorMsg.style.display = 'block';
                        }
                        // Clear password field on error, but keep email for user convenience
                        if(adminPasswordInput) adminPasswordInput.value = '';
                        break;
                    // --- END: Handle Admin Auth Responses ---

                    // --- START: Handle Discovery Passcode Responses ---
                    case 'discovery_passcode_success':
                        console.log("Discovery passcode correct (verified by server).");
                        isDiscoveryModeActivated = true;
                        localStorage.setItem(LS_KEYS.DISCOVERY_MODE, isDiscoveryModeActivated);
                        updateDiscoveryToggleVisualState();
                        updateDiscoverButtonVisibility();
                        hidePasscodeModal();
                        if (passcodeModalError) passcodeModalError.style.display = 'none';
                        break;
                    case 'discovery_passcode_error':
                        console.warn("Discovery passcode incorrect (verified by server).");
                        if (passcodeModalError) {
                            passcodeModalError.textContent = message.payload.message || getText('discovery_passcode_incorrect_message');
                            passcodeModalError.style.display = 'block';
                        }
                        if (passcodeModalInput) passcodeModalInput.value = '';
                        break;
                    // --- END: Handle Discovery Passcode Responses ---

                    default:
                        console.log('Unknown message type received:', message.type);
                }
            } catch (error) {
                console.error('Error processing WebSocket message:', error);
            }
        };

        ws.onclose = () => {
            console.log('[DEBUG] ws.onclose - connection lost');
            showConnectingScreen();
            console.log('WebSocket disconnected. Attempting to reconnect...');
            ws = null; // Ensure ws is nullified
            isManagementClient = false; // Reset flag on disconnect

            // Force canteen status to closed on disconnect
            isCanteenOpen = false;
            console.log('[Connection Status] Assumed canteen closed due to disconnection.');
            updateCanteenStatusIndicator(); // Update UI immediately
            updateAdminStatusToggle();    // Update UI immediately

            // --- Force logout regular users if connection is lost --- 
            if (currentUser) { 
                const regularUserScreens = ['screen-3', 'screen-4', 'screen-7', 'screen-8'];
                if (currentScreen && regularUserScreens.includes(currentScreen.id)) {
                    console.log(`[Force Logout] Connection lost. User ${currentUser.email} on screen ${currentScreen.id}. Logging out.`);
                    if (logoutButton) {
                        logoutButton.click(); 
                        // Show alert *after* navigation starts
                        setTimeout(() => {
                             const alertMsg = getText('server_connection_lost_logout'); // Get text first
                             console.log(`[onclose] Alert text to show: "${alertMsg}"`); // LOG the text
                             showCustomAlert(alertMsg, 'error_title', 5000); // Pass text and timeout (5s)
                        }, 100); 
                    }
                } else {
                    // If user is auto-logged-in from cookie but server is down, force logout
                    eraseCookie('canteenUser');
                    currentUser = null;
                    showScreen('screen-1');
                }
            }
            // --- End Force logout ---

            // Attempt to reconnect after a delay
            setTimeout(connectWebSocket, reconnectInterval);
        };

        ws.onerror = (error) => {
            console.error('WebSocket error:', error);

            // Force canteen status to closed on error
            isCanteenOpen = false;
            console.log('[Connection Status] Assumed canteen closed due to WebSocket error.');
            updateCanteenStatusIndicator(); // Update UI immediately
            updateAdminStatusToggle();    // Update UI immediately
            
            // --- Force logout regular users if connection error occurs --- 
            // (Same logic as onclose, potentially redundant if onerror always triggers onclose, but safer to include)
            if (currentUser) { 
                const regularUserScreens = ['screen-3', 'screen-4', 'screen-7', 'screen-8'];
                if (currentScreen && regularUserScreens.includes(currentScreen.id)) {
                    console.log(`[Force Logout] Connection error. User ${currentUser.email} on screen ${currentScreen.id}. Logging out.`);
                    if (logoutButton) {
                        logoutButton.click(); 
                        // Show alert *after* navigation starts
                        setTimeout(() => {
                             const alertMsg = getText('server_connection_lost_logout'); // Get text first
                             console.log(`[onerror] Alert text to show: "${alertMsg}"`); // LOG the text
                             showCustomAlert(alertMsg, 'error_title', 5000); // Pass text and timeout (5s)
                        }, 100); 
                    }
                } else {
                    // If user is auto-logged-in from cookie but server is down, force logout
                    eraseCookie('canteenUser');
                    currentUser = null;
                    showScreen('screen-1');
                }
            }
            // --- End Force logout ---

            ws.close(); // Trigger the onclose event for reconnection logic
        };
    }

    // Function to send identification message to server
    function identifyAsManagementClient() {
        if (ws && ws.readyState === WebSocket.OPEN) {
            console.log('Identifying as management client to WebSocket server...');
            ws.send(JSON.stringify({ type: 'identify_management' }));
            isManagementClient = true;
        } else {
            console.log('WebSocket not open, cannot identify as management client yet.');
            // It will try again on ws.onopen if connection succeeds later
        }
    }

    // Function to send messages safely
    function sendWebSocketMessage(message) {
        if (ws && ws.readyState === WebSocket.OPEN) {
            ws.send(JSON.stringify(message));
        } else {
            console.error('WebSocket is not connected. Message not sent:', message);
            // Optionally queue the message or show an error to the user
            // For order placement, maybe fall back to localStorage only or show error
            // showCustomAlert('Connection error. Order saved locally only.', 'error_title');
            return false; // Indicate failure
        }
        return true; // Indicate success
    }

    // --- End WebSocket Setup ---

    // --- DOM Elements (Grouped by Screen/Feature for clarity) ---
    const appContainer = document.querySelector('.app-container'),
          allScreens = document.querySelectorAll('.screen'),
          navigationElements = document.querySelectorAll('[data-target]'),
          htmlElement = document.documentElement,
          bodyElement = document.body,
          loginEmailInput = document.getElementById('login-email'),
          loginPasswordInput = document.getElementById('login-password'),
          loginSubmitButton = document.getElementById('login-submit'),
          loginErrorMsg = document.getElementById('login-error'),
          gotoAdminLoginButton = document.getElementById('goto-admin-login-button'),
          registerEmailInput = document.getElementById('register-email'),
          registerPasswordInput = document.getElementById('register-password'),
          registerPasswordConfirmInput = document.getElementById('register-password-confirm'),
          registerPhotoPicker = document.getElementById('register-photo-picker'),
          registerSubmitButton = document.getElementById('register-submit'),
          registerErrorMsg = document.getElementById('register-error'),
          logoutButton = document.getElementById('logout-button'),
          menuGrid = document.getElementById('menu-grid'),
          menuSortButtonsContainer = document.getElementById('menu-sort-buttons'),
          discoverButton = document.getElementById('discover-button'), // Button on Screen 3
          cartBadge = document.getElementById('cart-badge'),
          cartItemsContainer = document.getElementById('cart-items-container'),
          totalCalculationDetails = document.getElementById('total-calculation-details'),
          checkoutButton = document.getElementById('checkout-button'),
          userDisplayName = document.getElementById('user-display-name'),
          userProfileImage = document.getElementById('user-profile-image-display'),
          guestUserIcon = document.getElementById('guest-user-icon'),
          paymentMethods = document.getElementById('payment-methods'), // <--- Added this line
          adminEmailInput = document.getElementById('admin-email'),
          adminPasswordInput = document.getElementById('admin-password'),
          adminLoginSubmitButton = document.getElementById('admin-login-submit'),
          adminLoginErrorMsg = document.getElementById('admin-login-error'),
          mgmtBackToLoginButton = document.getElementById('mgmt-back-to-login'),
          orderSearchInput = document.getElementById('order-search-input'),
          orderSearchButton = document.getElementById('order-search-button'),
          orderLogContainer = document.getElementById('order-log-container'),
          orderPreviewSection = document.getElementById('order-preview-section'),
          orderPreviewContent = document.getElementById('order-preview-content'),
          orderStatusControls = document.getElementById('order-status-controls'),
          orderViewToggleButtons = document.querySelectorAll('.toggle-order-view-button'), // New DOM element
          // Screen 7 elements
          itemPreviewBackButton = document.getElementById('item-preview-back-button'),
          previewItemImage = document.getElementById('preview-item-image'),
          previewItemName = document.getElementById('preview-item-name'),
          previewItemDescription = document.getElementById('preview-item-description'),
          previewItemPrice = document.getElementById('preview-item-price'),
          addToCartPreviewButton = document.getElementById('add-to-cart-preview-button'),
          cartBadgePreview = document.getElementById('cart-badge-preview'),
          // Screen 8 elements
          discoveryBackButton = document.getElementById('discovery-back-button'), // Added this line
          cartBadgeDiscovery = document.getElementById('cart-badge-discovery'),
          discoveryBundlesScroller = document.getElementById('discovery-bundles-scroller'),
          discoverySuggestionsGrid = document.getElementById('discovery-suggestions-grid'),
          discoveryCategoriesContainer = document.getElementById('discovery-categories-container'),
          // Fixed & Settings
          toggleFullScreenButton = document.getElementById('toggle-fullscreen-btn'),
          settingsBtn = document.getElementById('settings-btn'),
          settingsPanel = document.getElementById('settings-panel'),
          languageGroup = document.getElementById('language-group'),
          currentLanguageDisplay = document.getElementById('current-language-display'),
          currentLanguageText = document.getElementById('current-language-text'),
          languageOptions = document.getElementById('language-options'),
          themeGroup = document.getElementById('theme-group'),
          currentThemeDisplay = document.getElementById('current-theme-display'),
          currentThemeText = document.getElementById('current-theme-text'),
          currentThemeSwatch = document.getElementById('current-theme-swatch'),
          themeOptions = document.getElementById('theme-options'),
          discoveryModeToggle = document.getElementById('discovery-mode-toggle'); // Toggle in Settings

    const customAlertOverlay = document.getElementById('custom-alert-overlay');
    const customAlertBox = document.getElementById('custom-alert-box');
    const customAlertMessage = document.getElementById('custom-alert-message');
    const customAlertCloseBtn = document.getElementById('custom-alert-close');
    const customAlertTitle = customAlertBox?.querySelector('h3'); // Use optional chaining

    // Passcode Modal Elements
    const passcodeModalOverlay = document.getElementById('passcode-modal-overlay');
    const passcodeModalBox = document.getElementById('passcode-modal-box');
    const passcodeModalTitle = document.getElementById('passcode-modal-title');
    const passcodeModalInput = document.getElementById('passcode-modal-input');
    const passcodeModalError = document.getElementById('passcode-modal-error');
    const passcodeModalOk = document.getElementById('passcode-modal-ok');
    const passcodeModalCancel = document.getElementById('passcode-modal-cancel');

    // Screen 9 Product Management Elements (REVISED)
    const gotoProductMgmtButton = document.getElementById('goto-product-mgmt-button'); // Button on screen 5
    const productMgmtBackButton = document.getElementById('product-mgmt-back-button');
    const productMgmtTitle = document.getElementById('product-mgmt-title');
    const categoryViewContainer = document.getElementById('category-view-container');
    const categoryListContainer = document.getElementById('category-list-container');
    const productViewContainer = document.getElementById('product-view-container');
    const productViewCategoryTitle = document.getElementById('product-view-category-title');
    const productGridContainer = document.getElementById('product-grid-container');
    const addProductFormContainer = document.getElementById('add-product-form-container'); // Container for the form
    const addProductCategoryName = document.getElementById('add-product-category-name'); // Span for category name in add form
    const newProductCategoryKeyInput = document.getElementById('new-product-category-key'); // Hidden input in add form

    // Add Category Form Elements (NEW)
    const categoryAddForm = document.getElementById('add-category-form');
    const newCategoryNameEnInput = document.getElementById('new-category-name-en');
    const newCategoryNameArInput = document.getElementById('new-category-name-ar');
    const addCategoryButton = document.getElementById('add-new-category-button');
    const addCategoryErrorMsg = document.getElementById('add-category-error');

    // Edit Category Modal Elements (NEW)
    const editCategoryModalOverlay = document.getElementById('edit-category-modal-overlay');
    const editCategoryModalBox = document.getElementById('edit-category-modal-box');
    const editCategoryKeyInput = document.getElementById('edit-category-key'); // Hidden input
    const editCategoryNameKeyInput = document.getElementById('edit-category-name-key'); // Hidden input
    const editCategoryNameEnInput = document.getElementById('edit-category-name-en');
    const editCategoryNameArInput = document.getElementById('edit-category-name-ar');
    const editCategoryErrorMsg = document.getElementById('edit-category-error');
    const editCategorySaveButton = document.getElementById('edit-category-save');
    const editCategoryCancelButton = document.getElementById('edit-category-cancel');

    // Add Product Form EN/AR Inputs (replace old single inputs)
    const newProductNameEnInput = document.getElementById('new-product-name-en');
    const newProductNameArInput = document.getElementById('new-product-name-ar');
    const newProductDescEnInput = document.getElementById('new-product-desc-en');
    const newProductDescArInput = document.getElementById('new-product-desc-ar');
    // Also keep references to other add product inputs
    const newProductPriceInput = document.getElementById('new-product-price');
    const newProductQuantityInput = document.getElementById('new-product-quantity');
    const newProductImageInput = document.getElementById('new-product-image');
    const addProductErrorMsg = document.getElementById('add-product-error'); // For product add errors
    const addNewProductButton = document.getElementById('add-new-product-button');

    // Edit Product Modal Elements (including new EN/AR)
    const editProductModalOverlay = document.getElementById('edit-product-modal-overlay');
    const editProductModalBox = document.getElementById('edit-product-modal-box');
    const editProductIdInput = document.getElementById('edit-product-id');
    const editProductNameEnInput = document.getElementById('edit-product-name-en'); // NEW
    const editProductNameArInput = document.getElementById('edit-product-name-ar'); // NEW
    const editProductDescEnInput = document.getElementById('edit-product-desc-en'); // NEW
    const editProductDescArInput = document.getElementById('edit-product-desc-ar'); // NEW
    const editProductPriceInput = document.getElementById('edit-product-price');
    const editProductQuantityInput = document.getElementById('edit-product-quantity');
    const editProductImageInput = document.getElementById('edit-product-image');
    const editProductCategorySelect = document.getElementById('edit-product-category');
    const editProductErrorMsg = document.getElementById('edit-product-error');
    const editProductSaveButton = document.getElementById('edit-product-save');
    const editProductCancelButton = document.getElementById('edit-product-cancel');

    // NEW: Custom Confirm Modal Elements
    const customConfirmModalOverlay = document.getElementById('custom-confirm-modal-overlay');
    const customConfirmModalBox = document.getElementById('custom-confirm-modal-box');
    const customConfirmTitle = document.getElementById('custom-confirm-title');
    const customConfirmMessage = document.getElementById('custom-confirm-message');
    const customConfirmOkBtn = document.getElementById('custom-confirm-ok-button');
    const customConfirmCancelBtn = document.getElementById('custom-confirm-cancel-button');
    // --- End New References ---

    // NEW: Config Management Elements
    const exportConfigButton = document.getElementById('export-config-button');
    const importConfigButton = document.getElementById('import-config-button');
    const importConfigInput = document.getElementById('import-config-input'); // Hidden file input
    const importConfigErrorMsg = document.getElementById('import-config-error'); // Error for import

    // --- Canteen Status Elements ---
    const canteenStatusIndicator = document.getElementById('canteen-status-indicator');
    const canteenStatusToggle = document.getElementById('canteen-status-toggle');
    const canteenStatusLabel = document.getElementById('canteen-status-label');

    // --- Data & Translations ---
    // Define initial/default data structures (use 'let' as they can be replaced by loaded data)
    // Assign initial data to the previously declared variables
    baseMenuData = [
        {id: 'coffee', price: 30, image: 'https://media.elwatannews.com/media/img/mediaarc/large/20237496061663046251.jpg', category: 'sweet', quantity: 999, name_key: 'item_name_coffee', description_key: 'item_desc_coffee'},
        {id: 'pizza', price: 70, image: 'https://www.foodandwine.com/thmb/4qg95tjf0mgdHqez5OLLYc0PNT4=/750x0/filters:no_upscale():max_bytes(150000):strip_icc():format(webp)/classic-cheese-pizza-FT-RECIPE0422-31a2c938fc2546c9a07b7011658cfd05.jpg', category: 'lunch', quantity: 999, name_key: 'item_name_pizza', description_key: 'item_desc_pizza'},
        {id: 'cookies', price: 20, image: 'https://interpretationfordream.com/wp-content/uploads/2024/09/069873874340983.webp', category: 'sweet', quantity: 999, name_key: 'item_name_cookies', description_key: 'item_desc_cookies'},
        {id: 'fries', price: 35, image: 'https://images.themodernproper.com/production/posts/2022/Homemade-French-Fries_8.jpg?w=1200&q=82&auto=format&fit=crop&dm=1662474181&s=687036746e03f50b6204c1390acdb537', category: 'snacks', quantity: 999, name_key: 'item_name_fries', description_key: 'item_desc_fries'},
        {id: 'burger', price: 60, image: 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcScReRWtq7d-yl2aIG7jOJs5FUrxeJpi-DyfZ8OycsNa_taC8mePeUW6-JE&s=10', category: 'lunch', quantity: 999, name_key: 'item_name_burger', description_key: 'item_desc_burger'},
        {id: 'soda', price: 15, image: 'https://jx.sa/8860-large_default/soda-star-water-300-ml-x-24.jpg', category: 'snacks', quantity: 999, name_key: 'item_name_soda', description_key: 'item_desc_soda'},
        {id: 'salad', price: 45, image: 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQ5sqfCpGLeoxFBPGxFxzmygHlKJgDnU-SJHEx9hVIyhnrpGmldu20OirA&s=10', category: 'lunch', quantity: 999, name_key: 'item_name_salad', description_key: 'item_desc_salad'},
        {id: 'cake', price: 40, image: 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRvFIIgqKfBgFotly6OrxXqxBGO_jLh-DIINS_e-_o4gaKlk3I9tvobZaKk&s=10', category: 'sweet', quantity: 999, name_key: 'item_name_cake', description_key: 'item_desc_cake'},
        {id: 'croissant', price: 25, image: 'https://static01.nyt.com/images/2021/04/07/dining/06croissantsrex1/merlin_184841898_ccc8fb62-ee41-44e8-9ddf-b95b198b88db-articleLarge.jpg', category: 'sweet', quantity: 999, name_key: 'item_name_croissant', description_key: 'item_desc_croissant'},
        {id: 'pasta', price: 55, image: 'https://images.services.kitchenstories.io/eT6sd87C6s0sOmsM8S2IDw96_Xs=/1080x0/filters:quality(85)/images.kitchenstories.io/wagtailOriginalImages/R131-final-photo-3-sg.jpg', category: 'lunch', quantity: 999, name_key: 'item_name_pasta', description_key: 'item_desc_pasta'},
        {id: 'chips', price: 10, image: 'https://preppykitchen.com/wp-content/uploads/2024/05/Homemade-Potato-Chips-Recipe-Card.jpg', category: 'snacks', quantity: 999, name_key: 'item_name_chips', description_key: 'item_desc_chips'},
        {id: 'juice', price: 20, image: 'https://images-prod.healthline.com/hlcmsresource/images/AN_images/orange-juice-1296x728-feature.jpg', category: 'sweet', quantity: 999, name_key: 'item_name_juice', description_key: 'item_desc_juice'},
        {id: 'sandwich', price: 50, image: 'https://www.dukeshill.co.uk/cdn/shop/articles/20240725081844-chicken-20bacon-20club-20sandwich-20main-20landscape.jpg?v=1724401314', category: 'lunch', quantity: 999, name_key: 'item_name_sandwich', description_key: 'item_desc_sandwich'},
        {id: 'muffin', price: 22, image: 'https://www.giallozafferano.com/images/269-26998/Chocolate-Chip-Muffins_1200x800.jpg', category: 'sweet', quantity: 999, name_key: 'item_name_muffin', description_key: 'item_desc_muffin'},
        {id: 'onionrings', price: 30, image: 'https://i0.wp.com/www.angsarap.net/wp-content/uploads/2015/03/Onion-Rings-Wide.jpg', category: 'snacks', quantity: 999, name_key: 'item_name_onionrings', description_key: 'item_desc_onionrings'},
        {id: 'soup', price: 35, image: 'https://i.postimg.cc/HxCYPzWN/Soup.jpg', category: 'lunch', quantity: 999, name_key: 'item_name_soup', description_key: 'item_desc_soup'}
    ];
    const mealSuggestions = [
        { id: 'sugg-1', name_key: 'suggestion_burger_combo_name', description_key: 'suggestion_burger_combo_desc', itemIds: ['burger', 'fries', 'soda'] },
        { id: 'sugg-2', name_key: 'suggestion_coffee_break_name', description_key: 'suggestion_coffee_break_desc', itemIds: ['coffee', 'muffin'] },
        { id: 'sugg-3', name_key: 'suggestion_lunch_light_name', description_key: 'suggestion_lunch_light_desc', itemIds: ['salad', 'juice'] }
    ];
    const bundleOffers = [
        { id: 'bundle-lunch-deal', name_key: 'bundle_lunch_deal_name', description_key: 'bundle_lunch_deal_desc', itemIds: ['pizza', 'salad', 'soda'], discountPercent: 15 },
        { id: 'bundle-sweet-treat', name_key: 'bundle_sweet_treat_name', description_key: 'bundle_sweet_treat_desc', itemIds: ['cake', 'coffee', 'croissant'], discountPercent: 20 }
    ];

    // Default translations (will be merged with loaded translations)
    // Assign initial translations to the previously declared variable
    translations = {
        // --- Keep ALL existing translations from previous step ---
        welcome_title: { en: "Welcome to<br>EVA Canteen", ar: "أهلاً بكم في<br>كانتين إيفا" },
        canteen_name: { en: "EVA Canteen", ar: "كانتين إيفا" },
        sign_in_label: { en: "sign in", ar: "تسجيل الدخول" },
        email_placeholder: { en: "email.....", ar: "البريد الإلكتروني....." },
        password_placeholder: { en: "password*****", ar: "كلمة المرور*****" },
        password_again_placeholder: { en: "password again*****", ar: "كلمة المرور مرة أخرى*****" },
        submit_button: { en: "submit", ar: "تأكيد" },
        register_button: { en: "Register", ar: "تسجيل" },
        login_button: { en: "Login", ar: "دخول" },
        new_account_prompt: { en: "new account?", ar: "حساب جديد؟" },
        pick_photo_label: { en: "pick photo", ar: "اختر صورة" },
        back_to_login_button: { en: "Back to Login", ar: "العودة للدخول" },
        back_to_welcome_button: { en: "Back to Welcome", ar: "العودة للترحيب" },
        back_button: { en: "Back", ar: "رجوع" },
        logout_button: { en: "Log out", ar: "تسجيل الخروج" },
        cart_label: { en: "Cart", ar: "السلة" },
        menu_label: { en: "Menu", ar: "القائمة" },
        sort_label: { en: "Sort", ar: "فرز" },
        sort_sweet: { en: "Sweet", ar: "حلويات" },
        sort_lunch: { en: "Lunch", ar: "غداء" },
        sort_snacks: { en: "Snacks", ar: "خفيف" },
        total_label: { en: "Total", ar: "الإجمالي" },
        payment_method_label: { en: "Payment Method", ar: "طريقة الدفع" },
        payment_cash: { en: "Cash", ar: "نقداً" },
        payment_card: { en: "Card", ar: "بطاقة" },
        add_to_cart_button: { en: "Add to Cart", ar: "أضف إلى السلة" },
        added_to_cart_button: { en: "Added!", ar: "تمت الإضافة!" },
        item_details_title: { en: "Item Details", ar: "تفاصيل المنتج" },
        item_name_placeholder: { en: "Item Name", ar: "اسم المنتج" },
        item_description_placeholder: { en: "Item description loading...", ar: "جاري تحميل وصف المنتج..." },
        cart_empty_message: { en: "Your cart is empty.", ar: "سلتك فارغة." },
        checkout_success_alert: { en: "Payment Method: {method}\nOrder ID: {id}\n\nYour order is placed (simulation).", ar: "الإجمالي: {total}\nطريقة الدفع: {method}\nرقم الطلب: {id}\n\nجاري إعداد طلبك (محاكاة)." },
        checkout_success_title: { en: "Order Confirmed!", ar: "تم تأكيد الطلب!" },
        ok_button: { en: "OK", ar: "حسناً" }, // Changed from "تم"
        cart_is_empty_alert: { en: "Your cart is empty!", ar: "سلتك فارغة!" },
        currency_symbol: { en: "L.E", ar: "ج.م" },
        quantity_prefix: { en: "x", ar: "×" },
        login_error_invalid: { en: "Invalid credentials.", ar: "بيانات الاعتماد غير صالحة." },
        login_error_fields: { en: "Please enter email and password.", ar: "الرجاء إدخال البريد الإلكتروني وكلمة المرور." },
        register_error_match: { en: "Passwords don't match or field empty.", ar: "كلمات المرور غير متطابقة أو الحقل فارغ." },
        register_error_fields: { en: "Please fill all fields.", ar: "الرجاء ملء جميع الحقول." },
        register_error_photo: { en: "Please select a profile picture.", ar: "الرجاء اختيار صورة شخصية." },
        management_button: { en: "Management", ar: "الإدارة" },
        admin_login_title: { en: "Management<br>Login", ar: "تسجيل دخول<br>الإدارة" },
        admin_enter_creds: { en: "Enter Credentials", ar: "أدخل بيانات الاعتماد" },
        admin_email_placeholder: { en: "admin email.....", ar: "بريد المدير....." },
        admin_password_placeholder: { en: "admin password*****", ar: "كلمة مرور المدير*****" },
        admin_login_error: { en: "Invalid admin credentials.", ar: "بيانات اعتماد المدير غير صالحة." },
        exit_button: { en: "Exit", ar: "خروج" },
        order_management_title: { en: "Order Management", ar: "إدارة الطلبات" },
        search_order_id_placeholder: { en: "Search by Order ID...", ar: "ابحث برقم الطلب..." },
        search_button: { en: "Search", ar: "بحث" },
        order_log_title: { en: "Order Log", ar: "سجل الطلبات" },
        no_orders_found: { en: "No orders found.", ar: "لم يتم العثور على طلبات." },
        order_preview_title: { en: "Order Preview", ar: "معاينة الطلب" },
        order_preview_placeholder: { en: "Select an order from the log to view details.", ar: "اختر طلبًا من السجل لعرض التفاصيل." },
        order_id_label: { en: "Order ID", ar: "رقم الطلب" },
        order_placed_label: { en: "Placed", ar: "تاريخ الطلب" },
        order_status_label: { en: "Status", ar: "الحالة" },
        order_payment_label: { en: "Payment", ar: "الدفع" },
        order_total_label: { en: "Total", ar: "الإجمالي" },
        order_items_label: { en: "Items", ar: "المنتجات" },
        order_status_pending: { en: "pending", ar: "قيد الانتظار" },
        order_status_preparing: { en: "preparing", ar: "قيد التجهيز" },
        order_status_delivered: { en: "delivered", ar: "تم التوصيل" },
        order_log_current_button: { en: "Current Orders", ar: "الطلبات الحالية" }, // New translation
        order_log_archived_button: { en: "Archived Orders", ar: "الطلبات المؤرشفة" }, // New translation
         subtotal_label: { en: "Subtotal", ar: "المجموع قبل الخصم" },
         settings_title: { en: "Settings", ar: "الإعدادات" }, settings_button_label: { en: "Settings", ar: "الإعدادات" }, language_setting_label: { en: "Language", ar: "اللغة" }, theme_setting_label: { en: "App Theme", ar: "سمة التطبيق" },
         theme_blue: { en: "Blue (Default)", ar: "الأزرق (الافتراضي)" }, theme_green: { en: "Green", ar: "الأخضر" }, theme_purple: { en: "Purple", ar: "البنفسجي" },
         theme_light_blue: { en: "Light Blue", ar: "أزرق فاتح" }, theme_mono_light: { en: "Monochrome Light", ar: "أبيض وأسود فاتح" }, theme_dark_grey: { en: "Dark Grey", ar: "رمادي داكن" }, theme_night: { en: "Night Mode", ar: "الوضع الليلي" },
         theme_mono_dark: { en: "Monochrome Dark", ar: "أبيض وأسود داكن" },
         theme_yellow: { en: "Yellow", ar: "أصفر" },
         theme_orange: { en: "Orange", ar: "برتقالي" },
         theme_light_red: { en: "Light Red", ar: "أحمر فاتح" }, // Added this line
         item_name_coffee: { en: "Coffee", ar: "قهوة" }, item_name_pizza: { en: "Pizza", ar: "بيتزا" }, item_name_cookies: { en: "Cookies", ar: "كوكيز" }, item_name_fries: { en: "French fries", ar: "بطاطس مقلية" }, item_name_burger: { en: "Burger", ar: "برجر" }, item_name_soda: { en: "Soda", ar: "صودا" }, item_name_salad: { en: "Salad", ar: "سلطة" }, item_name_cake: { en: "Cake Slice", ar: "شريحة كيك" }, item_name_croissant: { en: "Croissant", ar: "كرواسون" }, item_name_pasta: { en: "Pasta Aglio e Olio", ar: "باستا أليو إي أوليو" }, item_name_chips: { en: "Potato Chips", ar: "رقائق البطاطس" }, item_name_juice: { en: "Orange Juice", ar: "عصير برتقال" }, item_name_sandwich: { en: "Club Sandwich", ar: "كلوب ساندويتش" }, item_name_muffin: { en: "Muffin", ar: "مافن" }, item_name_onionrings: { en: "Onion Rings", ar: "حلقات بصل" }, item_name_soup: { en: "Soup of the Day", ar: "شوربة اليوم" }, item_desc_default: { en: "A tasty item from our menu.", ar: "منتج لذيذ من قائمتنا." },
         // Discovery Mode Translations
         discover_button: { en: "Discover", ar: "اكتشف" },
         discovery_mode_title: { en: "Discovery Mode", ar: "وضع الاستكشاف" },
         discovery_mode_enable_label: { en: "Enable Discovery Mode", ar: "تفعيل وضع الاستكشاف" },
         discovery_bundles_title: { en: "Special Bundles", ar: "عروض خاصة" },
         discovery_suggestions_title: { en: "Meal Ideas", ar: "أفكار وجبات" },
         discovery_all_items_title: { en: "Explore the Menu", ar: "استكشف القائمة" },
         suggestion_burger_combo_name: { en: "Classic Combo", ar: "كومبو كلاسيك" },
         suggestion_burger_combo_desc: { en: "The perfect trio: Burger, Fries, and Soda.", ar: "الثلاثي المثالي: برجر، بطاطس، وصودا." },
         suggestion_coffee_break_name: { en: "Coffee Break", ar: "استراحة قهوة" },
         suggestion_coffee_break_desc: { en: "Relax with a warm Coffee and a soft Muffin.", ar: "استرخِ مع قهوة دافئة ومافن طري." },
         suggestion_lunch_light_name: { en: "Light Lunch", ar: "غداء خفيف" },
         suggestion_lunch_light_desc: { en: "A healthy and refreshing Salad paired with Juice.", ar: "سلطة صحية ومنعشة مع عصير." },
         bundle_lunch_deal_name: { en: "Lunch Power Deal", ar: "عرض الغداء القوي" },
         bundle_lunch_deal_desc: { en: "Grab a Pizza, Salad, and Soda together and save!", ar: "احصل على بيتزا وسلطة وصودا معًا ووفر!" },
         bundle_sweet_treat_name: { en: "Sweet Treat Bundle", ar: "حزمة الحلوى اللذيذة" },
         bundle_sweet_treat_desc: { en: "Indulge with Cake, Coffee, and a Croissant at a special price.", ar: "دلل نفسك بالكيك والقهوة والكرواسون بسعر خاص." },
         add_bundle_button: { en: "Add Bundle", ar: "أضف الحزمة" },
         bundle_added_button: { en: "Bundle Added!", ar: "تمت إضافة الحزمة!" },
         discount_tag: { en: "{percent}% OFF", ar: "خصم {percent}%" },
         includes_items: { en: "Includes:", ar: "يشمل:" },
         original_price: { en: "Original:", ar: "الأصلي:" },
         bundle_price: { en: "Bundle Price:", ar: "سعر الحزمة:" },
         add_suggestion_button: { en: "Add All Items", ar: "أضف كل المنتجات" },
         suggestion_added_button: { en: "Items Added!", ar: "تمت إضافة المنتجات!" },
         suggestion_total_price: { en: "Total Price:", ar: "السعر الإجمالي:" },
         bundle_discount_applied: { en: "Bundle Discount", ar: "خصم الحزمة" },
         // Passcode Modal Translations
         discovery_passcode_prompt: { en: "Enter Discovery Mode Passcode:", ar: "أدخل رمز مرور وضع الاستكشاف:" },
         discovery_passcode_modal_title: { en: "Enter Passcode", ar: "أدخل الرمز" },
         discovery_passcode_incorrect_message: { en: "Incorrect passcode entered.", ar: "تم إدخال رمز مرور غير صحيح." },
         cancel_button: { en: "Cancel", ar: "إلغاء" },
        // --- NEW & MODIFIED Management Translations ---
        manage_products_button: { en: "Manage Products", ar: "إدارة المنتجات" },
        product_management_title: { en: "Product Management", ar: "إدارة المنتجات" },
        back_to_orders_button: { en: "Back to Orders", ar: "العودة للطلبات" },
        save_button: { en: "Save", ar: "حفظ" },
        saved_button: { en: "Saved!", ar: "تم الحفظ!" },
        product_quantity_header: { en: "Qty", ar: "الكمية" },
        // Category Management
        manage_categories_title: { en: "Manage Categories", ar: "إدارة الفئات" },
        add_category_title: { en: "Add New Category", ar: "إضافة فئة جديدة" },
        category_name_en_label: { en: "Category Name (English):", ar: "اسم الفئة (الإنجليزية):" },
        category_name_ar_label: { en: "Category Name (Arabic):", ar: "اسم الفئة (العربية):" },
        category_name_placeholder: { en: "e.g., Breakfast", ar: "مثال: فطور" },
        add_category_button: { en: "Add Category", ar: "إضافة فئة" },
        add_category_error_generic: { en: "Please enter names in both languages.", ar: "الرجاء إدخال الأسماء باللغتين." },
        add_category_error_exists: { en: "A category with this name or key might already exist.", ar: "قد توجد فئة بهذا الاسم أو المفتاح بالفعل." },
        add_category_success: { en: "Category '{name}' added successfully!", ar: "تمت إضافة الفئة '{name}' بنجاح!" },
        edit_category_title: { en: "Edit Category", ar: "تعديل الفئة" },
        edit_category_error_generic: { en: "Please enter names in both languages.", ar: "الرجاء إدخال الأسماء باللغتين." },
        edit_category_success: { en: "Category '{name}' updated successfully!", ar: "تم تحديث الفئة '{name}' بنجاح!" },
        delete_button: { en: "Delete", ar: "حذف" }, // Generic delete button text
        // confirm_delete_category: { en: "Are you sure you want to delete the category '{name}'? This cannot be undone.", ar: "هل أنت متأكد من رغبتك في حذف الفئة '{name}'؟ لا يمكن التراجع عن هذا الإجراء." }, // Now confirm_delete_category_message
        delete_category_error_not_empty: { en: "Cannot delete category '{name}' because it contains products. Please move or delete the products first.", ar: "لا يمكن حذف الفئة '{name}' لأنها تحتوي على منتجات. يرجى نقل المنتجات أو حذفها أولاً." },
        delete_category_success: { en: "Category '{name}' deleted successfully.", ar: "تم حذف الفئة '{name}' بنجاح." },
        // Product EN/AR Fields
        add_new_product_title: { en: "Add New Product", ar: "إضافة منتج جديد" },
        product_name_en_label: { en: "Product Name (English):", ar: "اسم المنتج (الإنجليزية):" },
        product_name_ar_label: { en: "Product Name (Arabic):", ar: "اسم المنتج (العربية):" },
        product_desc_en_label: { en: "Description (English):", ar: "الوصف (الإنجليزية):" },
        product_desc_ar_label: { en: "Description (Arabic):", ar: "الوصف (العربية):" },
        product_name_en_placeholder: { en: "e.g., Special Sandwich", ar: "مثال: Special Sandwich" },
        product_name_ar_placeholder: { en: "e.g., ساندويتش خاص", ar: "مثال: ساندويتش خاص" },
        product_desc_en_placeholder: { en: "e.g., Chicken, lettuce, tomato...", ar: "مثال: Chicken, lettuce, tomato..." },
        product_desc_ar_placeholder: { en: "e.g., دجاج، خس، طماطم...", ar: "مثال: دجاج، خس، طماطم..." },
        product_price_label: { en: "Price ({currency}):", ar: "السعر ({currency}):" },
        product_price_placeholder: { en: "e.g., 55.50", ar: "مثال: 55.50" },
        product_quantity_label: { en: "Quantity:", ar: "الكمية:" }, // Consistent Label
        product_quantity_placeholder: { en: "e.g., 50 (999 for unlimited)", ar: "مثال: 50 (999 للمتاح دائماً)" },
        product_image_label: { en: "Image URL:", ar: "رابط الصورة:" },
        product_image_placeholder: { en: "https://...", ar: "https://..." },
        product_category_label: { en: "Category:", ar: "الفئة:" },
        add_product_button: { en: "Add Product", ar: "إضافة المنتج" },
        add_product_error_generic: { en: "Please fill all fields correctly.", ar: "الرجاء ملء جميع الحقول بشكل صحيح." }, // Keep generic for non-lang fields
        add_product_error_en_ar_generic: { en: "Please fill all fields, including English and Arabic names/descriptions.", ar: "الرجاء ملء جميع الحقول، بما في ذلك الأسماء والأوصاف باللغتين الإنجليزية والعربية." },
        add_product_error_price: { en: "Invalid price.", ar: "السعر غير صالح." },
        add_product_error_quantity: { en: "Invalid quantity.", ar: "الكمية غير صالحة." },
        add_product_error_image: { en: "Invalid image URL.", ar: "رابط الصورة غير صالح." },
        add_product_success: { en: "Product '{name}' added successfully!", ar: "تمت إضافة المنتج '{name}' بنجاح!" },
        // Edit/Remove Product Translations
        edit_button: { en: "Edit", ar: "تعديل" },
        remove_button: { en: "Remove", ar: "إزالة" },
        // confirm_remove_product: { en: "Are you sure you want to remove '{name}'? This cannot be undone.", ar: "هل أنت متأكد من رغبتك في إزالة '{name}'؟ لا يمكن التراجع عن هذا الإجراء." }, // Now confirm_remove_product_message
        remove_product_success: { en: "Product '{name}' removed successfully.", ar: "تمت إزالة المنتج '{name}' بنجاح." },
        edit_product_title: { en: "Edit Product", ar: "تعديل المنتج" },
        save_changes_button: { en: "Save Changes", ar: "حفظ التغييرات" },
        edit_product_error_generic: { en: "Please fill all fields correctly.", ar: "الرجاء ملء جميع الحقول بشكل صحيح." },
        edit_product_error_price: { en: "Invalid price.", ar: "السعر غير صالح." },
        edit_product_error_quantity: { en: "Invalid quantity.", ar: "الكمية غير صالحة." },
        edit_product_error_image: { en: "Invalid image URL.", ar: "رابط الصورة غير صالح." },
        edit_product_success: { en: "Product '{name}' updated successfully!", ar: "تم تحديث المنتج '{name}' بنجاح!" },
        // Screen 9 View/Hint Keys
        drag_categories_hint: { en: "Drag and drop to reorder categories.", ar: "اسحب وأفلت لإعادة ترتيب الفئات." },
        drag_products_hint: { en: "Drag and drop to reorder products within this category.", ar: "اسحب وأفلت لإعادة ترتيب المنتجات داخل هذه الفئة." },
        back_to_categories_button: { en: "Back to Categories", ar: "العودة للفئات" },
        products_label: { en: "Products", ar: "المنتجات"},
        drag_to_reorder: { en: "Drag to reorder", ar: "اسحب للإعادة الترتيب" },
        no_products_in_category: { en: "No products in this category.", ar: "لا توجد منتجات في هذه الفئة." },
        error_loading_products: { en: "Error loading products.", ar: "خطأ في تحميل المنتجات." },
        no_categories_found: { en: "No categories available.", ar: "لا توجد فئات متاحة." }, // Added
        // --- NEW: Custom Confirm Modal Translations ---
        confirm_action_title: { en: "Confirm Action", ar: "تأكيد الإجراء" },
        confirm_button: { en: "Confirm", ar: "تأكيد" }, // General confirm button
        delete_confirm_button: { en: "Delete", ar: "حذف" }, // Specific delete confirm button
        // Confirm Messages (moved from previous confirm_delete_category/confirm_remove_product)
        confirm_delete_category_message: { en: "Are you sure you want to delete the category '{name}'? This action cannot be undone.", ar: "هل أنت متأكد من رغبتك في حذف الفئة '{name}'؟ لا يمكن التراجع عن هذا الإجراء." },
        confirm_remove_product_message: { en: "Are you sure you want to remove the product '{name}'? This action cannot be undone.", ar: "هل أنت متأكد من رغبتك في إزالة المنتج '{name}'؟ لا يمكن التراجع عن هذا الإجراء." },
        // --- NEW: Config Management Translations ---
        config_management_title: {en: "Configuration Management", ar: "إدارة الإعدادات"},
        export_config_button: {en: "Export Config", ar: "تصدير الإعدادات"},
        import_config_button: {en: "Import Config", ar: "استيراد الإعدادات"},
        import_config_confirm_message: {en: "Are you sure you want to import a configuration?\n\nThis will overwrite ALL existing app data (orders, products, categories, and settings). This action cannot be undone.", ar: "هل أنت متأكد من رغبتك في استيراد الإعدادات؟\n\nسيؤدي هذا إلى الكتابة فوق جميع بيانات التطبيق الموجودة (الطلبات، المنتجات، الفئات، والإعدادات). لا يمكن التراجع عن هذا الإجراء."},
        import_config_success_message: {en: "Configuration imported successfully!", ar: "تم استيراد الإعدادات بنجاح!"},
        import_config_error_generic: {en: "Import failed: Invalid file or format.", ar: "فشل الاستيراد: ملف أو تنسيق غير صالح."},
        import_config_error_json_parse: {en: "Import failed: Could not parse JSON file.", ar: "فشل الاستيراد: تعذر تحليل ملف JSON."},
        import_config_error_structure: {en: "Import failed: Invalid configuration structure.", ar: "فشل الاستيراد: هيكل الإعدادات غير صالح."},
        // --- Added Missing Keys ---
        checkout_error_connection: {en: "Connection Error: Order saved locally only.", ar: "خطأ في الاتصال: تم حفظ الطلب محليًا فقط."},
        error_title: {en: "Error", ar: "خطأ"},
        item_name_prod: {en: "Product", ar: "منتج"}, // Placeholder for dynamically added products like 'item_name_prod-...'
        // --- ADDED MISSING CHECKOUT SUCCESS KEYS from old version ---
        checkout_success_id: { en: "Order ID:", ar: "رقم الطلب:" },
        checkout_success_total: { en: "Total:", ar: "الإجمالي:" },
        checkout_success_method: { en: "Payment Method:", ar: "طريقة الدفع:" },
        checkout_error_empty: { en: "Your cart is empty!", ar: "سلتك فارغة!" },
        canteen_closed_login_alert: { en: "Canteen is currently closed. Please try again later.", ar: "الكانتين غير مفتوح حالياً. الرجاء المحاولة لاحقاً." },
        // --- ADDED: Canteen Status Translations ---
        canteen_closed_indicator: { en: "Canteen is currently CLOSED", ar: "الكانتين مغلق حالياً" },
        canteen_status_title: { en: "Canteen Status", ar: "حالة الكانتين" },
        canteen_status_open: { en: "Open", ar: "مفتوح" },
        canteen_status_closed: { en: "Closed", ar: "مغلق" },
        canteen_status_hint: { en: "Toggle to open or close the canteen for regular users.", ar: "قم بالتبديل لفتح أو إغلاق الكانتين للمستخدمين العاديين." },
        // --- ADDED: Server Connection Lost Key ---
        server_connection_lost_logout: { en: "Connection to server lost. You have been logged out.", ar: "انقطع الاتصال بالخادم. تم تسجيل خروجك." },
        // --- END ADDED KEY ---
        register_error_invalid_email: { en: "Please enter a valid email address.", ar: "الرجاء إدخال عنوان بريد إلكتروني صالح." }, // <-- ADDED
        // --- ADDED for product/category specific import/export ---
        import_products_config_confirm_message: {en: "Are you sure you want to import this configuration?\n\nThis will overwrite ONLY products, categories, and their related translations. Orders and general app settings will NOT be affected. This action cannot be undone.", ar: "هل أنت متأكد من رغبتك في استيراد هذا الإعداد؟\n\nسيؤدي هذا إلى الكتابة فوق المنتجات والفئات والترجمات المرتبطة بها فقط. لن تتأثر الطلبات وإعدادات التطبيق العامة. لا يمكن التراجع عن هذا الإجراء."},
        import_products_config_success_message: {en: "Products, categories, and related translations imported successfully!", ar: "تم استيراد المنتجات والفئات والترجمات المرتبطة بها بنجاح!"},
        // --- END ADDED ---
        item_out_of_stock_alert: { en: "Sorry, '{itemName}' is out of stock!", ar: "عذراً، '{itemName}' نفذ من المخزون حالياً!" },
        edit_product_success_title: { en: "Product Updated", ar: "تم تحديث المنتج" } // New title key
    };


    // --- Helper Functions ---
    function getText(key, specificLang = null) { // Added specificLang parameter
        console.log(`[getText] Called with key: "${key}", currentLanguage: "${currentLanguage}", specificLang: "${specificLang}"`); // DEBUG
        const lang = specificLang || currentLanguage || 'en';
        const translationSet = translations[key];
        let text = key; 
        if (translationSet && typeof translationSet === 'object') {
            text = translationSet[lang] || translationSet.en || key;
            console.log(`[getText] Found translationSet for "${key}". Attempting lang "${lang}". Result: "${text}"`); // DEBUG
        } else if (typeof translationSet === 'string') {
            text = translationSet;
            console.log(`[getText] Found string translation for "${key}": "${text}"`); // DEBUG
        } else {
            console.log(`[getText] No translationSet found for key: "${key}". Returning key itself.`); // DEBUG
        }
        return text;
    }
    function getCurrency() { return getText('currency_symbol'); }
    function formatPrice(p) { return `${p} ${getCurrency()}`; }

    // --- Canteen Status UI Update Functions ---
    // Moved here to guarantee definition before any call
    function updateCanteenStatusIndicator() {
        // console.log('[Log] Running updateCanteenStatusIndicator. isCanteenOpen =', isCanteenOpen);
        const indicatorElement = document.getElementById('canteen-status-indicator');
        if (!indicatorElement) {
             // console.warn("updateCanteenStatusIndicator: Element not found");
             return;
        }
        // Use the correct variable name: isCanteenOpen
        if (!isCanteenOpen) { 
            console.log("DEBUG: Entering block to SHOW indicator (isCanteenOpen is false)"); // <<< ADD DEBUG LOG
            indicatorElement.textContent = getText('canteen_closed_indicator');
            indicatorElement.style.display = 'block';
            // console.log('[Log] Indicator set to visible (Closed)');
        } else {
            indicatorElement.style.display = 'none';
            // console.log('[Log] Indicator set to hidden (Open)');
        }
    }

    function updateAdminStatusToggle() {
        // console.log('[Log] Running updateAdminStatusToggle. isCanteenOpen =', isCanteenOpen);
        const toggleElement = document.getElementById('canteen-status-toggle');
        const labelElement = document.getElementById('canteen-status-label');
        if (!toggleElement || !labelElement) {
            // console.warn("updateAdminStatusToggle: Elements not found");
            return;
        }
        // Use the correct variable name: isCanteenOpen
        toggleElement.checked = isCanteenOpen; 
        const labelKey = isCanteenOpen ? 'canteen_status_open' : 'canteen_status_closed';
        labelElement.dataset.langKey = labelKey;
        labelElement.textContent = getText(labelKey);
        // console.log(`[Log] Toggle checked: ${toggleElement.checked}, Label: ${labelElement.textContent}`);
    }
    // --- End Canteen Status UI Update Functions ---

    // --- Load Functions ---
    function loadTranslations() {
        // Start with the default translations defined in the code
        let finalTranslations = { ...translations }; // Create a copy of the defaults
        console.log("[loadTranslations] Starting with default keys:", Object.keys(finalTranslations).length);

        // Load from localStorage IF available
        try {
            // <<< FIX localStorage KEY HERE >>>
            const storedTranslations = localStorage.getItem(LS_KEYS.TRANSLATIONS); 
            if (storedTranslations) {
                const loadedTranslations = JSON.parse(storedTranslations);
                console.log("[loadTranslations] Found stored translations with keys:", Object.keys(loadedTranslations).length);
                
                // <<< CORRECTED MERGE LOGIC >>>
                // Merge loaded translations ON TOP of the defaults
                for (const key in loadedTranslations) {
                    if (loadedTranslations.hasOwnProperty(key)) {
                        // If the key exists in defaults, merge safely
                        if (finalTranslations[key]) {
                            if (typeof finalTranslations[key] === 'object' && typeof loadedTranslations[key] === 'object') {
                                finalTranslations[key] = { ...finalTranslations[key], ...loadedTranslations[key] };
                            } else {
                                // Overwrite if types don't match or default isn't object
                                finalTranslations[key] = loadedTranslations[key]; 
                            }
                        } else {
                            // If the key is only in loaded, add it
                            finalTranslations[key] = loadedTranslations[key];
                        }
                    }
                }
                console.log("[loadTranslations] Translations loaded and merged from localStorage. Final keys:", Object.keys(finalTranslations).length);
            } else {
                console.log("[loadTranslations] No stored translations found, using defaults.");
            }
        } catch (e) {
            console.error("[loadTranslations] Error loading/merging translations:", e);
            // Fallback to the initial defaults if error occurs
            finalTranslations = { ...translations }; 
        }
        // Assign the final merged object back to the global variable
        translations = finalTranslations;
    }

    function loadProducts() {
        const savedProducts = localStorage.getItem(LS_KEYS.PRODUCTS);
        if (savedProducts) {
            try {
                const parsedData = JSON.parse(savedProducts);
                // *** ADDED CHECK: Ensure it's an array ***
                if (Array.isArray(parsedData)) {
                    baseMenuData = parsedData;
                    console.log("Products loaded from localStorage.");
                    return; // Exit if loaded successfully
                } else {
                    console.warn("Invalid non-array product data found in localStorage. Using defaults.");
                }
            } catch (e) {
                console.error("Error parsing products from localStorage:", e, ". Using defaults.");
            }
        }
        // Fallback to default if not loaded or invalid
        baseMenuData = [...DEFAULT_PRODUCTS]; // Use default
        console.log("Using default products.");
        saveProducts(); // Save defaults if using them
    }

    function loadOrders() {
        // **MODIFIED**: Prioritize server data if connected and management, else use localStorage
        if (isManagementClient && ws && ws.readyState === WebSocket.OPEN) {
            // We expect initial_orders message to populate `allOrders`
            console.log('Waiting for initial orders from WebSocket...');
            // Render empty initially, will be populated by WS message
            renderOrderLog([]);
            clearOrderPreview();
        } else {
            // Fallback to localStorage if not management or not connected
            console.log('Loading orders from localStorage (fallback).');
            try {
                const storedOrders = localStorage.getItem(LS_KEYS.ORDERS);
                allOrders = storedOrders ? JSON.parse(storedOrders) : [];
                // If management screen is loaded without WS connection, render from local storage
                if (currentScreen === 'screen-5' || currentScreen === 'screen-9') {
                   renderOrderLog(allOrders);
                   clearOrderPreview(); // Clear preview initially
                }
            } catch (e) {
                console.error("Error loading orders from localStorage:", e);
                allOrders = [];
            }
        }
    }

    // The loadCategories logic is already inside initializeCategories,
    // but we should ensure initializeCategories is called *after* loadProducts.
    // saveCategories function already exists.


    // --- Save Functions ---
    function saveTranslations() {
        try {
            // Save the entire current translations object
            localStorage.setItem(LS_KEYS.TRANSLATIONS, JSON.stringify(translations));
            console.log("Translations saved to localStorage.");
        } catch (e) {
            console.error("Error saving translations to localStorage:", e);
        }
    }

    function saveProducts() {
        try {
            localStorage.setItem(LS_KEYS.PRODUCTS, JSON.stringify(baseMenuData));
            console.log("Products saved to localStorage.");
        } catch (e) {
            console.error("Error saving products to localStorage:", e);
        }
    }

    function saveOrders() {
        // **MODIFIED**: Primarily rely on server for orders in management view.
        // Clients placing orders still save locally as backup/offline capability.
        // Management view might not need to save locally if server is source of truth.
        try {
            localStorage.setItem(LS_KEYS.ORDERS, JSON.stringify(allOrders));
        } catch (e) {
            console.error("Error saving orders to localStorage:", e);
        }
    }

    // saveCategories function already exists below initializeCategories.

    // --- Theme Switching Function ---
    function applyTheme(themeName) { console.log("Applying theme:", themeName); bodyElement.dataset.theme = themeName; currentTheme = themeName; localStorage.setItem(LS_KEYS.THEME, themeName); if (settingsPanel) updateThemeDisplay(); }

    // --- Settings Panel Logic ---
    function toggleSettingsPanel(show) { if (!settingsPanel) return; const i = settingsPanel.classList.contains('visible'); if (typeof show === 'boolean') { if (show && !i) { settingsPanel.classList.add('visible'); document.addEventListener('click', handleOutsideSettingsClick, true); updateSettingsDisplays(); } else if (!show && i) { closeAllSettingsDropdowns(); settingsPanel.classList.remove('visible'); document.removeEventListener('click', handleOutsideSettingsClick, true); } } else { toggleSettingsPanel(!i); } }
    function handleOutsideSettingsClick(e) { if (settingsPanel && !settingsPanel.contains(e.target) && settingsBtn && !settingsBtn.contains(e.target)) { toggleSettingsPanel(false); } else { const isDropdownControl = currentLanguageDisplay?.contains(e.target) || currentThemeDisplay?.contains(e.target); const isDropdownList = languageOptions?.contains(e.target) || themeOptions?.contains(e.target); const isToggleControl = discoveryModeToggle?.contains(e.target); if (settingsPanel && settingsPanel.contains(e.target) && !isDropdownControl && !isDropdownList && !isToggleControl) { closeAllSettingsDropdowns(); } } }
    function toggleSettingsDropdown(g) { if (!g) return; const o = g === languageGroup ? themeGroup : languageGroup; const i = !g.classList.contains('open'); const d = g.querySelector('.settings-current-display'); const l = g.querySelector('.settings-options-list'); if (i && o && o.classList.contains('open')) { o.classList.remove('open', 'open-upward'); const oD = o.querySelector('.settings-current-display'); if (oD) oD.setAttribute('aria-expanded', 'false'); } let u = false; if (i && d && l) { const e = 150; const r = d.getBoundingClientRect(); const sB = window.innerHeight - r.bottom - 10; const sA = r.top - 10; if (sB < e && sA > sB) { u = true; } } g.classList.remove('open-upward'); if(i) { if (u) { g.classList.add('open-upward'); } g.classList.add('open'); } else { g.classList.remove('open'); } if (d) d.setAttribute('aria-expanded', i); }
    function closeAllSettingsDropdowns() { if(languageGroup) languageGroup.classList.remove('open', 'open-upward'); if(themeGroup) themeGroup.classList.remove('open', 'open-upward'); if(currentLanguageDisplay) currentLanguageDisplay.setAttribute('aria-expanded', 'false'); if(currentThemeDisplay) currentThemeDisplay.setAttribute('aria-expanded', 'false'); }
    function updateLanguageDisplay() { const s = languageOptions?.querySelector(`.option-item[data-lang="${currentLanguage}"]`); if (s && currentLanguageText) { currentLanguageText.textContent = s.querySelector('span').textContent; languageOptions?.querySelectorAll('.option-item').forEach(i => { const a = i.dataset.lang === currentLanguage; i.classList.toggle('active', a); i.setAttribute('aria-selected', a); }); } }
    function updateThemeDisplay() { 
        const s = themeOptions?.querySelector(`.option-item[data-theme="${currentTheme}"]`); 
        if (s && currentThemeText && currentThemeSwatch) { 
            const tK = s.querySelector('span:not(.theme-swatch)')?.dataset.langKey; 
            console.log(`[updateThemeDisplay] Current theme: "${currentTheme}", Extracted langKey (tK): "${tK}"`); // DEBUG
            console.log(`[updateThemeDisplay] --- Dumping translations object ---`); // DEBUG
            console.log(translations); // DEBUG
            if (translations['theme_light_red']) { // DEBUG
                console.log(`[updateThemeDisplay] translations['theme_light_red'] exists:`, translations['theme_light_red']); // DEBUG
            } else { // DEBUG
                console.log(`[updateThemeDisplay] !!! translations['theme_light_red'] NOT FOUND !!!`); // DEBUG
            } // DEBUG
            if (tK) { 
                const translatedText = getText(tK);
                console.log(`[updateThemeDisplay] getText("${tK}") returned: "${translatedText}"`); // DEBUG
                currentThemeText.textContent = translatedText; 
            } else { 
                currentThemeText.textContent = s.querySelector('span:not(.theme-swatch)')?.textContent || currentTheme; 
                console.log(`[updateThemeDisplay] No langKey (tK) found. Fallback to textContent or currentTheme.`); // DEBUG
            } 
            const w = s.querySelector('.theme-swatch'); 
            if (w) { 
                currentThemeSwatch.style.background = w.style.background; 
                currentThemeSwatch.className = 'theme-swatch'; 
                const c = Array.from(w.classList).find(cls => cls !== 'theme-swatch'); 
                if (c) { currentThemeSwatch.classList.add(c); } 
            } 
            themeOptions?.querySelectorAll('.option-item').forEach(i => { 
                const a = i.dataset.theme === currentTheme; 
                i.classList.toggle('active', a); 
                i.setAttribute('aria-selected', a); 
            }); 
        } 
    }
    function updateDiscoveryToggleVisualState() { if (discoveryModeToggle) { discoveryModeToggle.setAttribute('aria-checked', isDiscoveryModeActivated); } }
    function updateSettingsDisplays() { updateLanguageDisplay(); updateThemeDisplay(); updateDiscoveryToggleVisualState(); }
    function updateDiscoverButtonVisibility() { if (discoverButton) { discoverButton.style.display = isDiscoveryModeActivated ? 'inline-flex' : 'none'; } }
    // --- End Settings Panel Logic ---

    // --- Language and UI Update Functions ---
    function updateLanguageUI() {
         htmlElement.lang = currentLanguage;
         localStorage.setItem(LS_KEYS.LANGUAGE, currentLanguage); // Save language setting
         document.querySelectorAll('[data-lang-key]').forEach(el => {
             const key = el.dataset.langKey;
             let translation = getText(key);

             // Currency symbol injection
             if ((key === 'product_price_label') && (el.closest('#add-product-form-container') || el.closest('#edit-product-modal-box'))) {
                 translation = translation.replace('{currency}', getCurrency());
             }
              // Percent injection for discount tag
             if (key === 'discount_tag' && el.dataset.percent) {
                 translation = translation.replace('{percent}', el.dataset.percent);
             }


             if (['welcome_title', 'admin_login_title'].includes(key)) { el.innerHTML = translation; }
             else if (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA') {
                 if (el.dataset.langValueTarget) { el.setAttribute(el.dataset.langValueTarget, translation); }
             }
             else if (el.tagName === 'OPTION') { el.textContent = translation; }
             else { el.textContent = translation; }
         });
         document.querySelectorAll('[data-lang-placeholder-key]').forEach(el => {
             const key = el.dataset.langPlaceholderKey;
             if (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA') {
                let translation;
                if (el.id === 'new-category-name-en') {
                    translation = getText(key, 'en'); // Force English placeholder
                    // console.log(`Setting placeholder for 'new-category-name-en': Language=en, Key=${key}, Translation=${translation}, ElementID=${el.id}`);
                } else if (el.id === 'new-category-name-ar') {
                    translation = getText(key, 'ar'); // Force Arabic placeholder
                    // console.log(`Setting placeholder for 'new-category-name-ar': Language=ar, Key=${key}, Translation=${translation}, ElementID=${el.id}`);
                } else {
                    translation = getText(key); // Use current UI language for other placeholders
                }
                el.placeholder = translation;
             }
         });
         updateSettingsDisplays();
         populateMenuGrid(); // Update menu grid based on new category/product data/order
         populateSortButtons(); // Update sort buttons based on categories
         updateCartUI(); // Update cart which now includes discount validation

         // Update Screen 5 if active
         if (currentScreen && currentScreen.id === 'screen-5') {
            const logTitle = currentScreen.querySelector('.order-log-section h4');
            const previewTitle = currentScreen.querySelector('.order-preview-section h4');
            const configTitle = currentScreen.querySelector('.config-management-section h4');
            if(logTitle) logTitle.textContent = getText('order_log_title');
            if(previewTitle) previewTitle.textContent = getText('order_preview_title');
            if(configTitle) configTitle.textContent = getText('config_management_title');
             renderOrderLog();
             if (currentAdminOrderSelection) showOrderDetails(currentAdminOrderSelection); else clearOrderPreview();
             if(importConfigErrorMsg) importConfigErrorMsg.textContent = getText('import_config_error_generic'); // Update import error text
         }
         // Update Screen 9 if active (re-render current view)
         if (currentScreen && currentScreen.id === 'screen-9') {
             // Re-render specific view (categories or products)
             showScreen9View(currentMgmtView, currentMgmtCategory);
             // Also update the Add Category form texts if visible
             if(categoryViewContainer?.classList.contains('active')){
                const acTitle = categoryAddForm?.querySelector('h5');
                if (acTitle) acTitle.textContent = getText('add_category_title');
             }
         }

         if (currentScreen && currentScreen.id === 'screen-7') { const currentItemId = addToCartPreviewButton?.dataset.itemId; if (currentItemId) { showItemPreview(currentItemId, false); const isAdded = addToCartPreviewButton.classList.contains('added'); setPreviewButtonState(isAdded); } }
         if (currentScreen && currentScreen.id === 'screen-8') { populateDiscoveryMode(); } // Refresh discovery
         updateModalLanguage(); // General alert modal
         updatePasscodeModalLanguage();
         updateEditModalLanguage(); // Edit product modal
         updateEditCategoryModalLanguage(); // Edit category modal
         updateConfirmModalLanguage(); // NEW: Update confirm modal
         updateProductCategoryDropdowns(); // Update category dropdowns in modals/forms
         if (addToCartPreviewButton && addToCartPreviewButton.dataset.itemId) { const isAdded = addToCartPreviewButton.classList.contains('added'); setPreviewButtonState(isAdded); }
        if (currentScreen && currentScreen.id === 'screen-8') {
            if(discoveryBundlesScroller) { discoveryBundlesScroller.querySelectorAll('.add-bundle-button.added span').forEach(span => { if(span) span.textContent = getText('bundle_added_button'); }); }
            if(discoverySuggestionsGrid) { discoverySuggestionsGrid.querySelectorAll('.add-suggestion-button.added span').forEach(span => { if(span) span.textContent = getText('suggestion_added_button'); }); }
         }
         updateDiscoverButtonVisibility();
     }


    // --- Screen Management ---
     function showScreen(id, skip = false) {
         const targetScreen = document.getElementById(id);
         if (targetScreen && targetScreen !== currentScreen) {
             toggleSettingsPanel(false);
             let fromScreenId = null;
             if (currentScreen) {
                 fromScreenId = currentScreen.id;
                 currentScreen.classList.remove('active');
                 if (fromScreenId === 'screen-7') { resetPreviewButtonState(); }
                 if (fromScreenId === 'screen-8') { Object.values(suggestionButtonTimeouts).forEach(clearTimeout); Object.values(bundleButtonTimeouts).forEach(clearTimeout); suggestionButtonTimeouts = {}; bundleButtonTimeouts = {}; }
                 if (fromScreenId === 'screen-9') { draggedElement = null; } // Reset dragged element when leaving screen 9
             }

            // Updated logic for previousScreenId
            if (fromScreenId && id !== 'screen-1') { // Store previous screen unless navigating to the main login screen
                previousScreenId = fromScreenId;
                console.log(`[Debug] Navigating from ${fromScreenId} to ${id}. previousScreenId set to: ${previousScreenId}`); // DEBUG
            } else if (id === 'screen-1') { // Clear when going to main login
                previousScreenId = null;
                console.log(`[Debug] Navigating to ${id} (screen-1). previousScreenId cleared.`); // DEBUG
            } else if (fromScreenId) {
                // This case handles when fromScreenId is not null, but id is screen-1 (already handled above) or fromScreenId was null initially.
                // If fromScreenId exists but previousScreenId wasn't set by the conditions above, it means we came from screen-1 or previousScreenId was null.
                // It's safer to log if previousScreenId remains unchanged here for clarity, though it should be null if coming from screen-1 or initially null.
                console.log(`[Debug] Navigating from ${fromScreenId} to ${id}. previousScreenId remains: ${previousScreenId}`); // DEBUG
            } else {
                console.log(`[Debug] Navigating to ${id} (no fromScreenId). previousScreenId remains: ${previousScreenId}`); // DEBUG
            }
            // Note: If navigating away from screen-7, the specific logic for screen-7's back button (item-preview-back-button)
            // might still use its own previousScreenId which is set when entering screen-7. This general previousScreenId
            // is for more generic back button functionality.

             requestAnimationFrame(() => {
                 targetScreen.classList.add('active');
                 currentScreen = targetScreen;

                 // Specific logic for screen-7's back button handling (already present and seems okay)
                 // if (id === 'screen-7' && fromScreenId && ['screen-3', 'screen-8'].includes(fromScreenId)) {
                 //     previousScreenId = fromScreenId; // This was the old specific logic for screen-7
                 // } else if (id !== 'screen-7' && fromScreenId !== 'screen-7') {
                 //     previousScreenId = null; // This was too aggressive
                 // }


                 if (id === 'screen-4') updateCartUI();
                 if (id === 'screen-5') {
                    renderOrderLog(); clearOrderPreview(); if(orderSearchInput) orderSearchInput.value = '';
                    if(importConfigErrorMsg) importConfigErrorMsg.style.display = 'none'; // Hide import error on screen entry
                    // Set the active toggle button based on currentOrderLogView
                    orderViewToggleButtons.forEach(btn => {
                        btn.classList.toggle('active', btn.dataset.viewMode === currentOrderLogView);
                    });
                 }
                 // Screen 9 logic
                 if (id === 'screen-9') {
                     showScreen9View('categories'); // Always start at category view
                 }
                 if (id === 'screen-6') { 
                    if(adminLoginErrorMsg) adminLoginErrorMsg.style.display = 'none'; 
                    if(adminPasswordInput) adminPasswordInput.focus(); // Focus password input
                 }
                 if (id === 'screen-3' || id === 'screen-7' || id === 'screen-8' || id === 'screen-9') updateCartBadge();
                 if (id === 'screen-8') { populateDiscoveryMode(); }
                 if (id === 'screen-3') { updateDiscoverButtonVisibility(); }
                 if (id === 'screen-1') { updateCanteenStatusIndicator(); }
                 if (targetScreen && !skip) targetScreen.scrollTop = 0;
             });
         } else if (!targetScreen) {
             console.error(`Screen ${id} not found`);
         } else if (targetScreen === currentScreen && !skip) {
             targetScreen.scrollTop = 0;
             toggleSettingsPanel(false);
         }

         // **MODIFIED**: Identify as management client when switching to relevant screens
         if ((id === 'screen-5' || id === 'screen-9') && !isManagementClient) {
             identifyAsManagementClient();
             // Trigger reload of orders from WebSocket if connection is open
             if (ws && ws.readyState === WebSocket.OPEN) {
                 console.log("Requesting initial orders for management screen...");
                 ws.send(JSON.stringify({ type: 'get_orders' })); // Server needs to handle this
             } else {
                 loadOrders(); // Fallback to localStorage if WS not ready
             }
         } else if (id !== 'screen-5' && id !== 'screen-9') {
             isManagementClient = false; // Reset flag when leaving management screens
         }
     }

    // --- User and Profile Functions ---
    function updateUserInfoUI() {
      if (currentUser) {
        const n = currentUser.email.split('@')[0];
        if(userDisplayName) userDisplayName.textContent = `@${n}`;
        if(userProfileImage) {
          userProfileImage.src = PROFILE_PICS[currentUser.profilePic] || DEFAULT_PROFILE_PIC;
          userProfileImage.alt = `${n}'s PP`;
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

    // --- Menu and Filtering Functions ---
    function getProductData(productId) { return baseMenuData.find(p => p.id === productId); }

    function populateSortButtons() {
        if (!menuSortButtonsContainer) return;
        menuSortButtonsContainer.innerHTML = ''; // Clear existing

        // *** ADDED LOGS ***
        console.log("[Debug] Populating Sort Buttons. Categories:", JSON.stringify(categories));
        console.log("[Debug] Populating Sort Buttons. Translations:", JSON.stringify(translations));
        // *** END LOGS ***

        let firstCategoryKey = null;
        categories.forEach((cat, index) => {
            if (index === 0) firstCategoryKey = cat.key; // Get the first category key
            const button = document.createElement('button');
            button.className = 'sort-button';
            button.dataset.category = cat.key;
            // Check if name_key exists and try to get translation
            const nameKey = cat.name_key || `sort_${cat.key}`; // Fallback name_key if missing
            const buttonText = getText(nameKey) || cat.key; // Fallback to cat.key if translation fails
            button.dataset.langKey = nameKey; // Store the key used
            button.textContent = buttonText;
            menuSortButtonsContainer.appendChild(button);
        });
        // Activate the first button by default if categories exist
        const firstButton = menuSortButtonsContainer.querySelector('.sort-button');
        if (firstButton) firstButton.classList.add('active');
    }


    function populateMenuGrid() {
        if(!menuGrid || !menuSortButtonsContainer) return;
        menuGrid.innerHTML = '';
        const activeSortButton = menuSortButtonsContainer.querySelector('.sort-button.active');
        const selectedCategoryKey = activeSortButton ? activeSortButton.dataset.category : (categories[0]?.key || null); // Use key

        if (!selectedCategoryKey) {
             menuGrid.innerHTML = `<p class="empty-cart-message">${getText('no_categories_found') || 'No categories available.'}</p>`;
             return;
        }

        const category = categories.find(c => c.key === selectedCategoryKey);
        if (!category || category.productIds.length === 0) {
             menuGrid.innerHTML = `<p class="empty-cart-message">${getText('no_products_in_category') || 'No products in this category.'}</p>`;
            return;
        }

        // Filter baseMenuData to include only products in the current category's order list
        const productsToShow = category.productIds
            .map(productId => getProductData(productId)) // Get product data
            .filter(product => product && product.category === category.key); // Ensure product exists and is still in this category

        // Re-render the grid using the ordered and filtered list
        productsToShow.forEach((item, index) => {
             const menuItemDiv = document.createElement('div');
             menuItemDiv.className = 'menu-item'; menuItemDiv.dataset.id = item.id; menuItemDiv.dataset.category = item.category; // Still store original category key
             const name = getText(item.name_key); const price = formatPrice(item.price);
             menuItemDiv.innerHTML = `<img src="${item.image}" alt="${name}" onerror="this.src='https://via.placeholder.com/100x75/eee?text=Img'; this.onerror=null;"><p>${name}</p><span class="price-button">${price}</span>`;
             menuItemDiv.style.animation = `fadeInItem 0.4s ${index * 0.04}s ease-out backwards`;
             menuGrid.appendChild(menuItemDiv);
        });
    }
    function applyFilter(s, a = true) {
        if (!s || s.id !== 'screen-3') return;
        populateMenuGrid(); // Re-render based on active sort button's category key
    }

    // --- Cart Functions (with Validation) ---
    function updateCartBadge() {
        const validatedCart = validateCartDiscounts(cart);
        const totalQuantity = validatedCart.reduce((sum, item) => sum + (item.isDiscount ? 0 : item.quantity), 0);
        [cartBadge, cartBadgePreview, cartBadgeDiscovery].forEach(badgeElement => {
            if (badgeElement) {
                badgeElement.textContent = totalQuantity;
                badgeElement.classList.toggle('visible', totalQuantity > 0);
            }
        });
    }

    function validateCartDiscounts(currentCart) {
        // Create a map of item IDs currently in the cart (excluding discounts) and their total quantity
        const cartItemQuantities = currentCart.reduce((map, item) => {
            if (!item.isDiscount) {
                map.set(item.id, (map.get(item.id) || 0) + item.quantity);
            }
            return map;
        }, new Map());

        const validatedCart = [];
        const appliedBundles = new Set(); // Track which bundles have had their discount validated and applied once

        // First, add all regular items
        currentCart.forEach(item => {
            if (!item.isDiscount) {
                validatedCart.push(item);
            }
        });

        // Then, validate and add discounts
        currentCart.forEach(item => {
            if (item.isDiscount && item.bundleId) {
                const bundle = bundleOffers.find(b => b.id === item.bundleId);
                if (bundle && !appliedBundles.has(bundle.id)) { // Ensure bundle exists and only apply discount once per bundle type
                    const requiredIds = bundle.itemIds;
                    // Check if enough quantity of *all* required items exist in the cart for *one* bundle
                    const canApplyBundle = requiredIds.every(reqId => cartItemQuantities.has(reqId) && cartItemQuantities.get(reqId) > 0);

                    if (canApplyBundle) {
                         // Add the discount item
                         validatedCart.push(item);
                         appliedBundles.add(bundle.id); // Mark this bundle discount as applied
                         // Note: For simplicity, this logic applies the bundle discount *once*
                         // even if there are multiple quantities of items that could qualify for multiple bundles.
                         // A more complex system would track quantities used for bundles.
                    } else {
                        // console.log(`Removing orphaned discount for bundle ${item.bundleId} - items missing or insufficient quantity.`);
                    }
                } else if (item.bundleId && appliedBundles.has(bundle.id)) {
                    // console.log(`Skipping duplicate discount for bundle ${item.bundleId}`);
                    // This discount has already been handled for this bundle type
                } else if (!item.bundleId) {
                    // This is a non-bundle discount, keep it? Depends on logic. Assuming no other discount types for now.
                    // If there were other manual discounts, you'd add them here.
                     console.warn(`Discount item ${item.id} has no bundleId. Keeping it.`);
                     validatedCart.push(item);
                } else {
                    console.warn(`Discount item ${item.id} has unknown bundleId ${item.bundleId}. Removing.`);
                }
            }
        });

        return validatedCart;
    }


    function updateCartUI() {
        if (!cartItemsContainer || !totalCalculationDetails || !checkoutButton) return;

        const validatedCart = validateCartDiscounts(cart);
        // Only update the main cart if validation resulted in changes (discounts removed)
        if (validatedCart.length !== cart.length || JSON.stringify(validatedCart) !== JSON.stringify(cart)) {
            console.log("Cart updated after discount validation.");
            cart = validatedCart;
        }

        cartItemsContainer.innerHTML = '';
        totalCalculationDetails.innerHTML = '';
        let totalPriceBeforeDiscounts = 0;
        let totalDiscount = 0;
        const currencySymbol = getCurrency();
        const quantityPrefix = getText('quantity_prefix');

        if (cart.length === 0) { // Use updated `cart` array
            cartItemsContainer.innerHTML = `<p class="empty-cart-message">${getText('cart_empty_message')}</p>`;
        } else {
            cart.forEach(item => { // Iterate over updated `cart` array
                const itemSubtotal = item.price * item.quantity;
                if (item.isDiscount) {
                    totalDiscount += Math.abs(itemSubtotal);
                    const discountName = getText(item.name_key) || "Discount";
                    totalCalculationDetails.innerHTML += `<p style="color: var(--active-green); font-weight: bold;">${discountName}: -${formatPrice(Math.abs(itemSubtotal))}</p>`; // Show discounted amount
                    const cartItemEl = document.createElement('div');
                    cartItemEl.className = 'cart-item discount-item';
                    cartItemEl.dataset.id = item.id;
                    cartItemEl.dataset.bundleId = item.bundleId || '';
                    cartItemEl.innerHTML = `
                        <img src="${item.image || 'https://img.icons8.com/ios-filled/50/discount--v1.png'}" alt="Discount" style="opacity:0.5; filter: grayscale(80%); width: 40px; height: 40px; object-fit: contain;">
                        <div class="item-details">
                            <div class="item-info"><p>${discountName}</p></div>
                            <span class="item-price-button" style="color: var(--active-green); font-weight: bold; background: transparent; border: none; padding: 6px 0;">-${formatPrice(Math.abs(item.price))}</span>
                        </div>
                        <button class="remove-item-button" title="Remove discount">×</button>`;
                    cartItemsContainer.appendChild(cartItemEl);
                } else {
                    totalPriceBeforeDiscounts += itemSubtotal;
                    const itemName = getText(item.name_key);
                    totalCalculationDetails.innerHTML += `<p>${quantityPrefix}${item.quantity} ${itemName} = ${formatPrice(itemSubtotal)}</p>`;
                    const cartItemEl = document.createElement('div');
                    cartItemEl.className = 'cart-item';
                    cartItemEl.dataset.id = item.id;
                    cartItemEl.innerHTML = `
                        <img src="${item.image}" alt="${itemName}">
                        <div class="item-details">
                            <div class="item-info"><p title="${itemName}">${itemName}</p><span class="item-quantity">${quantityPrefix}${item.quantity}</span></div>
                            <span class="item-price-button">${formatPrice(itemSubtotal)}</span>
                        </div>
                        <button class="remove-item-button" title="Remove item">×</button>`;
                    cartItemsContainer.appendChild(cartItemEl);
                }
            });
        }

        const finalTotal = totalPriceBeforeDiscounts - totalDiscount;
        checkoutButton.textContent = formatPrice(finalTotal);
        checkoutButton.disabled = cart.filter(item => !item.isDiscount).length === 0; // Use updated `cart`
        updateCartBadge();
    }

    function addToCart(id) {
        const productData = getProductData(id); if (!productData) { console.warn(`Product ${id} not found.`); return; }
        const cartItem = cart.find(i => i.id === id && !i.isDiscount); const currentCartQuantity = cartItem ? cartItem.quantity : 0;
        if (productData.quantity !== 999 && productData.quantity <= currentCartQuantity) { 
            const itemName = getText(productData.name_key);
            showCustomAlert(getText('item_out_of_stock_alert').replace('{itemName}', itemName), 'error_title'); // Changed title to 'error_title'
            return; 
        }
        const existingCartItemIndex = cart.findIndex(i => i.id === id && !i.isDiscount); if (existingCartItemIndex > -1) { cart[existingCartItemIndex].quantity++; } else { const cartProductData = { id: productData.id, price: productData.price, image: productData.image, category: productData.category, name_key: productData.name_key, description_key: productData.description_key, quantity: 1 }; cart.push(cartProductData); }
        updateCartUI(); // This will re-validate discounts
    }
    function removeFromCart(id) {
        const itemIndex = cart.findIndex(i => i.id === id); if (itemIndex === -1) return;
        // If it's a discount item or quantity is 1, remove the item
        if (cart[itemIndex].isDiscount || cart[itemIndex].quantity <= 1) {
            // Before removing a regular item, find if it was part of a bundle discount that is currently applied
            if (!cart[itemIndex].isDiscount) {
                 const itemRemovedId = cart[itemIndex].id;
                 // Check for any bundle discounts in the cart that require this item
                 const relatedBundleDiscounts = cart.filter(item =>
                    item.isDiscount &&
                    item.bundleId &&
                    bundleOffers.find(b => b.id === item.bundleId)?.itemIds.includes(itemRemovedId)
                 );

                 if (relatedBundleDiscounts.length > 0) {
                      // If removing this item invalidates a bundle discount, remove *all* discount items
                      // related to any bundle that required this item.
                      // This is a simplified approach. A more complex one would re-validate bundles.
                      console.log(`Removing item ${itemRemovedId}. Checking for related bundle discounts...`);
                      const bundleIdsToRemove = new Set();
                       relatedBundleDiscounts.forEach(discountItem => bundleIdsToRemove.add(discountItem.bundleId));

                       cart = cart.filter(item =>
                           !(item.isDiscount && item.bundleId && bundleIdsToRemove.has(item.bundleId))
                       );
                       console.log(`Removed related bundle discounts:`, [...bundleIdsToRemove]);
                 }
            }
            // Finally, remove the item itself
            const indexToRemove = cart.findIndex(i => i.id === id); // Find index again in potentially modified array
            if (indexToRemove > -1) {
                 cart.splice(indexToRemove, 1);
                 console.log(`Removed item or discount: ${id}`);
            }


        } else {
            cart[itemIndex].quantity--;
             console.log(`Reduced quantity for item: ${id}`);
        }
        updateCartUI(); // Re-validate discounts after removal
    }
    // --- End Cart Functions ---

    // --- Item Preview Functions ---
    function showItemPreview(id, n = true) { const d = getProductData(id); if (!d || !previewItemImage || !previewItemName || !previewItemDescription || !previewItemPrice || !addToCartPreviewButton) return; const nm = getText(d.name_key), ds = getText(d.description_key || 'item_desc_default'), p = formatPrice(d.price); previewItemImage.src = d.image; previewItemImage.alt = nm; previewItemName.textContent = nm; previewItemDescription.textContent = ds; previewItemPrice.textContent = p; addToCartPreviewButton.dataset.itemId = id; setPreviewButtonState(false); if (n) showScreen('screen-7'); else updateCartBadge(); }
    function setPreviewButtonState(a) { if (!addToCartPreviewButton) return; addToCartPreviewButton.classList.toggle('added', a); const k = a ? 'added_to_cart_button' : 'add_to_cart_button'; const c = a ? 'fas fa-check' : 'fas fa-cart-plus'; let s = addToCartPreviewButton.querySelector('span'); if (!s) { s = document.createElement('span'); addToCartPreviewButton.appendChild(s); } s.dataset.langKey = k; s.textContent = getText(k); let i = addToCartPreviewButton.querySelector('i'); if (!i) { i = document.createElement('i'); addToCartPreviewButton.prepend(i); } i.className = c; i.style.marginRight = ''; i.style.marginLeft = ''; }
    function resetPreviewButtonState() {
        // ADD CHECK for the button's existence
        if (!addToCartPreviewButton) {
            console.warn("resetPreviewButtonState called but addToCartPreviewButton not found.");
            return;
        }
        // Original code
        if(addToCartPreviewButton) { // Keep this inner check too for safety, though redundant now
            if (previewButtonTimeout) {
                clearTimeout(previewButtonTimeout);
                previewButtonTimeout = null;
            }
            setPreviewButtonState(false);
            addToCartPreviewButton.dataset.itemId = '';
        }
    }

    // --- Order Placement and Management Functions ---
     // function generateOrderId() { return `ORD-${Date.now()}-${Math.floor(Math.random()*10000)}`; }
     // New implementation for sequential daily order IDs
     function generateOrderId() {
         // REMOVED localStorage logic. Now generates a simple temporary ID.
         // The server will assign the final sequential ID.
         const tempId = `TEMP-${Date.now()}-${Math.random().toString(36).substring(2, 9)}`;
         console.log(`Generated temporary Client-Side ID: ${tempId}`);
         return tempId;
         /* --- OLD localStorage Logic --- 
         const now = new Date();
         const day = String(now.getDate()).padStart(2, '0'); // DD format
         const month = String(now.getMonth() + 1).padStart(2, '0'); // MM format
         const year = now.getFullYear();
         const currentDateStr = `${year}-${month}-${day}`; // YYYY-MM-DD for comparison

         // Get last order data from localStorage
         const lastDateStr = localStorage.getItem(LS_KEYS.LAST_ORDER_DATE) || '';
         let lastSequence = parseInt(localStorage.getItem(LS_KEYS.LAST_ORDER_SEQUENCE) || '0', 10);

         let currentSequence;

         // Check if it's a new day
         if (currentDateStr === lastDateStr) {
             currentSequence = lastSequence + 1;
         } else {
             // Reset sequence for the new day
             currentSequence = 1;
         }

         // Save the new date and sequence
         localStorage.setItem(LS_KEYS.LAST_ORDER_DATE, currentDateStr);
         localStorage.setItem(LS_KEYS.LAST_ORDER_SEQUENCE, String(currentSequence));

         // Format the final ID
         const orderId = `ORD-${currentSequence}-${day}-${month}`;
         console.log(`Generated Order ID: ${orderId}`); // Log for debugging
         return orderId;
         */
     }

     function placeOrder() {
         // <<< Add client-side check for canteen status >>>
         if (!isCanteenOpen) {
             console.warn("Attempted to place order while canteen is perceived as closed (client-side check).");
             // Show alert based on server status or connection issue
             const alertKey = ws && ws.readyState === WebSocket.OPEN ? 'canteen_closed_login_alert' : 'checkout_error_connection'; // Use different messages
             showCustomAlert(getText(alertKey), 'error_title');
             return;
         }
         // --- End client-side check ---

         if (cart.length === 0) {
             showCustomAlert(getText('checkout_error_empty'), 'error_title');
             return;
         }

         const tempOrderId = generateOrderId(); // Get Temp ID
         const orderTimestamp = new Date();
         const activePaymentMethod = paymentMethods?.querySelector('.payment-button.active')?.dataset.method || 'cash';

         // Calculate total and gather items using the current cart
         const validatedCart = validateCartDiscounts([...cart]); 
         const totalAmount = validatedCart.reduce((sum, item) => {
             const itemPrice = (typeof item.price === 'number') ? item.price : 0;
             const itemQuantity = (typeof item.quantity === 'number') ? item.quantity : 0;
             // Discounts have negative price, add them correctly
             return sum + (itemPrice * itemQuantity);
         }, 0);

         const orderItems = validatedCart.map(cartItem => {
             // Find product data (including name_key, description_key etc.)
             const productData = baseMenuData.find(p => p.id === cartItem.id);
             return {
                 id: cartItem.id,
                 quantity: cartItem.quantity,
                 price: cartItem.price, // Use the price from the validated cart (could be discount)
                 isDiscount: cartItem.isDiscount || false,
                 // Include keys for display later, especially for discounts
                 name_key: cartItem.name_key || productData?.name_key || 'unknown_item',
                 // Add other relevant keys if needed
             };
         });

         const newOrderRequest = {
             id: tempOrderId, // Send the TEMP ID in the request
             timestamp: orderTimestamp,
             items: orderItems,
             totalAmount: parseFloat(totalAmount.toFixed(2)), 
             status: 'pending', // Initial status
             paymentMethod: activePaymentMethod,
             user: currentUser ? { email: currentUser.email, profilePic: currentUser.profilePic } : null
         };

         // Send order request to WebSocket server
         const sentToServer = sendWebSocketMessage({ type: 'place_order', payload: newOrderRequest });

         if (sentToServer) {
             console.log('Order request sent to WebSocket server with temp ID:', tempOrderId);
             // DO NOT clear cart or show alert here anymore. Wait for server confirmation.
         } else {
             console.warn('Failed to send order to server, saving locally only.');
             // Save locally as a fallback if sending failed
             // Note: This local order will have the TEMP ID.
             // Consider how to handle this if needed later (e.g., sync attempts)
             // allOrders.unshift(newOrderRequest); 
             // saveOrders();
             showCustomAlert(getText('checkout_error_connection'), 'error_title'); // Inform user of connection error
             // Do NOT clear cart here either, let the user retry or fix connection
         }

         // --- REMOVED Cart clearing, UI updates, Alert, and Navigation from here --- 
         // --- These actions are now handled in the 'order_confirmed_by_server' message case --- 
     }
     function renderOrderLog(ordersToRender = null, viewModeToUse = currentOrderLogView) {
        if(!orderLogContainer) return;
        orderLogContainer.innerHTML = '';

        const ordersToDisplay = ordersToRender || allOrders;
        // console.log(`Rendering order log. View mode: ${viewModeToUse}. Orders available: ${ordersToDisplay.length}`);

        // Date logic for filtering
        const startOfToday = new Date();
        startOfToday.setHours(0, 0, 0, 0); // Set to the beginning of the current day

        let filteredOrders = ordersToDisplay.filter(order => {
            const orderDate = new Date(order.timestamp);
            // It's important to normalize the order's date to the start of its day for consistent comparison
            orderDate.setHours(0, 0, 0, 0);

            if (viewModeToUse === 'archived') {
                return orderDate < startOfToday; // Orders from before today are archived
            } else { // 'current'
                return orderDate >= startOfToday; // Orders from today onwards are current
            }
        });

        // Sort orders: most recent first, then by ID for tie-breaking
        filteredOrders.sort((a, b) => {
            const dateA = new Date(a.timestamp);
            const dateB = new Date(b.timestamp);
            if (dateB - dateA !== 0) {
                return dateB - dateA; // Most recent first
            }
            return a.id.localeCompare(b.id); // Then by ID
        });

        // Apply search filter if there's a search term
        const searchTerm = orderSearchInput?.value.trim().toLowerCase();
        if (searchTerm) {
            filteredOrders = filteredOrders.filter(order => order.id.toLowerCase().includes(searchTerm));
        }

        orderLogContainer.innerHTML = ''; // Clear previous entries

        if (filteredOrders.length === 0) {
            orderLogContainer.innerHTML = `<p class="no-orders-message">${getText(viewModeToUse === 'archived' ? 'no_archived_orders_message' : 'no_current_orders_message')}</p>`;
            if (currentAdminOrderSelection && !filteredOrders.some(o => o.id === currentAdminOrderSelection)) {
                clearOrderPreview(); // Clear preview if selected order is not in the new filtered list
            }
            return;
        }

        filteredOrders.forEach(order => {
            const item = document.createElement('div');
            item.className = 'order-log-item';
            item.dataset.orderId = order.id;
            if (order.id === currentAdminOrderSelection) {
                item.classList.add('active');
            }

            const orderIdSpan = document.createElement('span');
            orderIdSpan.className = 'order-id';
            orderIdSpan.textContent = order.id;
            orderIdSpan.title = order.id; // Show full ID on hover

            const statusSpan = document.createElement('span');
            statusSpan.className = `order-status ${order.status}`;
            statusSpan.textContent = getText(`order_status_${order.status}`) || order.status;

            const totalSpan = document.createElement('span');
            totalSpan.className = 'order-total';
            totalSpan.textContent = formatPrice(order.totalAmount);

            item.appendChild(orderIdSpan);
            item.appendChild(statusSpan);
            item.appendChild(totalSpan);

            item.addEventListener('click', () => showOrderDetails(order.id));
            orderLogContainer.appendChild(item);
        });

        // If a selected order is no longer in the filtered list (e.g., due to search or view change),
        // and the list is not empty, clear the preview.
        if (currentAdminOrderSelection && !filteredOrders.some(o => o.id === currentAdminOrderSelection)) {
            clearOrderPreview();
        }
     }
     function clearOrderPreview() { if(!orderPreviewContent || !orderStatusControls) return; orderPreviewContent.innerHTML = `<p class="order-preview-placeholder">${getText('order_preview_placeholder')}</p>`; orderStatusControls.innerHTML = ''; currentAdminOrderSelection = null; orderLogContainer?.querySelectorAll('.order-log-item.active').forEach(i => i.classList.remove('active')); }
     function showOrderDetails(id) {
         const o = allOrders.find(ord => ord.id === id);

         // DEBUG: Log the entire order object
         console.log('Showing details for order:', o);

         if (!o || !orderPreviewContent) {
             clearOrderPreview();
             return;
         }

         currentAdminOrderSelection = id; // Store selected order ID

         // Highlight active order in log
         orderLogContainer?.querySelectorAll('.order-log-item').forEach(item => {
             item.classList.toggle('active', item.dataset.orderId === id);
         });

        let itemsHtml = '<ul>';
        o.items.forEach(item => {
            const product = getProductData(item.id);
            const itemName = product ? getText(product.name_key) : getText('unknown_item');
            // Ensure item.price and item.quantity are valid numbers for calculation
            const itemPrice = typeof item.price === 'number' ? item.price : 0;
            const itemQuantity = typeof item.quantity === 'number' ? item.quantity : 0;
            itemsHtml += `<li>${itemQuantity} x ${itemName} (${formatPrice(itemPrice * itemQuantity)})</li>`;
        });
        itemsHtml += '</ul>';

        // Revised user display logic
        let userDisplayHtml;
        // MODIFIED: Check o.user and o.user.email instead of o.userEmail
        if (o.user && o.user.email && o.user.email !== 'N/A') { // Registered user with a proper email
            const userName = (typeof o.user.name === 'string' && o.user.name && o.user.name !== 'Guest') ? o.user.name : o.user.email.split('@')[0];
            userDisplayHtml = `${userName} (<a href="mailto:${o.user.email}">${o.user.email}</a>)`;
        } else {
            // Guest user (o.user is null, or o.user.email is 'N/A' or missing)
            userDisplayHtml = getText('user_guest');
        }
        
        const orderTime = new Date(o.timestamp).toLocaleString(currentLanguage === 'ar' ? 'ar-EG-u-nu-latn' : 'en-GB', {
            day: '2-digit', month: '2-digit', year: 'numeric',
            hour: '2-digit', minute: '2-digit', hour12: true
        });

        // MODIFIED: Use o.totalAmount instead of o.total
        const totalFormatted = (typeof o.totalAmount === 'number') ? formatPrice(o.totalAmount) : getText('total_undefined');

        orderPreviewContent.innerHTML = `
            <p><strong>${getText('order_id_label')}:</strong> <span>${o.id || getText('id_undefined')}</span></p>
            <p><strong>${getText('user_label')}:</strong> <span>${userDisplayHtml}</span></p>
            <p><strong>${getText('time_label')}:</strong> <span>${orderTime}</span></p>
            <p><strong>${getText('status_label')}:</strong> <span class="order-status ${o.status}">${getText('order_status_' + o.status)}</span></p>
            <p><strong>${getText('payment_method_label')}:</strong> <span>${getText('payment_method_' + o.paymentMethod) || o.paymentMethod}</span></p>
            ${o.discountApplied ? `<p><strong>${getText('discount_applied_label')}:</strong> <span>${getText(o.discountApplied.name_key)} (${o.discountApplied.percentage}%)</span></p>` : ''}
            <p><strong>${getText('items_label')}:</strong></p>
            ${itemsHtml}
            <p><strong>${getText('total_label')}:</strong> <span>${totalFormatted}</span></p>
        `;
        renderStatusButtons(o);
     }
     function renderStatusButtons(o) { if(!orderStatusControls) return; orderStatusControls.innerHTML = ''; const p = ['pending', 'preparing', 'delivered']; p.forEach(s => { const b = document.createElement('button'); b.className = 'button small-button status-button'; b.dataset.status = s; const t = getText(`order_status_${s}`); b.textContent = t.charAt(0).toUpperCase() + t.slice(1); b.disabled = (o.status === s); b.classList.toggle('active', o.status === s); let ic = ''; if (s === 'pending') ic = 'fas fa-hourglass-start'; else if (s === 'preparing') ic = 'fas fa-cogs'; else if (s === 'delivered') ic = 'fas fa-check-circle'; if(ic) { const i = document.createElement('i'); i.className = ic; b.prepend(i, ' '); } b.addEventListener('click', () => updateOrderStatus(o.id, s)); orderStatusControls.appendChild(b); }); }
     function updateOrderStatus(id, n) {
         const o = allOrders.find(ord => ord.id === id);
         if (o) {
             o.status = n;
             // saveOrders(); // Client-side save, not for server persistence
             renderOrderLog(); // Will use currentOrderLogView
             showOrderDetails(id); // Re-render details to update button states

             // Send status update to server via WebSocket
             if (ws && ws.readyState === WebSocket.OPEN) {
                 sendWebSocketMessage({
                     type: 'update_order_status',
                     payload: { orderId: id, newStatus: n }
                 });
                 console.log(`Sent update_order_status for order ${id} to ${n}`);
             } else {
                 console.error('WebSocket not connected. Cannot send order status update.');
                 // Optionally, queue the update or notify the user
             }
         }
     }
     function handleOrderSearch() {
        // The actual filtering and re-rendering is now primarily handled by renderOrderLog
        // This function mainly triggers a re-render with the current search term.
        // console.log(`Order search triggered. Term: "${orderSearchInput?.value}", View: "${currentOrderLogView}"`);
        renderOrderLog(); // Re-render based on current view and whatever is in search input

        // If search clears, and an item was selected, we might want to ensure it's still valid
        // or clear preview. renderOrderLog handles clearing preview if selected item is not in results.
     }

    // --- Category / Product Order Management ---
    function initializeCategories() {
        console.log("Initializing categories...");
        const savedCategories = localStorage.getItem(LS_KEYS.CATEGORIES);
        let loadedFromSave = false;
        if (savedCategories) {
            try {
                const parsedData = JSON.parse(savedCategories);
                if (Array.isArray(parsedData)) {
                    categories = parsedData; // Assign directly if loaded from save
                    console.log("Categories loaded from localStorage.");
                    loadedFromSave = true;
                } else {
                     console.warn("Invalid non-array category data found in localStorage. Building defaults.");
                }
            } catch (e) {
                console.error("Error parsing categories from localStorage:", e, ". Building defaults.");
            }
        }

        if (!loadedFromSave) {
            console.log("Building initial categories from base menu data.");
            // ** Assign the *returned* value from the function **
            categories = buildInitialCategories();
        }

        // Always run sync after loading/building
        syncCategoriesWithBaseData(); // Calls syncCategoriesWithBaseData
    }

    // Builds categories based ONLY on current baseMenuData
    function buildInitialCategories() {
        console.log("Building initial category structure...");
        const categoryKeys = [...new Set(baseMenuData.map(p => p.category))];
        const defaultCategoryOrder = ['sweet', 'lunch', 'snacks'];
        const orderedKeys = defaultCategoryOrder.filter(k => categoryKeys.includes(k)).concat(categoryKeys.filter(k => !defaultCategoryOrder.includes(k)));
        // ** Create a local variable for the new categories array **
        const builtCategories = orderedKeys.map(catKey => ({
            key: catKey,
            name_key: `sort_${catKey}`,
            productIds: baseMenuData.filter(p => p.category === catKey).map(p => p.id)
        }));
         // Ensure default categories like 'sweet', 'lunch', 'snacks' exist in translations
         const defaultCategoryTranslations = {
              sort_sweet: { en: "Sweet", ar: "حلويات" },
              sort_lunch: { en: "Lunch", ar: "غداء" },
              sort_snacks: { en: "Snacks", ar: "خفيف" }
         };
         Object.keys(defaultCategoryTranslations).forEach(key => {
             if (!translations[key]) {
                  translations[key] = defaultCategoryTranslations[key];
             }
         });
         saveTranslations(); // Save any added default translations
         console.log("Initial categories built and default translations ensured:", builtCategories);
         // ** Return the built array **
         return builtCategories;
    }
    function syncCategoriesWithBaseData() {
        const allProductIds = new Set(baseMenuData.map(p => p.id));
        const categoryKeysInBase = new Set(baseMenuData.map(p => p.category));
        const newCategoriesToAdd = [];

        // 1. Add any new categories found in baseMenuData but not in categories array
        categoryKeysInBase.forEach(catKey => {
             if (!categories.some(c => c.key === catKey)) {
                 console.log(`Sync: Adding missing category key '${catKey}'`);
                 // Attempt to find a name_key if it exists in translations (e.g., loaded from config)
                 // Otherwise, default to a generic name_key based on the key
                 const existingTranslationKey = Object.keys(translations).find(tKey => translations[tKey]?.en?.toLowerCase() === catKey.toLowerCase() || translations[tKey]?.ar === catKey);
                 const newNameKey = existingTranslationKey || `sort_${catKey}`; // Use existing key if found, otherwise create new one

                 // If using a new name_key, ensure it has default translations
                 if (!translations[newNameKey]) {
                      translations[newNameKey] = { en: catKey, ar: catKey }; // Default to key name in both languages
                      console.log(`Sync: Added default translation for new category key '${newNameKey}'.`);
                      // Note: User will need to edit this translation later in the Edit Category modal
                 }
                 newCategoriesToAdd.push({ key: catKey, name_key: newNameKey, productIds: [] }); // Add as empty for now
             }
        });

        // Append new categories to the end
        categories.push(...newCategoriesToAdd);

        // 2. Remove categories from the categories array that no longer exist in baseMenuData
        const initialCategoryCount = categories.length;
        categories = categories.filter(c => {
            const existsInBase = categoryKeysInBase.has(c.key);
            if (!existsInBase) {
                console.log(`Sync: Removing category key '${c.key}' (not found in products data).`);
                // Do NOT remove the translation key here, as it might be intended for later use.
                // Translation cleanup should be manual or via config import overwrite.
            }
            return existsInBase;
        });
        if (categories.length < initialCategoryCount) {
             console.log(`Sync: Removed ${initialCategoryCount - categories.length} categories.`);
        }


        // 3. Sync productIds within each category in the categories array
        categories.forEach(category => {
             // --- ADD CHECK: Ensure category.productIds is an array --- 
             if (!Array.isArray(category.productIds)) {
                 console.warn(`Sync: Category '${category.key}' missing or has invalid productIds. Initializing as [].`);
                 category.productIds = [];
             }
             // --- END CHECK ---

             const currentProductsInCategory = baseMenuData.filter(p => p.category === category.key);
             const currentProductIdsInCategory = new Set(currentProductsInCategory.map(p => p.id));

             // Filter out productIds from the category list that no longer exist in baseMenuData or changed category
             const initialProductIdsCount = category.productIds.length;
             category.productIds = category.productIds.filter(id => currentProductIdsInCategory.has(id));
             if (category.productIds.length < initialProductIdsCount) {
                 console.log(`Sync: Removed ${initialProductIdsCount - category.productIds.length} orphaned product IDs from category '${category.key}'.`);
             }

             // Add productIds from baseMenuData that are in this category but not in the category's productIds list
             // Adds them to the end for simplicity during sync
             currentProductsInCategory.forEach(product => {
                  if (!category.productIds.includes(product.id)) {
                      console.log(`Sync: Adding product ID '${product.id}' to category '${category.key}' list.`);
                      category.productIds.push(product.id);
                  }
             });
        });

        console.log("Categories synced with baseMenuData:", categories);
    }
    function saveCategories() { try { localStorage.setItem(LS_KEYS.CATEGORIES, JSON.stringify(categories)); console.log("Categories order saved."); } catch (e) { console.error("Error saving categories:", e); } }

    // --- Screen 9 View Management & Rendering ---
    function showScreen9View(viewType, categoryKey = null) {
        if (!currentScreen || currentScreen.id !== 'screen-9') return;
        currentMgmtView = viewType; currentMgmtCategory = categoryKey;
        const categoryContainer = currentScreen.querySelector('#category-view-container'); const productContainer = currentScreen.querySelector('#product-view-container'); const mgmtTitle = currentScreen.querySelector('#product-mgmt-title'); const backButton = currentScreen.querySelector('#product-mgmt-back-button'); const backButtonSpan = backButton?.querySelector('span');
        if (!categoryContainer || !productContainer || !mgmtTitle || !backButton || !backButtonSpan) return;
        if (viewType === 'categories') { categoryContainer.classList.add('active'); productContainer.classList.remove('active'); mgmtTitle.textContent = getText('product_management_title'); backButton.dataset.target = 'screen-5'; backButtonSpan.textContent = getText('back_to_orders_button'); renderCategoryList(); }
        else if (viewType === 'products' && categoryKey) { categoryContainer.classList.remove('active'); productContainer.classList.add('active'); const categoryData = categories.find(c => c.key === categoryKey); const categoryName = categoryData ? getText(categoryData.name_key) : categoryKey; mgmtTitle.textContent = categoryName; productViewCategoryTitle.textContent = `${categoryName} ${getText('products_label') || 'Products'}`; backButton.dataset.target = ''; /* Clear target */ backButtonSpan.textContent = getText('back_to_categories_button') || 'Back to Categories'; renderProductGridForCategory(categoryKey); setupAddProductFormForCategory(categoryKey); }
        else { console.error("Invalid view type or missing key"); showScreen9View('categories'); }
    }

    function renderCategoryList() {
        if (!categoryListContainer) return;
        categoryListContainer.innerHTML = ''; // Clear previous items

        if (categories.length === 0) {
            categoryListContainer.innerHTML = `<p class="empty-cart-message">${getText('no_categories_found')}</p>`; // Reuse empty message style
            return;
        }

        categories.forEach((category) => {
            const catItem = document.createElement('div');
            catItem.className = 'category-list-item';
            catItem.dataset.categoryKey = category.key;
            catItem.draggable = true; // Keep draggable

            const categoryName = getText(category.name_key) || category.key;
            const editButtonText = getText('edit_button') || 'Edit';
            const deleteButtonText = getText('delete_button') || 'Delete';
            const dragHintText = getText('drag_to_reorder') || 'Drag to reorder';

            // Add Edit and Delete buttons
            catItem.innerHTML = `
                <span class="category-name">${categoryName}</span>
                <div class="category-actions">
                     <button class="button small-button action-button edit-category-button" data-key="${category.key}" title="${editButtonText}">
                        <i class="fas fa-edit"></i>
                     </button>
                     <button class="button small-button action-button delete-category-button" data-key="${category.key}" title="${deleteButtonText}">
                        <i class="fas fa-trash"></i>
                     </button>
                    <span class="drag-handle" title="${dragHintText}">
                        <i class="fas fa-grip-vertical"></i>
                    </span>
                </div>
            `;

            // Add event listeners
            catItem.addEventListener('dragstart', handleCategoryDragStart);
            catItem.addEventListener('dragover', handleDragOver);
            catItem.addEventListener('dragleave', handleDragLeave);
            catItem.addEventListener('drop', handleCategoryDrop);
            catItem.addEventListener('dragend', handleDragEnd);

            // Click listener: navigate if not clicking actions or drag handle
            catItem.addEventListener('click', (e) => {
                if (!e.target.closest('.category-actions') && !e.target.closest('.drag-handle')) {
                    showScreen9View('products', category.key);
                }
            });

            // Add listeners for new buttons *within* this loop iteration
            const editBtn = catItem.querySelector('.edit-category-button');
            const deleteBtn = catItem.querySelector('.delete-category-button');
            editBtn?.addEventListener('click', (e) => {
                e.stopPropagation(); // Prevent category navigation
                openEditCategoryModal(category.key);
            });
            deleteBtn?.addEventListener('click', (e) => {
                e.stopPropagation(); // Prevent category navigation
                handleDeleteCategory(category.key); // Calls custom confirm now
            });


            categoryListContainer.appendChild(catItem);
        });
    }

    function renderProductGridForCategory(categoryKey) {
        if (!productGridContainer) return; productGridContainer.innerHTML = '';
        const category = categories.find(c => c.key === categoryKey); if (!category) { productGridContainer.innerHTML = `<p class="empty-cart-message">${getText('error_loading_products')}</p>`; return; }
        // Filter baseMenuData to only include products that are in this category AND in the category's ordered list
        const productsToShow = category.productIds
             .map(productId => getProductData(productId)) // Get product data
             .filter(product => product && product.category === categoryKey); // Ensure data exists and category matches


        productsToShow.forEach(product => {
            const gridItem = document.createElement('div'); gridItem.className = 'product-grid-item-admin'; gridItem.dataset.productId = product.id; gridItem.draggable = true;
            const name = getText(product.name_key); const price = formatPrice(product.price); const editText = getText('edit_button'); const removeText = getText('remove_button'); // Use generic remove
             // Add quantity display
            const quantityText = product.quantity === 999 ? '∞' : product.quantity;
            const quantityHeader = getText('product_quantity_header'); // Get translated header
            gridItem.innerHTML = `<img src="${product.image}" alt="${name}" onerror="this.src='https://via.placeholder.com/100x75/eee?text=Img'; this.onerror=null;"><p class="product-name-admin" title="${name}">${name}</p><span class="product-price-admin">${price}</span><span class="product-quantity-admin">${quantityHeader}: ${quantityText}</span><div class="admin-actions-overlay"><button class="button small-button action-button edit-product-button" data-id="${product.id}" title="${editText}"><i class="fas fa-edit"></i></button><button class="button small-button action-button remove-product-button" data-id="${product.id}" title="${removeText}"><i class="fas fa-trash"></i></button></div>`;
            gridItem.addEventListener('dragstart', handleProductDragStart); gridItem.addEventListener('dragover', handleDragOver); gridItem.addEventListener('dragleave', handleDragLeave); gridItem.addEventListener('drop', handleProductDrop); gridItem.addEventListener('dragend', handleDragEnd);
            const editBtn = gridItem.querySelector('.edit-product-button'); const removeBtn = gridItem.querySelector('.remove-product-button');
            editBtn?.addEventListener('click', (e) => { e.stopPropagation(); openEditProductModal(product.id); });
            removeBtn?.addEventListener('click', (e) => { e.stopPropagation(); handleRemoveProduct(product.id); }); // Calls custom confirm now
            productGridContainer.appendChild(gridItem);
        });
        if (productsToShow.length === 0) { productGridContainer.innerHTML = `<p class="empty-cart-message" style="grid-column: 1 / -1;">${getText('no_products_in_category')}</p>`; }
    }

    function setupAddProductFormForCategory(categoryKey) {
        if (!addProductFormContainer || !newProductCategoryKeyInput || !addProductCategoryName) return;
        const categoryData = categories.find(c => c.key === categoryKey); const categoryName = categoryData ? getText(categoryData.name_key) : categoryKey;
        newProductCategoryKeyInput.value = categoryKey; addProductCategoryName.textContent = categoryName;

        // Get new EN/AR inputs
        const nameEnInput = addProductFormContainer.querySelector('#new-product-name-en');
        const nameArInput = addProductFormContainer.querySelector('#new-product-name-ar');
        const descEnInput = addProductFormContainer.querySelector('#new-product-desc-en');
        const descArInput = addProductFormContainer.querySelector('#new-product-desc-ar');
        const priceInput = addProductFormContainer.querySelector('#new-product-price');
        const quantityInput = addProductFormContainer.querySelector('#new-product-quantity');
        const imageInput = addProductFormContainer.querySelector('#new-product-image');
        const errorMsg = addProductFormContainer.querySelector('#add-product-error');

        // Reset all fields
        if (nameEnInput) nameEnInput.value = '';
        if (nameArInput) nameArInput.value = '';
        if (descEnInput) descEnInput.value = '';
        if (descArInput) descArInput.value = '';
        if (priceInput) priceInput.value = '';
        if (quantityInput) quantityInput.value = '';
        if (imageInput) imageInput.value = '';
        if (errorMsg) errorMsg.style.display = 'none';

        // Update currency symbol in price label placeholder
         const priceLabel = addProductFormContainer.querySelector('label[data-lang-key="product_price_label"]');
         if(priceLabel) {
              priceLabel.textContent = getText('product_price_label').replace('{currency}', getCurrency());
         }
    }
    // --- End Screen 9 View Management & Rendering ---

    // --- START: Category Management Functions ---
    function handleAddCategory() {
        console.log("handleAddCategory function started"); // <<< ADD LOG
        if (!newCategoryNameEnInput || !newCategoryNameArInput || !addCategoryErrorMsg) {
             console.error("Add category form elements missing."); // <<< ADD LOG
             return;
        }
        addCategoryErrorMsg.style.display = 'none';

        const nameEn = newCategoryNameEnInput.value.trim();
        const nameAr = newCategoryNameArInput.value.trim();

        console.log(`Adding category: EN='${nameEn}', AR='${nameAr}'`); // <<< ADD LOG

        if (!nameEn || !nameAr) {
            console.log("Validation Failed: Missing category names"); // <<< ADD LOG
            addCategoryErrorMsg.textContent = getText('add_category_error_generic');
            addCategoryErrorMsg.style.display = 'block';
            return; // EXIT POINT 1
        }

        // Key generation - ensure it's unique
        let potentialKeyBase = nameEn.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');
        if (!potentialKeyBase) { potentialKeyBase = 'category'; } // Fallback key base

        let newCategoryKey = potentialKeyBase;
        let counter = 1;
        // Ensure uniqueness by adding a counter or timestamp if base exists
        while (categories.some(c => c.key === newCategoryKey)) {
             newCategoryKey = `${potentialKeyBase}-${counter}`;
             counter++;
        }

        const newNameKey = `sort_${newCategoryKey}`;

        // Check if a translation key with the *same value* already exists
        // This is a more robust check than just the generated key name
        const nameExists = Object.values(translations).some(t =>
             (t.en?.toLowerCase() === nameEn.toLowerCase() && t.ar === nameAr) ||
             (t.ar?.toLowerCase() === nameAr.toLowerCase() && t.en === nameEn)
        );

        if (nameExists) {
             console.log("Validation Failed: Category name (translation) already exists"); // <<< ADD LOG
             addCategoryErrorMsg.textContent = getText('add_category_error_exists');
             addCategoryErrorMsg.style.display = 'block';
             return; // EXIT POINT 3 (Prevent adding duplicate names)
        }


        console.log("Validation passed. Adding category data..."); // <<< ADD LOG
        // Add to translations
        translations[newNameKey] = { en: nameEn, ar: nameAr };
        saveTranslations(); // *** SAVE TRANSLATIONS ***
        // Add to categories array
        categories.push({ key: newCategoryKey, name_key: newNameKey, productIds: [] });
        saveCategories(); // *** SAVE CATEGORIES ***

        renderCategoryList();
        populateSortButtons();
        updateProductCategoryDropdowns();
        updateLanguageUI(); // Refresh UI for new translation key

        // Clear form
        newCategoryNameEnInput.value = '';
        newCategoryNameArInput.value = '';

        console.log(`Category added successfully in function: Key=${newCategoryKey}`); // <<< ADD LOG
        showCustomAlert(getText('add_category_success').replace('{name}', nameEn));

        // Send update via WebSocket
        sendWebSocketMessage({
            type: 'admin_category_added',
            payload: { category: categories[categories.length - 1], translations: { [newNameKey]: translations[newNameKey] } }
        });
        console.log("Sent 'admin_category_added' message via WebSocket.");
    }

    function openEditCategoryModal(categoryKey) {
        if (!editCategoryModalOverlay || !categoryKey) return;

        const category = categories.find(c => c.key === categoryKey);
        if (!category) {
            console.error(`Category with key ${categoryKey} not found.`);
            return;
        }

        // Find the translation data, falling back if necessary
        const nameData = translations[category.name_key] || { en: '', ar: '' };
        // Ensure translation exists, create a placeholder if not
        if (!translations[category.name_key]) {
            translations[category.name_key] = { en: category.key, ar: category.key }; // Default to key if translation missing
            saveTranslations(); // Save the new placeholder translation
            nameData.en = category.key;
            nameData.ar = category.key;
             console.warn(`Translation key ${category.name_key} missing for category ${category.key}, created placeholder.`);
        }


        // Populate hidden fields
        editCategoryKeyInput.value = category.key;
        editCategoryNameKeyInput.value = category.name_key;

        // Populate visible fields
        editCategoryNameEnInput.value = nameData.en || '';
        editCategoryNameArInput.value = nameData.ar || '';

        editCategoryErrorMsg.style.display = 'none'; // Hide previous errors
        updateEditCategoryModalLanguage(); // Ensure modal text is correct lang
        editCategoryModalOverlay.classList.add('visible');
        editCategoryNameEnInput.focus();
    }

    function handleSaveCategoryEdit() {
        if (!editCategoryKeyInput || !editCategoryNameKeyInput || !editCategoryNameEnInput || !editCategoryNameArInput || !editCategoryErrorMsg) return;
        editCategoryErrorMsg.style.display = 'none';

        const categoryKey = editCategoryKeyInput.value;
        const nameKey = editCategoryNameKeyInput.value;
        const nameEn = editCategoryNameEnInput.value.trim();
        const nameAr = editCategoryNameArInput.value.trim();

        if (!categoryKey || !nameKey || !nameEn || !nameAr) {
            editCategoryErrorMsg.textContent = getText('edit_category_error_generic');
            editCategoryErrorMsg.style.display = 'block';
            return;
        }

        // Check if the new name already exists for *another* category's translation key
        const nameExistsForOtherCategory = categories.some(cat => {
             if (cat.key === categoryKey) return false; // Skip the category being edited
             const existingTranslation = translations[cat.name_key];
             return existingTranslation &&
                    ((existingTranslation.en?.toLowerCase() === nameEn.toLowerCase()) || (existingTranslation.ar === nameAr));
        });

         if (nameExistsForOtherCategory) {
              editCategoryErrorMsg.textContent = getText('add_category_error_exists'); // Reuse the error message
              editCategoryErrorMsg.style.display = 'block';
              console.log("Validation Failed: Edited category name conflicts with another category's name.");
              return;
         }


        // Update translations object
        if (translations[nameKey]) {
            translations[nameKey].en = nameEn;
            translations[nameKey].ar = nameAr;
        } else {
            translations[nameKey] = { en: nameEn, ar: nameAr };
            console.warn(`Translation key ${nameKey} was missing during edit, created new entry.`);
        }
        saveTranslations(); // *** SAVE TRANSLATIONS ***


        // Close modal, refresh UI
        hideEditCategoryModal();
        renderCategoryList(); // Update the list display (names)
        populateSortButtons(); // Update sort buttons on screen 3 (names)
        updateProductCategoryDropdowns(); // Update dropdowns in modals (names)
        updateLanguageUI(); // Refresh general UI just in case (updates elements based on data-lang-key)

        console.log(`Category ${categoryKey} updated.`);
        showCustomAlert(getText('edit_category_success').replace('{name}', nameEn));

        // Send update via WebSocket
        sendWebSocketMessage({
            type: 'admin_category_updated',
            payload: { categoryKey: categoryKey, nameKey: nameKey, translations: { [nameKey]: translations[nameKey] } }
        });
        console.log("Sent 'admin_category_updated' message via WebSocket.");
    }

    function hideEditCategoryModal() {
        if (!editCategoryModalOverlay) return;
        editCategoryModalOverlay.classList.remove('visible');
        setTimeout(() => {
            if(editCategoryKeyInput) editCategoryKeyInput.value = '';
            if(editCategoryNameKeyInput) editCategoryNameKeyInput.value = '';
            if(editCategoryNameEnInput) editCategoryNameEnInput.value = '';
            if(editCategoryNameArInput) editCategoryNameArInput.value = '';
            if(editCategoryErrorMsg) editCategoryErrorMsg.style.display = 'none';
        }, 300);
    }

    function updateEditCategoryModalLanguage() {
        const titleEl = editCategoryModalBox?.querySelector('h3');
        if(titleEl) titleEl.textContent = getText('edit_category_title');
        if(editCategoryErrorMsg) editCategoryErrorMsg.textContent = getText('edit_category_error_generic');
        if(editCategoryCancelButton) editCategoryCancelButton.textContent = getText('cancel_button');
        if(editCategorySaveButton) editCategorySaveButton.textContent = getText('save_changes_button');
        // Labels/Placeholders use data-lang attributes, updated by updateLanguageUI
    }


    function handleDeleteCategory(categoryKey) {
        if (!categoryKey) return;

        const categoryIndex = categories.findIndex(c => c.key === categoryKey);
        if (categoryIndex === -1) {
            console.error(`Category with key ${categoryKey} not found for deletion.`);
            return;
        }

        const category = categories[categoryIndex];
        const name = getText(category.name_key) || category.key;

        // Prevent deletion if category has products listed in its productIds array
        if (category.productIds && category.productIds.length > 0) {
            const errorMsgText = getText('delete_category_error_not_empty').replace('{name}', name);
            showCustomAlert(errorMsgText, 'Error'); // Use a generic error title perhaps
            return;
        }

        const confirmMessage = getText('confirm_delete_category_message').replace('{name}', name);

        // --- Use Custom Confirm ---
        showCustomConfirm(
            confirmMessage,
            'confirm_action_title', // Optional: specific title key
            'delete_confirm_button', // Use specific "Delete" button text
            'cancel_button',
            () => { // onConfirm callback
                // Actual deletion logic moved here
                // Remove the category from the categories array
                categories.splice(categoryIndex, 1);
                saveCategories(); // *** SAVE CATEGORIES ***

                // Check if the deleted category's key is still used by any product in baseMenuData
                const productsStillUsingCategory = baseMenuData.filter(p => p.category === categoryKey);
                if (productsStillUsingCategory.length > 0) {
                     console.warn(`Deleted category key '${categoryKey}' is still referenced by ${productsStillUsingCategory.length} products. These products might appear under 'No categories' or be inaccessible until assigned a new category.`);
                     // Note: We are NOT deleting products here. The user should move products first.
                     // This is just a warning in case the product list wasn't empty despite the category.productIds check.
                }

                // Optional: Clean up translation if the key is only used by this category
                // For this simulation, let's delete the translation key assuming it's unique for categories
                // and doesn't conflict with item name/desc keys.
                // A more robust approach might track translation key usage.
                if (category.name_key.startsWith('sort_') && translations[category.name_key]) {
                     delete translations[category.name_key];
                     saveTranslations(); // *** SAVE TRANSLATIONS ***
                     console.log(`Deleted translation key '${category.name_key}'`);
                } else {
                    console.warn(`Translation key '${category.name_key}' did not match expected format or does not exist. Not deleting translation key.`);
                }


                // Refresh UI
                renderCategoryList(); // Refresh display (category is gone)
                populateSortButtons(); // Update sort buttons on screen 3 (category is gone)
                updateProductCategoryDropdowns(); // Update dropdowns in modals (category is gone)
                updateLanguageUI(); // Refresh general UI

                console.log(`Category ${categoryKey} deleted.`);
                showCustomAlert(getText('delete_category_success').replace('{name}', name));

                 // If the deleted category was the one currently being viewed in Product Management (Screen 9),
                 // switch back to the category list view.
                 if (currentScreen?.id === 'screen-9' && currentMgmtView === 'products' && currentMgmtCategory === categoryKey) {
                      showScreen9View('categories');
                 }

                 // Send update via WebSocket
                 sendWebSocketMessage({
                     type: 'admin_category_deleted',
                     payload: { categoryKey: categoryKey, nameKey: category.name_key } // Send key and name_key
                 });
                 console.log("Sent 'admin_category_deleted' message via WebSocket.");
            }
            // No specific onCancel action needed other than hiding the modal
        );
        // --- End Custom Confirm ---
    }
    // --- END: Category Management Functions ---


    // --- START: Product Management Functions (Screen 9) ---
    function handleAddNewProduct() {
         console.log("handleAddNewProduct function started"); // <<< ADD LOG
         const addFormContainer = currentScreen?.querySelector('#add-product-form-container'); if (!addFormContainer) { console.error("Add form not found."); return; }
         const categoryKeyInput = addFormContainer.querySelector('#new-product-category-key'); const currentCategoryKey = categoryKeyInput?.value; if (!currentCategoryKey) { console.error("Category key not set."); return; }

         // Get ALL necessary inputs, including EN/AR
         const nameEnInput = addFormContainer.querySelector('#new-product-name-en');
         const nameArInput = addFormContainer.querySelector('#new-product-name-ar');
         const descEnInput = addFormContainer.querySelector('#new-product-desc-en');
         const descArInput = addProductFormContainer.querySelector('#new-product-desc-ar');
         const priceInput = addProductFormContainer.querySelector('#new-product-price');
         const quantityInput = addProductFormContainer.querySelector('#new-product-quantity');
         const imageInput = addProductFormContainer.querySelector('#new-product-image');
         const errorMsg = addProductFormContainer.querySelector('#add-product-error');

         if (!nameEnInput || !nameArInput || !descEnInput || !descArInput || !priceInput || !quantityInput || !imageInput || !errorMsg) { console.error("Add product form elements missing."); return; }

         console.log("Inputs found, proceeding with validation..."); // <<< ADD LOG
         errorMsg.style.display = 'none';

         // Get values from EN/AR fields
         const nameEn = nameEnInput.value.trim();
         const nameAr = nameArInput.value.trim();
         const descriptionEn = descEnInput.value.trim();
         const descriptionAr = descArInput.value.trim();
         const priceStr = priceInput.value;
         const quantityStr = quantityInput.value;
         const imageUrl = imageInput.value.trim();
         const category = currentCategoryKey;

         // Validation (Include EN/AR fields)
         if (!nameEn || !nameAr || !descriptionEn || !descriptionAr || !priceStr || quantityStr === '' || !imageUrl || !category) { // Check quantityStr explicitly for empty string
             console.log("Validation Failed: Missing fields"); // <<< ADD LOG
             errorMsg.textContent = getText('add_product_error_en_ar_generic'); // Use new error key
             errorMsg.style.display = 'block';
             return; // EXIT POINT 1
         }
         const price = parseFloat(priceStr); if (isNaN(price) || price < 0) {
             console.log("Validation Failed: Invalid price"); // <<< ADD LOG
             errorMsg.textContent = getText('add_product_error_price'); errorMsg.style.display = 'block'; return; // EXIT POINT 2
        }
         const quantity = parseInt(quantityStr, 10); if (isNaN(quantity) || quantity < 0) { // Allow 0 quantity
            console.log("Validation Failed: Invalid quantity"); // <<< ADD LOG
            errorMsg.textContent = getText('add_product_error_quantity'); errorMsg.style.display = 'block'; return; // EXIT POINT 3
        }
        // Basic URL check - using try...catch for robustness
         let isValidUrl = false;
         try {
            new URL(imageUrl); // Try creating a URL object
            isValidUrl = true;
         } catch (_) {
            isValidUrl = false; // Failed to parse
         }
         if (!isValidUrl) {
             console.log("Validation Failed: Invalid image URL"); // <<< ADD LOG
             errorMsg.textContent = getText('add_product_error_image'); errorMsg.style.display = 'block'; return; // EXIT POINT 4
         }
         // --- End Validation ---
         console.log("Validation Passed. Creating product..."); // <<< ADD LOG

         // Create a unique ID for the product
         const newId = `prod-${Date.now()}-${Math.random().toString(36).substring(2, 8)}`; // More robust unique ID

         // Create unique keys for name and description translations
         const nameKey = `item_name_${newId}`;
         const descKey = `item_desc_${newId}`;

         // Populate translations with both languages
         translations[nameKey] = { en: nameEn, ar: nameAr };
         translations[descKey] = { en: descriptionEn, ar: descriptionAr };
         saveTranslations(); // *** SAVE TRANSLATIONS ***

         const newProduct = {
             id: newId, price: price, image: imageUrl, category: category,
             quantity: quantity, name_key: nameKey, description_key: descKey
         };

         baseMenuData.push(newProduct);
         saveProducts(); // *** SAVE PRODUCTS ***

         const categoryIndex = categories.findIndex(c => c.key === currentCategoryKey);
         if (categoryIndex > -1) {
              // Add the new product ID to the end of the productIds list for this category
              categories[categoryIndex].productIds.push(newId);
              saveCategories(); // *** SAVE CATEGORIES (order changed) ***
              console.log(`Added product ID '${newId}' to category '${currentCategoryKey}' list.`);
         } else {
              console.warn(`Category ${currentCategoryKey} not found in categories array during product add. This should not happen if the dropdown/view logic is correct.`);
              // Attempt to re-sync categories just in case
              syncCategoriesWithBaseData();
              saveCategories();
         }

         renderProductGridForCategory(currentCategoryKey); // Refresh the current product view
         populateMenuGrid(); // Refresh main menu (screen 3)
         updateLanguageUI(); // Refresh UI for new translation keys

         // Clear EN/AR fields as well
         nameEnInput.value = ''; nameArInput.value = ''; descEnInput.value = ''; descArInput.value = ''; priceInput.value = ''; quantityInput.value = ''; imageInput.value = '';
         addProductErrorMsg.style.display = 'none';

         // Send update via WebSocket
         sendWebSocketMessage({
             type: 'admin_product_added',
             payload: {
                 product: newProduct,
                 categoryKey: currentCategoryKey,
                 // Include the translations for the new keys
                 translations: {
                     [nameKey]: translations[nameKey], // Send the name translation object {en: ..., ar: ...}
                     [descKey]: translations[descKey]  // Send the desc translation object {en: ..., ar: ...}
                 }
             }
         });
         console.log("Sent 'admin_product_added' message via WebSocket with translations.");

         console.log("Product added successfully.");
         setTimeout(() => { showCustomAlert(getText('add_product_success').replace('{name}', nameEn)); }, 100);
    }

    function handleRemoveProduct(productId) {
        const productIndex = baseMenuData.findIndex(item => item.id === productId);
        if (productIndex === -1) {
            console.error(`Product ${productId} not found.`);
            return;
        }
        const productName = getText(baseMenuData[productIndex].name_key);
        const productCategory = baseMenuData[productIndex].category;
        const productToRemove = baseMenuData[productIndex]; // Get product data before splicing

        const confirmMessage = getText('confirm_remove_product_message').replace('{name}', productName);

        // --- Use Custom Confirm ---
        showCustomConfirm(
            confirmMessage,
            'confirm_action_title', // Optional: specific title key
            'delete_confirm_button', // Use specific "Delete" button text
            'cancel_button',
            () => { // onConfirm callback
                // Remove product from baseMenuData
                const removedProduct = baseMenuData.splice(productIndex, 1)[0];
                saveProducts(); // *** SAVE PRODUCTS ***

                // Remove product ID from its category's list in the 'categories' array
                const categoryIndex = categories.findIndex(c => c.key === productCategory);
                if (categoryIndex > -1) {
                    const productIdsArray = categories[categoryIndex].productIds;
                    const idIndex = productIdsArray.indexOf(productId);
                    if (idIndex > -1) {
                        productIdsArray.splice(idIndex, 1);
                        saveCategories(); // *** SAVE CATEGORIES ***
                        console.log(`Removed product ID '${productId}' from category '${productCategory}' list.`);
                    } else {
                        console.warn(`Product ID '${productId}' not found in category '${productCategory}' order array during removal.`);
                    }
                } else {
                    console.warn(`Category '${productCategory}' not found in categories array during product removal.`);
                }

                // Optional: Clean up translation keys (assume unique for simulation)
                // Check if the keys are still used by any other product before deleting
                 const isNameKeyUsed = baseMenuData.some(p => p.name_key === removedProduct.name_key);
                 const isDescKeyUsed = baseMenuData.some(p => p.description_key === removedProduct.description_key);

                 if (!isNameKeyUsed && translations[removedProduct.name_key]) {
                      delete translations[removedProduct.name_key];
                      console.log(`Deleted unused translation key: ${removedProduct.name_key}`);
                 } else if (isNameKeyUsed) {
                      console.log(`Translation key ${removedProduct.name_key} is still used by other products.`);
                 } else {
                      console.warn(`Translation key ${removedProduct.name_key} not found.`);
                 }

                if (!isDescKeyUsed && translations[removedProduct.description_key]) {
                    delete translations[removedProduct.description_key];
                     console.log(`Deleted unused translation key: ${removedProduct.description_key}`);
                 } else if (isDescKeyUsed) {
                      console.log(`Translation key ${removedProduct.description_key} is still used by other products.`);
                 } else {
                       console.warn(`Translation key ${removedProduct.description_key} not found.`);
                 }
                 saveTranslations(); // *** SAVE TRANSLATIONS ***


                // Refresh views
                // Only re-render the product grid if the user was viewing that category
                if (currentScreen?.id === 'screen-9' && currentMgmtView === 'products' && currentMgmtCategory === productCategory) {
                    renderProductGridForCategory(currentMgmtCategory);
                } else if (currentScreen?.id === 'screen-9' && currentMgmtView === 'categories') {
                     // If viewing categories, the category list might need re-render if a category became empty (though the check prevents this)
                     // In a real app, this might update product counts shown in category list. Not needed here.
                }

                populateMenuGrid(); // Refresh main menu

                updateLanguageUI(); // Ensure UI is consistent after potential translation key removal

                console.log(`Product ${productId} removed.`);
                showCustomAlert(getText('remove_product_success').replace('{name}', productName));

                // Send update via WebSocket
                sendWebSocketMessage({
                    type: 'admin_product_removed',
                    payload: { productId: productId, categoryKey: productCategory } // Send ID and original category
                });
                console.log("Sent 'admin_product_removed' message via WebSocket.");
            }
        );
    }


    // --- Edit Product Modal Functions ---
    function showEditProductModal() {
        if (!editProductModalOverlay) return;
        updateProductCategoryDropdowns(); // Refresh category list before showing
        updateEditModalLanguage();
        if(editProductErrorMsg) editProductErrorMsg.style.display = 'none';
        requestAnimationFrame(() => {
            editProductModalOverlay.classList.add('visible');
            // Focus the first input after modal is visible
            const firstInput = editProductModalBox?.querySelector('input[type="text"], input[type="number"], select');
            if (firstInput) firstInput.focus();
             // Reset scroll position of the form-box
             const formBox = editProductModalBox?.querySelector('.form-box');
             if (formBox) formBox.scrollTop = 0;
        });
    }

    function hideEditProductModal() {
        if (!editProductModalOverlay) return;
        editProductModalOverlay.classList.remove('visible');
        setTimeout(() => {
            // Clear fields
            if(editProductIdInput) editProductIdInput.value = '';
            if(editProductNameEnInput) editProductNameEnInput.value = '';
            if(editProductNameArInput) editProductNameArInput.value = '';
            if(editProductDescEnInput) editProductDescEnInput.value = '';
            if(editProductDescArInput) editProductDescArInput.value = '';
            if(editProductPriceInput) editProductPriceInput.value = '';
            if(editProductQuantityInput) editProductQuantityInput.value = '';
            if(editProductImageInput) editProductImageInput.value = '';
            if(editProductCategorySelect) editProductCategorySelect.value = categories[0]?.key || ''; // Reset to first available category
            if(editProductErrorMsg) editProductErrorMsg.style.display = 'none';
            if(editProductModalBox) delete editProductModalBox.dataset.editingProductId; // Clear dataset
        }, 300);
    }

    function updateEditModalLanguage() { // Updated to use new EN/AR elements
        const titleEl = editProductModalBox?.querySelector('h3');
        const errorEl = editProductModalBox?.querySelector('#edit-product-error');
        const cancelBtn = editProductModalBox?.querySelector('#edit-product-cancel');
        const saveBtn = editProductModalBox?.querySelector('#edit-product-save');

        if(titleEl) titleEl.textContent = getText('edit_product_title');
        if(cancelBtn) cancelBtn.textContent = getText('cancel_button');
        if(saveBtn) saveBtn.textContent = getText('save_changes_button');

        editProductModalBox?.querySelectorAll('label[data-lang-key]').forEach(el => {
            const key = el.dataset.langKey;
            let translation = getText(key);
            if (key === 'product_price_label') { translation = translation.replace('{currency}', getCurrency()); }
            el.textContent = translation;
        });
         editProductModalBox?.querySelectorAll('input[data-lang-placeholder-key]').forEach(el => {
             const key = el.dataset.langPlaceholderKey;
             el.placeholder = getText(key);
         });
         // Update dynamically populated select options
         editProductCategorySelect?.querySelectorAll('option').forEach(opt => {
             const cat = categories.find(c => c.key === opt.value);
             if(cat) opt.textContent = getText(cat.name_key) || cat.key;
         });
        if(errorEl) errorEl.textContent = getText('edit_product_error_generic'); // Use the generic one here, specific validation is in handleSave
    }

    function openEditProductModal(productId) {
        const product = getProductData(productId); if (!product || !editProductModalOverlay) { console.error(`Product ${productId} not found.`); return; }

        // Get EN/AR names/descriptions from translations, falling back if keys are missing
        const nameData = translations[product.name_key] || { en: '', ar: '' };
        const descData = translations[product.description_key] || { en: '', ar: '' };

        editProductIdInput.value = product.id;
        // Populate EN/AR fields
        editProductNameEnInput.value = nameData.en || '';
        editProductNameArInput.value = nameData.ar || '';
        editProductDescEnInput.value = descData.en || '';
        editProductDescArInput.value = descData.ar || '';

        editProductPriceInput.value = product.price;
        editProductQuantityInput.value = product.quantity;
        editProductImageInput.value = product.image;
        updateProductCategoryDropdowns(); // Ensure dropdown is populated *before* setting value
        editProductCategorySelect.value = product.category; // Set selected category AFTER populating

        editProductModalBox.dataset.editingProductId = productId; // Store ID in dataset for validation/reference
        showEditProductModal(); // This now calls update dropdowns and language
    }

    function handleSaveProductEdit() {
         const productId = editProductIdInput?.value; if (!productId || !editProductModalBox || !editProductErrorMsg) { console.error("Required elements not found."); return; }
         editProductErrorMsg.style.display = 'none';

         const productIndex = baseMenuData.findIndex(item => item.id === productId); if (productIndex === -1) { console.error(`Product ${productId} not found.`); hideEditProductModal(); return; }

         // Get values from EN/AR fields
         const nameEn = editProductNameEnInput.value.trim();
         const nameAr = editProductNameArInput.value.trim();
         const descriptionEn = editProductDescEnInput.value.trim();
         const descriptionAr = editProductDescArInput.value.trim();
         const priceStr = editProductPriceInput.value;
         const quantityStr = editProductQuantityInput.value;
         const imageUrl = editProductImageInput.value.trim();
         const newCategory = editProductCategorySelect.value;

         // --- Validation (Include EN/AR) ---
         if (!nameEn || !nameAr || !descriptionEn || !descriptionAr || !priceStr || quantityStr === '' || !imageUrl || !newCategory) { // Check quantityStr explicitly for empty string
            editProductErrorMsg.textContent = getText('add_product_error_en_ar_generic'); // Use the more specific error
            editProductErrorMsg.style.display = 'block';
            return;
         }
        const price = parseFloat(priceStr); if (isNaN(price) || price < 0) { editProductErrorMsg.textContent = getText('edit_product_error_price'); editProductErrorMsg.style.display = 'block'; return; }
        const quantity = parseInt(quantityStr, 10); if (isNaN(quantity) || quantity < 0) { editProductErrorMsg.textContent = getText('edit_product_error_quantity'); editProductErrorMsg.style.display = 'block'; return; } // Allow 0 quantity
        let isValidUrl = false; try { new URL(imageUrl); isValidUrl = true; } catch (_) { isValidUrl = false; }
        if (!isValidUrl) { editProductErrorMsg.textContent = getText('edit_product_error_image'); editProductErrorMsg.style.display = 'block'; return; }
         // --- End Validation ---

         const originalProduct = baseMenuData[productIndex];
         const originalCategory = originalProduct.category;
         const originalNameKey = originalProduct.name_key;
         const originalDescKey = originalProduct.description_key;

         // Update base data
         baseMenuData[productIndex].price = price;
         baseMenuData[productIndex].quantity = quantity;
         baseMenuData[productIndex].image = imageUrl;
         baseMenuData[productIndex].category = newCategory; // Update category key

         saveProducts(); // *** SAVE PRODUCTS ***

         // Update translations
         if (translations[originalNameKey]) {
             translations[originalNameKey].en = nameEn;
             translations[originalNameKey].ar = nameAr;
         } else { translations[originalNameKey] = { en: nameEn, ar: nameAr }; console.warn(`Translation key ${originalNameKey} was missing during edit update, created new entry.`);}
         if (translations[originalDescKey]) {
             translations[originalDescKey].en = descriptionEn;
             translations[originalDescKey].ar = descriptionAr;
         } else { translations[originalDescKey] = { en: descriptionEn, ar: descriptionAr }; console.warn(`Translation key ${originalDescKey} was missing during edit update, created new entry.`);}
         saveTranslations(); // *** SAVE TRANSLATIONS ***


         // Handle category change in the 'categories' array (product order)
         if (originalCategory !== newCategory) {
             console.log(`Category changed for product ${productId}: ${originalCategory} -> ${newCategory}`);
             // Remove from old category's productIds list
             const oldCatIndex = categories.findIndex(c => c.key === originalCategory);
             if (oldCatIndex > -1) {
                 const oldIdIndex = categories[oldCatIndex].productIds.indexOf(productId);
                 if (oldIdIndex > -1) { categories[oldCatIndex].productIds.splice(oldIdIndex, 1); console.log(`Removed product ID '${productId}' from old category '${originalCategory}' list.`);}
                 else { console.warn(`Product ID '${productId}' not found in old category '${originalCategory}' list during category change.`);}
             } else { console.warn(`Original category '${originalCategory}' not found in categories array during product edit category change.`); }
             // Add to new category's productIds list (add to the end for simplicity)
             const newCatIndex = categories.findIndex(c => c.key === newCategory);
             if (newCatIndex > -1) {
                 if (!categories[newCatIndex].productIds.includes(productId)) { // Avoid duplicates if somehow possible
                    categories[newCatIndex].productIds.push(productId);
                    console.log(`Added product ID '${productId}' to new category '${newCategory}' list.`);
                 } else { console.warn(`Product ID '${productId}' already exists in new category '${newCategory}' list.`);}
             } else {
                console.error(`New category '${newCategory}' not found in categories array during product edit category change. This should not happen if the dropdown is correctly populated.`);
             }
             saveCategories(); // *** SAVE CATEGORIES (order changed) ***
         }

         console.log(`Product ${productId} updated.`);
         hideEditProductModal();

         // Refresh views that might show this product or category
         // If we are currently viewing the product grid for either the original or the new category, re-render that grid.
         if (currentScreen?.id === 'screen-9' && currentMgmtView === 'products') {
              if (currentMgmtCategory === originalCategory) {
                   renderProductGridForCategory(originalCategory); // Render the old category's grid (item might be gone)
              }
              // If the new category is different AND we are viewing that new category, render it.
              // This handles the case where the user is viewing the destination category when editing.
              if (originalCategory !== newCategory && currentMgmtCategory === newCategory) {
                   renderProductGridForCategory(newCategory); // Render the new category's grid (item is added)
              }
              // If the user was viewing a DIFFERENT category grid, or was viewing the category list, no product grid re-render is needed for *this* product update.
              // The category list might need re-rendering if product counts were shown (not currently implemented).
              // The sort buttons on screen 3 will be updated by updateLanguageUI.
         }


         populateMenuGrid(); // Refresh main menu (screen 3) - essential as products or categories change
         updateProductCategoryDropdowns(); // Refresh category dropdowns in modals/forms (in case category names changed via Category Edit modal)
         updateLanguageUI(); // Refresh UI for updated translation keys and potentially category names in dropdowns

         const alertProductName = currentLanguage === 'ar' ? nameAr : nameEn;
         showCustomAlert(getText('edit_product_success').replace('{name}', alertProductName), 'edit_product_success_title'); // Use new title key

         // Send update via WebSocket
         sendWebSocketMessage({
             type: 'admin_product_updated',
             payload: {
                 // product: baseMenuData[productIndex], // Send the complete updated product data - revised below
                 productId: productId,
                 updatedFields: { // Send only changed fields + necessary keys
                     price: price,
                     quantity: quantity,
                     image: imageUrl,
                     category: newCategory,
                     // Include the actual updated text for names/descriptions
                     name_en: nameEn,
                     name_ar: nameAr,
                     description_en: descriptionEn,
                     description_ar: descriptionAr,
                     // Include the keys for the server to update the correct translation entry
                     name_key: originalNameKey,
                     description_key: originalDescKey
                 },
                 originalCategoryKey: originalCategory, // Still needed for category list update
                 newCategoryKey: newCategory             // Still needed for category list update
             }
         });
         console.log("Sent 'admin_product_updated' message via WebSocket with updated text.");
     }

    // Helper to populate category dropdowns
    function updateProductCategoryDropdowns() {
        const selectsToUpdate = [editProductCategorySelect /* Add other selects here if needed */ ];
        selectsToUpdate.forEach(selectElement => {
            if (!selectElement) return;
            const currentVal = selectElement.value; // Preserve selection if possible
            selectElement.innerHTML = ''; // Clear existing options

            // Add a default "Select Category" option if needed, though likely not for edit
            // const defaultOption = document.createElement('option');
            // defaultOption.value = '';
            // defaultOption.textContent = 'Select Category...'; // Add translation key if desired
            // defaultOption.disabled = true; // Make it unselectable
            // defaultOption.selected = true; // Make it the default selected option if currentVal is empty
            // selectElement.appendChild(defaultOption);

            if (categories.length === 0) {
                 selectElement.innerHTML = '<option value="">No categories</option>'; // Add a placeholder
                 selectElement.disabled = true; // Disable if no categories
                 selectElement.value = ''; // Ensure value is empty
                 return; // Exit if no categories
            } else {
                 selectElement.disabled = false; // Enable if categories exist
            }

            categories.forEach(cat => {
                const option = document.createElement('option');
                option.value = cat.key;
                option.textContent = getText(cat.name_key) || cat.key; // Set text based on current language
                selectElement.appendChild(option);
            });

            // Try to restore previous selection
            if (currentVal && categories.some(c => c.key === currentVal)) {
                selectElement.value = currentVal;
            } else {
                 selectElement.value = categories[0].key; // Default to first available category
            }
        });
    }
    // --- End Edit Product Modal Functions ---
     // --- END: Product Management Functions ---


    // --- Drag and Drop Handlers ---
    function handleCategoryDragStart(e) { draggedElement = e.target.closest('.category-list-item'); if (!draggedElement) return; e.dataTransfer.effectAllowed = 'move'; e.dataTransfer.setData('text/plain', draggedElement.dataset.categoryKey); setTimeout(() => { draggedElement.classList.add('dragging'); }, 0); }
    function handleProductDragStart(e) { draggedElement = e.target.closest('.product-grid-item-admin'); if (!draggedElement) return; e.dataTransfer.effectAllowed = 'move'; e.dataTransfer.setData('text/plain', draggedElement.dataset.productId); setTimeout(() => { draggedElement.classList.add('dragging'); }, 0); }
    function handleDragOver(e) { e.preventDefault(); e.dataTransfer.dropEffect = 'move'; const targetElement = e.target.closest('.category-list-item, .product-grid-item-admin'); if (targetElement && targetElement !== draggedElement) { document.querySelectorAll('.dragging-over').forEach(el => el.classList.remove('dragging-over')); targetElement.classList.add('dragging-over'); } }
    function handleDragLeave(e) { const targetElement = e.target.closest('.category-list-item, .product-grid-item-admin'); if (targetElement) { targetElement.classList.remove('dragging-over'); } }
    function handleCategoryDrop(e) {
        e.preventDefault(); e.stopPropagation(); const targetElement = e.target.closest('.category-list-item'); if (!targetElement || targetElement === draggedElement || !draggedElement) { handleDragEnd(); return; }
        const draggedCategoryKey = e.dataTransfer.getData('text/plain'); const targetCategoryKey = targetElement.dataset.categoryKey; const draggedIndex = categories.findIndex(c => c.key === draggedCategoryKey); const targetIndex = categories.findIndex(c => c.key === targetCategoryKey); if (draggedIndex === -1 || targetIndex === -1) { console.error("Category drop error."); handleDragEnd(); return; }
        const [draggedItem] = categories.splice(draggedIndex, 1); categories.splice(targetIndex, 0, draggedItem); console.log(`Moved category ${draggedCategoryKey} to index ${targetIndex}`); handleDragEnd(); renderCategoryList(); saveCategories(); populateSortButtons(); // Update sort buttons order

        // --- Send reordered categories to server ---
        sendWebSocketMessage({
            type: 'admin_categories_reordered',
            payload: categories // Send the entire updated categories array
        });
        console.log("Sent 'admin_categories_reordered' message via WebSocket.");
    }
    function handleProductDrop(e) {
        e.preventDefault(); e.stopPropagation(); const targetElement = e.target.closest('.product-grid-item-admin'); if (!targetElement || targetElement === draggedElement || !draggedElement || !currentMgmtCategory) { handleDragEnd(); return; }
        const draggedProductId = e.dataTransfer.getData('text/plain'); const targetProductId = targetElement.dataset.productId; const categoryIndex = categories.findIndex(c => c.key === currentMgmtCategory); if (categoryIndex === -1) { console.error(`Category ${currentMgmtCategory} not found.`); handleDragEnd(); return; } const productIdsArray = categories[categoryIndex].productIds; const draggedIndex = productIdsArray.indexOf(draggedProductId); const targetIndex = productIdsArray.indexOf(targetProductId); if (draggedIndex === -1 || targetIndex === -1) { console.error("Product drop error."); handleDragEnd(); return; }
        const [draggedIdItem] = productIdsArray.splice(draggedIndex, 1); productIdsArray.splice(targetIndex, 0, draggedIdItem); console.log(`Moved product ${draggedProductId} in category ${currentMgmtCategory}`); handleDragEnd(); renderProductGridForCategory(currentMgmtCategory); saveCategories();

        // --- Send reordered categories (containing the updated product order) to server ---
        sendWebSocketMessage({
            type: 'admin_categories_reordered',
            payload: categories // Send the entire updated categories array
        });
        console.log("Sent 'admin_categories_reordered' message via WebSocket after product drop.");
    }
    function handleDragEnd() { document.querySelectorAll('.dragging').forEach(el => el.classList.remove('dragging')); document.querySelectorAll('.dragging-over').forEach(el => el.classList.remove('dragging-over')); draggedElement = null; }
    // --- End Drag and Drop Handlers --

        // --- Discovery Mode Functions ---
        function addBundleToCart(bundleId, buttonElement) {
            const bundle = bundleOffers.find(b => b.id === bundleId); if (!bundle || !buttonElement) return;
            let allStockSufficient = true; const itemsToAdd = [];
            for (const itemId of bundle.itemIds) { const itemData = getProductData(itemId); if (!itemData) { console.warn(`Item ${itemId} not found.`); allStockSufficient = false; break; } const cartItem = cart.find(i => i.id === itemId && !i.isDiscount); const currentCartQuantity = cartItem ? cartItem.quantity : 0; if (itemData.quantity !== 999 && itemData.quantity <= currentCartQuantity) { allStockSufficient = false; showCustomAlert(`Sorry, '${getText(itemData.name_key)}' is out of stock!`, 'checkout_success_title'); break; } itemsToAdd.push({ id: itemId, data: itemData }); }
            if (!allStockSufficient) { return; } let originalTotalPrice = 0;
            itemsToAdd.forEach(itemInfo => {
                originalTotalPrice += itemInfo.data.price;
                const itemExists = cart.find(cartItem => cartItem.id === itemInfo.id && !cartItem.isDiscount);
                if (itemExists) { itemExists.quantity++; }
                else { const cartProductData = { id: itemInfo.data.id, price: itemInfo.data.price, image: itemInfo.data.image, category: itemInfo.data.category, name_key: itemInfo.data.name_key, description_key: itemInfo.data.description_key, quantity: 1 }; cart.push(cartProductData); }
            });
            const discountMultiplier = (100 - bundle.discountPercent) / 100; const finalPrice = Math.round(originalTotalPrice * discountMultiplier); const discountAmount = originalTotalPrice - finalPrice;
            if (discountAmount > 0) {
                // Check if a discount for this bundle already exists to avoid adding multiple times per bundle add click
                const existingDiscountIndex = cart.findIndex(i => i.isDiscount && i.bundleId === bundle.id);
                 if (existingDiscountIndex === -1) {
                     const discountItemId = `discount-${bundleId}-${Date.now()}`; // Unique ID for the discount instance
                     const discountItem = {
                         id: discountItemId,
                         name_key: 'bundle_discount_applied', // Use consistent key
                         price: -discountAmount, // Store the total discount value for the bundle
                         quantity: 1, // Discount item quantity is always 1
                         isDiscount: true,
                         image: 'https://img.icons8.com/ios-filled/50/discount--v1.png', // Generic discount icon
                         bundleId: bundleId // *** STORE THE BUNDLE ID ***
                     };
                     cart.push(discountItem);
                     console.log(`Applied discount: ${discountAmount} for bundle ${bundleId}`);
                 } else {
                      console.log(`Discount already exists for bundle ${bundleId}, not adding again.`);
                      // Optionally update the existing discount item's price if quantity logic changes (not needed with current bundle logic)
                 }
            }
            updateCartUI(); // This will now validate the discount just added and update total
    
            // Button feedback animation
            if (bundleButtonTimeouts[bundleId]) { clearTimeout(bundleButtonTimeouts[bundleId]); } buttonElement.classList.add('added'); const icon = buttonElement.querySelector('i'); const span = buttonElement.querySelector('span'); if (icon) icon.className = 'fas fa-check'; if (span) { span.dataset.langKey = 'bundle_added_button'; span.textContent = getText('bundle_added_button'); } bundleButtonTimeouts[bundleId] = setTimeout(() => { if (buttonElement && buttonElement.classList.contains('added')) { buttonElement.classList.remove('added'); if (icon) icon.className = 'fas fa-cart-plus'; if (span) { span.dataset.langKey = 'add_bundle_button'; span.textContent = getText('add_bundle_button'); } } delete bundleButtonTimeouts[bundleId]; }, 1500);
        }
    
        function populateDiscoveryMode() {
            if (!discoveryBundlesScroller || !discoverySuggestionsGrid || !discoveryCategoriesContainer) return;
            discoveryBundlesScroller.innerHTML = ''; discoverySuggestionsGrid.innerHTML = ''; discoveryCategoriesContainer.innerHTML = ''; const MAX_IMAGES_SHOWN = 4;
            bundleOffers.forEach(bundle => { const card = document.createElement('div'); card.className = 'offer-card bundle-offer'; card.dataset.bundleId = bundle.id; const bundleName = getText(bundle.name_key); const bundleDesc = getText(bundle.description_key); let itemsHtml = `<p class="offer-items"><strong>${getText('includes_items')}</strong> `; let imageGridHtml = ''; let originalTotalPrice = 0; let allItemsFound = true; let imageCount = 0; bundle.itemIds.forEach(itemId => { const itemData = getProductData(itemId); if (itemData) { itemsHtml += `<span>${getText(itemData.name_key)}</span>`; originalTotalPrice += itemData.price; if (imageCount < MAX_IMAGES_SHOWN) { imageGridHtml += `<img src="${itemData.image}" alt="${getText(itemData.name_key)}">`; imageCount++; } } else { allItemsFound = false; console.warn(`Item ${itemId} not found for bundle ${bundle.id}`); } }); itemsHtml += '</p>'; let gridClass = 'offer-image-grid'; if (imageCount === 1) gridClass += ' count-1'; else if (imageCount === 3) gridClass += ' count-3'; const imageGridContainer = `<div class="${gridClass}">${imageGridHtml}</div>`; if (allItemsFound && originalTotalPrice > 0) { const discountMultiplier = (100 - bundle.discountPercent) / 100; const finalPrice = Math.round(originalTotalPrice * discountMultiplier); const discountTag = `<span class="bundle-discount-tag" data-lang-key="discount_tag" data-percent="${bundle.discountPercent}">${getText('discount_tag').replace('{percent}', bundle.discountPercent)}</span>`; card.innerHTML = ` ${discountTag} <h5>${bundleName}</h5> ${imageCount > 0 ? imageGridContainer : ''} <p class="offer-description">${bundleDesc}</p> ${itemsHtml} <div class="offer-actions"> <div class="bundle-pricing"> <span class="bundle-original-price">${getText('original_price')} ${formatPrice(originalTotalPrice)}</span> <span class="bundle-final-price">${getText('bundle_price')} ${formatPrice(finalPrice)}</span> </div> <button class="button rect-button add-bundle-button"> <i class="fas fa-cart-plus"></i> <span data-lang-key="add_bundle_button">${getText('add_bundle_button')}</span> </button> </div>`; discoveryBundlesScroller.appendChild(card); } });
            mealSuggestions.forEach(suggestion => { const gridItem = document.createElement('div'); gridItem.className = 'suggestion-grid-item'; gridItem.dataset.suggestionId = suggestion.id; const suggName = getText(suggestion.name_key); let itemsHtml = `<div class="suggestion-items">`; let itemImagesHtml = ''; let allItemsFound = true; let suggestionTotalPrice = 0; suggestion.itemIds.forEach((itemId, index) => { const itemData = getProductData(itemId); if (itemData) { itemsHtml += `<span>${getText(itemData.name_key)}</span>`; suggestionTotalPrice += itemData.price; itemImagesHtml += `<img src="${itemData.image}" alt="${getText(itemData.name_key)}" title="${getText(itemData.name_key)}">`; if (index < suggestion.itemIds.length - 1) { itemImagesHtml += ` <span class="plus-separator">+</span> `; } } else { allItemsFound = false; console.warn(`Item ${itemId} not found.`); } }); itemsHtml += '</div>'; const itemImagesContainer = `<div class="suggestion-item-images">${itemImagesHtml}</div>`; const totalPriceHtml = `<p class="suggestion-total-price"><strong>${getText('suggestion_total_price')}</strong> ${formatPrice(suggestionTotalPrice)}</p>`; if (allItemsFound) { const buttonHtml = ` <button class="button rect-button add-suggestion-button"> <i class="fas fa-cart-plus"></i> <span data-lang-key="add_suggestion_button">${getText('add_suggestion_button')}</span> </button>`; gridItem.innerHTML = `${itemImagesContainer}<h5>${suggName}</h5>${itemsHtml}${totalPriceHtml}${buttonHtml}`; discoverySuggestionsGrid.appendChild(gridItem); } });
            categories.forEach(category => { const categorySection = document.createElement('div'); categorySection.className = 'discovery-category-section'; const categoryTitle = document.createElement('h5'); categoryTitle.textContent = getText(category.name_key) || category.key; categorySection.appendChild(categoryTitle); const categoryGrid = document.createElement('div'); categoryGrid.className = 'discovery-category-grid';
                 // Filter baseMenuData for items in this category's productIds list for discovery view
                 const productsToDisplay = category.productIds
                     .map(productId => getProductData(productId))
                     .filter(item => item && item.category === category.key); // Ensure product exists and category matches
    
                 productsToDisplay.forEach(item => {
                      const itemEl = document.createElement('div');
                      itemEl.className = 'discovery-category-item';
                      itemEl.dataset.id = item.id;
                      const itemName = getText(item.name_key);
                      const itemPrice = formatPrice(item.price);
                      itemEl.innerHTML = ` <img src="${item.image}" alt="${itemName}"> <p title="${itemName}">${itemName}</p> <span class="price-button">${itemPrice}</span> `;
                      // Add click listener to show item preview, but prevent if clicking the price button
                      itemEl.addEventListener('click', (e) => {
                           if (!e.target.classList.contains('price-button')) {
                                showItemPreview(item.id);
                           }
                      });
                      const priceButton = itemEl.querySelector('.price-button');
                      if (priceButton) {
                           // Add click listener specifically for the price button to add to cart
                           priceButton.addEventListener('click', (e) => {
                                e.stopPropagation(); // Prevent the parent item's click listener
                                addToCart(item.id);
                                // Visual feedback on button
                                priceButton.style.transition = 'transform 0.1s ease-out, background-color 0.1s ease-out';
                                priceButton.style.backgroundColor = 'var(--active-green)';
                                priceButton.style.transform = 'scale(1.1)';
                                setTimeout(() => {
                                     priceButton.style.backgroundColor = ''; // Revert background
                                     priceButton.style.transform = ''; // Revert transform
                                     setTimeout(() => priceButton.style.transition = '', 150); // Remove transition after revert
                                }, 150); // Quick pulse effect
                           });
                      }
                      categoryGrid.appendChild(itemEl);
                 });
                if(productsToDisplay.length > 0) { categorySection.appendChild(categoryGrid); discoveryCategoriesContainer.appendChild(categorySection); }}); updateCartBadge();
        }
        function addSuggestionToCart(suggestionId, buttonElement) {
            const suggestion = mealSuggestions.find(s => s.id === suggestionId); if (!suggestion || !buttonElement) return; let allStockSufficient = true; const itemsToAdd = [];
            for (const itemId of suggestion.itemIds) { const itemData = getProductData(itemId); if (!itemData) { console.warn(`Item ${itemId} not found.`); allStockSufficient = false; break; } const cartItem = cart.find(i => i.id === itemId && !i.isDiscount); const currentCartQuantity = cartItem ? cartItem.quantity : 0; if (itemData.quantity !== 999 && itemData.quantity <= currentCartQuantity) { allStockSufficient = false; showCustomAlert(`Sorry, '${getText(itemData.name_key)}' is out of stock!`, 'checkout_success_title'); break; } itemsToAdd.push({ id: itemId, data: itemData }); }
            if (!allStockSufficient) { return; }
            itemsToAdd.forEach(itemInfo => { const itemExists = cart.find(i => i.id === itemInfo.id && !i.isDiscount); if (itemExists) { itemExists.quantity++; } else { const cartProductData = { id: itemInfo.data.id, price: itemInfo.data.price, image: itemInfo.data.image, category: itemInfo.data.category, name_key: itemInfo.data.name_key, description_key: itemInfo.data.description_key, quantity: 1 }; cart.push(cartProductData); } }); updateCartUI();
            if (suggestionButtonTimeouts[suggestionId]) { clearTimeout(suggestionButtonTimeouts[suggestionId]); } buttonElement.classList.add('added'); const icon = buttonElement.querySelector('i'); const span = buttonElement.querySelector('span'); if (icon) icon.className = 'fas fa-check'; if (span) { span.dataset.langKey = 'suggestion_added_button'; span.textContent = getText('suggestion_added_button'); } suggestionButtonTimeouts[suggestionId] = setTimeout(() => { if (buttonElement && buttonElement.classList.contains('added')) { buttonElement.classList.remove('added'); if (icon) icon.className = 'fas fa-cart-plus'; if (span) { span.dataset.langKey = 'add_suggestion_button'; span.textContent = getText('add_suggestion_button'); } } delete suggestionButtonTimeouts[suggestionId]; }, 1500);
        }
        // --- End Discovery Mode Functions ---
    
        // --- Custom Alert Functions ---
        function updateModalLanguage() { if (customAlertTitle) { const titleKey = customAlertTitle.dataset.langKey || 'checkout_success_title'; customAlertTitle.textContent = getText(titleKey); } if (customAlertCloseBtn) customAlertCloseBtn.textContent = getText('ok_button'); }
        let currentAlertTimeout = null; // Variable to hold the timeout ID
        function showCustomAlert(m, titleKey = 'checkout_success_title', autoHideDelay = null) { 
            if (!customAlertOverlay || !customAlertMessage) return;
            
            console.log(`[showCustomAlert] Called with message: "${m}", titleKey: "${titleKey}", autoHideDelay: ${autoHideDelay}`); // LOG Input

            // Clear any existing auto-hide timeout before showing a new alert
            if (currentAlertTimeout) {
                console.log('[showCustomAlert] Clearing existing auto-hide timeout:', currentAlertTimeout);
                clearTimeout(currentAlertTimeout);
                currentAlertTimeout = null;
            }

            if(customAlertTitle) customAlertTitle.dataset.langKey = titleKey;
            updateModalLanguage(); 
            customAlertMessage.textContent = m; // Assign the message text
            console.log('[showCustomAlert] Set message content to:', customAlertMessage.textContent); // LOG Assigned text

            requestAnimationFrame(() => { 
                customAlertOverlay.classList.add('visible'); 
                console.log('[showCustomAlert] Made overlay visible.'); // LOG Visibility
            });

            // Set auto-hide if delay is provided
            if (typeof autoHideDelay === 'number' && autoHideDelay > 0) {
                console.log(`[showCustomAlert] Setting auto-hide timeout for ${autoHideDelay}ms.`); // LOG Timeout set
                currentAlertTimeout = setTimeout(() => {
                    console.log('[showCustomAlert] Auto-hide timeout fired. Calling hideCustomAlert().'); // LOG Timeout fired
                    hideCustomAlert();
                }, autoHideDelay);
                console.log('[showCustomAlert] Timeout ID set:', currentAlertTimeout);
            } else {
                 console.log('[showCustomAlert] No auto-hide delay provided or invalid.');
            }
        }
        function hideCustomAlert() { 
            console.log('[hideCustomAlert] Function called.'); // LOG Function entry
            if (!customAlertOverlay || !customAlertOverlay.classList.contains('visible')) {
                console.log('[hideCustomAlert] Overlay not found or not visible, exiting.');
                return;
            }
            
            // Clear the timeout if the alert is hidden manually (e.g., by clicking OK) or automatically
            if (currentAlertTimeout) {
                console.log('[hideCustomAlert] Clearing auto-hide timeout:', currentAlertTimeout);
                clearTimeout(currentAlertTimeout);
                currentAlertTimeout = null;
            }

            const msg = customAlertMessage?.textContent;
            customAlertOverlay.classList.remove('visible');
            console.log('[hideCustomAlert] Removed visibility from overlay.');
            // ... (keep the rest of hideCustomAlert logic for potentially refreshing screen 9)
            // ...
        }
        // --- End Custom Alert Functions ---
    
        // --- Passcode Modal Functions ---
        function updatePasscodeModalLanguage() { if(passcodeModalTitle) passcodeModalTitle.textContent = getText('discovery_passcode_modal_title'); if(passcodeModalInput) passcodeModalInput.placeholder = getText('discovery_passcode_prompt'); if(passcodeModalError) passcodeModalError.textContent = getText('discovery_passcode_incorrect_message'); if(passcodeModalOk) passcodeModalOk.textContent = getText('ok_button'); if(passcodeModalCancel) passcodeModalCancel.textContent = getText('cancel_button'); }
        function showPasscodeModal() { if (!passcodeModalOverlay) return; updatePasscodeModalLanguage(); if(passcodeModalInput) passcodeModalInput.value = ''; if(passcodeModalError) passcodeModalError.style.display = 'none'; requestAnimationFrame(() => { passcodeModalOverlay.classList.add('visible'); if(passcodeModalInput) passcodeModalInput.focus(); }); }
        function hidePasscodeModal() { if (!passcodeModalOverlay) return; passcodeModalOverlay.classList.remove('visible'); }
        function handlePasscodeSubmit() {
            const enteredPasscode = passcodeModalInput?.value;
            if (passcodeModalError) passcodeModalError.style.display = 'none'; // Hide error first

            if (enteredPasscode) {
                console.log("[Client] Sending verify_discovery_passcode message.");
                sendWebSocketMessage({ type: 'verify_discovery_passcode', payload: { passcode: enteredPasscode } });
            } else {
                // Should not happen if OK button is disabled for empty input, but as a fallback:
                if (passcodeModalError) {
                    passcodeModalError.textContent = getText('discovery_passcode_incorrect_message'); // Or a "field required" message
                    passcodeModalError.style.display = 'block';
                }
            }
        }
        // --- End Passcode Modal Functions ---
    
         // --- START: Custom Confirmation Modal Functions ---
        function updateConfirmModalLanguage() {
            if (customConfirmTitle) customConfirmTitle.textContent = getText(customConfirmTitle.dataset.langKey || 'confirm_action_title');
            if (customConfirmOkBtn) customConfirmOkBtn.textContent = getText(customConfirmOkBtn.dataset.langKey || 'confirm_button');
            if (customConfirmCancelBtn) customConfirmCancelBtn.textContent = getText(customConfirmCancelBtn.dataset.langKey || 'cancel_button');
        }
    
        function showCustomConfirm(message, titleKey = 'confirm_action_title', confirmButtonKey = 'confirm_button', cancelButtonKey = 'cancel_button', onConfirm, onCancel) {
            if (!customConfirmModalOverlay || !customConfirmMessage || !customConfirmTitle || !customConfirmOkBtn || !customConfirmCancelBtn) {
                console.error("Custom confirm modal elements not found! Falling back to native confirm.");
                // Fallback to native confirm if elements are missing
                if (confirm(message)) { // Use the message directly as it should be pre-translated
                     if (onConfirm) onConfirm();
                } else {
                     if (onCancel) onCancel();
                }
                return;
            }
    
            // Set texts using provided keys
            customConfirmTitle.dataset.langKey = titleKey;
            customConfirmOkBtn.dataset.langKey = confirmButtonKey;
            customConfirmCancelBtn.dataset.langKey = cancelButtonKey;
            updateConfirmModalLanguage(); // Update text content based on keys
    
            customConfirmMessage.textContent = message; // Display the already translated message
    
            // Store callbacks
            currentConfirmCallback = onConfirm;
            currentCancelCallback = onCancel;
    
            // Make visible
            requestAnimationFrame(() => {
                customConfirmModalOverlay.classList.add('visible');
            });
        }
    
        function hideCustomConfirm() {
            if (!customConfirmModalOverlay) return;
            customConfirmModalOverlay.classList.remove('visible');
            // Clear callbacks after hiding
            currentConfirmCallback = null;
            currentCancelCallback = null;
        }
        // --- END: Custom Confirmation Modal Functions ---
    
        // --- START: Config Management Functions ---
    
        function exportConfig() {
            // Collect all relevant translation keys from products and categories
            const relevantTranslationKeys = new Set();
            baseMenuData.forEach(product => {
                if (product.name_key) relevantTranslationKeys.add(product.name_key);
                if (product.description_key) relevantTranslationKeys.add(product.description_key);
            });
            categories.forEach(category => {
                if (category.name_key) relevantTranslationKeys.add(category.name_key);
            });

            const productRelatedTranslations = {};
            relevantTranslationKeys.forEach(key => {
                if (translations[key]) {
                    productRelatedTranslations[key] = translations[key];
                }
            });

            const configData = {
                products: baseMenuData,
                categories: categories,
                productRelatedTranslations: productRelatedTranslations // MODIFIED: Export only relevant translations
                // REMOVED: orders, settings
            };
            const jsonString = JSON.stringify(configData, null, 2); // Beautify JSON with 2 spaces
    
            const blob = new Blob([jsonString], { type: 'application/json' });
            const url = URL.createObjectURL(blob);
            const a = document.createElement('a');
            const dateString = new Date().toISOString().split('T')[0]; // YYYY-MM-DD
            a.download = `canteen_products_config_${dateString}.json`; // MODIFIED: filename
            a.href = url;
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            URL.revokeObjectURL(url); // Clean up
    
            console.log("Product and Category Config exported."); // MODIFIED: log message
        }
    
        function importConfig(file) {
            if (!file) {
                 showCustomAlert(getText('import_config_error_generic'), 'Error');
                 if(importConfigErrorMsg) {
                     importConfigErrorMsg.textContent = getText('import_config_error_generic');
                     importConfigErrorMsg.style.display = 'block';
                 }
                return;
            }
            if(importConfigErrorMsg) importConfigErrorMsg.style.display = 'none'; // Hide previous errors
    
            const reader = new FileReader();
            reader.onload = (event) => {
                try {
                    const importedData = JSON.parse(event.target.result);
                    console.log("Parsed imported product/category data:", importedData);
    
                    // MODIFIED: Basic validation of the imported data structure for products/categories
                    if (!importedData || typeof importedData !== 'object' ||
                        !Array.isArray(importedData.products) ||
                        !Array.isArray(importedData.categories) ||
                        typeof importedData.productRelatedTranslations !== 'object'
                        // REMOVED: validation for orders and settings
                    ) {
                        console.error("Imported product/category data structure is invalid.");
                        showCustomAlert(getText('import_config_error_structure'), 'Error');
                         if(importConfigErrorMsg) {
                             importConfigErrorMsg.textContent = getText('import_config_error_structure');
                             importConfigErrorMsg.style.display = 'block';
                         }
                        return;
                    }
    
                    // MODIFIED: Update confirm message key
                    showCustomConfirm(
                        getText('import_products_config_confirm_message'), // NEW Key for product-specific import
                        'confirm_action_title', 
                        'confirm_button', 
                        'cancel_button',
                        () => { // onConfirm callback
                            // Apply imported data - ONLY products, categories, and their translations
                            baseMenuData = importedData.products;
                            categories = importedData.categories;
                            
                            // Merge productRelatedTranslations into the main translations object
                            // This will overwrite existing keys if they are present in the imported file,
                            // and add new ones. Other translations remain untouched.
                            if (importedData.productRelatedTranslations) {
                                Object.assign(translations, importedData.productRelatedTranslations);
                            }
    
                            // Save imported data to localStorage
                            saveProducts();
                            saveCategories();
                            saveTranslations(); // Save the merged translations
                            // REMOVED: saving orders and general settings
    
                            console.log("Product/Category configuration imported and saved successfully locally.");

                            // MODIFIED: Send only product/category related data to server
                            sendWebSocketMessage({
                                type: 'admin_config_imported',
                                payload: {
                                    products: baseMenuData,
                                    categories: categories,
                                    productRelatedTranslations: importedData.productRelatedTranslations 
                                }
                            });
                            console.log("Sent imported product/category config to server.");
                            
                            // Refresh UI based on new data (orders and general settings are NOT affected)
                            // applyTheme(currentTheme); // Theme is not part of this import
                            updateLanguageUI(); // This will pick up new/updated product/category translations
                            // renderOrderLog(); // Orders are not part of this import
                            // clearOrderPreview();
                            // if(orderSearchInput) orderSearchInput.value = '';
                            // updateDiscoverButtonVisibility(); // Discovery settings not part of this import
                            // updateDiscoveryToggleVisualState();
                            populateSortButtons(); 
                            populateMenuGrid(); 
                            updateProductCategoryDropdowns(); 
    
                            showCustomAlert(getText('import_products_config_success_message'), 'checkout_success_title'); // NEW Key
                             if(importConfigErrorMsg) importConfigErrorMsg.style.display = 'none';
                        },
                        () => {
                             console.log("Product/Category Import cancelled by user.");
                              if(importConfigErrorMsg) importConfigErrorMsg.style.display = 'none';
                        }
                    );
    
                } catch (e) {
                    console.error("Error processing imported product/category file:", e);
                     showCustomAlert(getText('import_config_error_json_parse'), 'Error');
                     if(importConfigErrorMsg) {
                         importConfigErrorMsg.textContent = getText('import_config_error_json_parse');
                         importConfigErrorMsg.style.display = 'block';
                     }
                } finally {
                    if (importConfigInput) importConfigInput.value = '';
                }
            };
    
            reader.onerror = (error) => {
                console.error("Error reading file:", error);
                 showCustomAlert(getText('import_config_error_generic'), 'Error');
                 if(importConfigErrorMsg) {
                     importConfigErrorMsg.textContent = getText('import_config_error_generic');
                     importConfigErrorMsg.style.display = 'block';
                 }
                 if (importConfigInput) importConfigInput.value = '';
            };
    
            reader.readAsText(file); 
        }
    
        // --- END: Config Management Functions ---
    
    
        // --- Event Listeners ---
        // General Navigation
        navigationElements.forEach(e => {
             const targetId = e.dataset.target;
             if (targetId && e.id !== 'item-preview-back-button' && e.id !== 'product-mgmt-back-button') { // Exclude manually handled buttons
                 e.addEventListener('click', () => showScreen(targetId));
             }
         });
    
        loginSubmitButton?.addEventListener('click', () => {
            const email = loginEmailInput.value.trim();
            const password = loginPasswordInput.value;
            const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/; // Simple email format regex

            if(!loginErrorMsg) return;
            loginErrorMsg.style.display = 'none'; // Hide previous errors

            if (!email || !password) {
                loginErrorMsg.textContent = getText('login_error_fields');
                loginErrorMsg.style.display = 'block';
                return;
            }

            // --- NEW: Client-side email format validation ---\n            if (!emailRegex.test(email)) {\n                loginErrorMsg.textContent = getText('login_error_invalid_email') || 'Please enter a valid email address.'; // Need translation key\n                loginErrorMsg.style.display = 'block';\n                return; // Don't proceed if email format is invalid\n            }\n            // --- END: Email validation ---\n\n            // --- Check if canteen is open BEFORE trying to log in ---\n            if (!isCanteenOpen) {\n                showCustomAlert(getText('canteen_closed_login_alert'), 'error_title');\n                return; // Prevent sending login request\n            }\n            // --- End check ---\n\n            // Send login request to server
            console.log(`[Client] Preparing to send login_user message for: ${email}`); // <-- ADDED LOG
            sendWebSocketMessage({ type: 'login_user', payload: { email: email, password: password } });

        });
        gotoAdminLoginButton?.addEventListener('click', () => showScreen('screen-6'));
        registerSubmitButton?.addEventListener('click', () => {
            const email = registerEmailInput.value.trim();
            const password = registerPasswordInput.value;
            const passwordConfirm = registerPasswordConfirmInput.value;
            const activePhoto = registerPhotoPicker?.querySelector('.profile-pic.active');
            const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/; // Simple email format regex

            console.log(`[Register Button Click] Email: ${email}`); // <-- ADDED LOG 1

            if(!registerErrorMsg) return;
            registerErrorMsg.style.display = 'none'; // Hide previous errors

            // Perform client-side validation first
            if (!email || !password || !passwordConfirm) {
                console.error("[Register Check] Failed: Missing fields."); // LOG ERROR
                registerErrorMsg.textContent = getText('register_error_fields'); // Use translation key
                registerErrorMsg.style.display = 'block';
                return;
            }
            if (password !== passwordConfirm) {
                console.error("[Register Check] Failed: Passwords don\'t match."); // LOG ERROR
                registerErrorMsg.textContent = getText('register_error_match'); // Use translation key
                registerErrorMsg.style.display = 'block';
                return;
            }
            if (!activePhoto) {
                console.error("[Register Check] Failed: No photo selected."); // LOG ERROR
                registerErrorMsg.textContent = getText('register_error_photo'); // Use translation key
                registerErrorMsg.style.display = 'block';
                return;
            }

            // --- Client-side email format validation ---
            const isEmailValid = emailRegex.test(email);
            console.log(`[Register Button Click] Is email valid format? ${isEmailValid}`);
            if (!isEmailValid) {
                console.error("[Register Check] Failed: Invalid email format."); // LOG ERROR
                registerErrorMsg.textContent = getText('register_error_invalid_email'); // Use translation key
                registerErrorMsg.style.display = 'block';
                console.log(`[Register Check] Set error display to: ${registerErrorMsg.style.display}`); // LOG DISPLAY STYLE
                return;
            }
            // --- END: Email validation ---

            // --- Check if canteen is open BEFORE trying to register ---
            if (!isCanteenOpen) {
                showCustomAlert(getText('canteen_closed_signup_alert'), 'error_title');
                return; // Prevent sending registration request
            }
            // --- End check ---

            // Send registration request to server
            const profilePicSrc = activePhoto.src; // Get the selected picture source
            console.log(`[Register Button Click] Validation passed, sending message for: ${email}`); // <-- ADDED LOG 4
            // Add the new log line here:
            console.log(`[Client] WebSocket readyState before sending: ${ws?.readyState}`);
            sendWebSocketMessage({ type: 'register_user', payload: { email: email, password: password, profilePic: profilePicSrc } });

        });
        registerPhotoPicker?.addEventListener('click', e => { if (e.target.classList.contains('profile-pic')) { registerPhotoPicker.querySelectorAll('.profile-pic').forEach(p => p.classList.remove('active')); e.target.classList.add('active'); } });
        logoutButton?.addEventListener('click', () => {
            currentUser = null;
            cart = [];
            selectedPaymentMethod = 'cash'; // Reset on logout
            eraseCookie('canteenUser'); // <-- Add this
            updateCartUI();
            updateUserInfoUI();
            // Use the correct variable name: paymentMethods
            if(paymentMethods) paymentMethods.querySelectorAll('.payment-button').forEach(b => b.classList.toggle('active', b.dataset.method === 'cash'));
            if (menuSortButtonsContainer) {
                const d = categories[0]?.key || 'sweet';
                menuSortButtonsContainer.querySelectorAll('.sort-button').forEach(b => b.classList.toggle('active', b.dataset.category === d));
                populateMenuGrid();
            }
            isDiscoveryModeActivated = false;
            localStorage.setItem(LS_KEYS.DISCOVERY_MODE, isDiscoveryModeActivated);
            updateDiscoverButtonVisibility();
            showScreen('screen-1');
        }); // Save discovery state on logout
        menuGrid?.addEventListener('click', e => { const m = e.target.closest('.menu-item'), p = e.target.closest('.price-button'); if (m) { const id = m.dataset.id; if (p) { addToCart(id); p.style.transition = 'transform 0.1s ease-out, background-color 0.1s ease-out'; p.style.backgroundColor = 'var(--active-green)'; p.style.transform = 'scale(1.1)'; setTimeout(() => { p.style.backgroundColor = ''; p.style.transform = ''; setTimeout(() => p.style.transition = '', 150); }, 150); } else { showItemPreview(id); } } });
        menuSortButtonsContainer?.addEventListener('click', e => { if (e.target.classList.contains('sort-button')) { const b = e.target; if (b.classList.contains('active')) return; menuSortButtonsContainer.querySelectorAll('.sort-button').forEach(btn => btn.classList.remove('active')); b.classList.add('active'); applyFilter(document.getElementById('screen-3'), true); } });
        // Use the correct variable name: paymentMethods
        paymentMethods?.addEventListener('click', e => {
            const b = e.target.closest('.payment-button');
            if (b && !b.classList.contains('active')) {
                selectedPaymentMethod = b.dataset.method;
                // Use the correct variable name: paymentMethods
                paymentMethods.querySelectorAll('.payment-button').forEach(btn => btn.classList.remove('active'));
                b.classList.add('active');
            }
        });
        cartItemsContainer?.addEventListener('click', e => { if (e.target.classList.contains('remove-item-button')) { const c = e.target.closest('.cart-item'), id = c?.dataset.id; if (id) removeFromCart(id); } });
        checkoutButton?.addEventListener('click', () => { placeOrder(); });
        adminLoginSubmitButton?.addEventListener('click', () => {
            const email = adminEmailInput.value;
            const password = adminPasswordInput.value;

            if (!adminLoginErrorMsg) return;
            adminLoginErrorMsg.style.display = 'none';

            // REMOVED: The console warning below is sufficient. No need to show a UI error message here.
            // REMOVED: console.warn("Client-side admin login validation was removed for security. Implement server-side validation in server.js.");
            // REMOVED: adminLoginErrorMsg.textContent = "Admin login must be verified by the server. (Not yet implemented)";
            // REMOVED: adminLoginErrorMsg.style.display = 'block';

            // Send admin login request to server via WebSocket
            if (email && password) {
                console.log(`[Client] Sending admin_login message for: ${email}`);
                sendWebSocketMessage({ type: 'admin_login', payload: { email: email, password: password } });
            } else {
                adminLoginErrorMsg.textContent = getText('login_error_fields'); // Re-use existing translation for empty fields
                adminLoginErrorMsg.style.display = 'block';
            }
        });
        mgmtBackToLoginButton?.addEventListener('click', () => { clearOrderPreview(); if(orderSearchInput) orderSearchInput.value = ''; showScreen('screen-1'); });
        orderSearchButton?.addEventListener('click', handleOrderSearch);
        orderSearchInput?.addEventListener('keypress', e => { if (e.key === 'Enter') handleOrderSearch(); });
        orderSearchInput?.addEventListener('input', () => { if (orderSearchInput.value.trim() === '') { handleOrderSearch(); } }); // Use function reference
    
        itemPreviewBackButton?.addEventListener('click', () => { const targetScreenId = previousScreenId || 'screen-3'; showScreen(targetScreenId); previousScreenId = null; });
        addToCartPreviewButton?.addEventListener('click', e => { const b = e.target.closest('button'), id = b?.dataset.itemId; if (id) { addToCart(id); if (previewButtonTimeout) { clearTimeout(previewButtonTimeout); } setPreviewButtonState(true); previewButtonTimeout = setTimeout(() => { if (currentScreen && currentScreen.id === 'screen-7' && addToCartPreviewButton.dataset.itemId === id) { setPreviewButtonState(false); } previewButtonTimeout = null; }, 1500); } });
        toggleFullScreenButton?.addEventListener('click', () => {
            bodyElement.classList.toggle('full-screen-mode');
            const f = bodyElement.classList.contains('full-screen-mode');
            toggleFullScreenButton.innerHTML = f ? '<i class="fas fa-compress"></i>' : '<i class="fas fa-expand"></i>';
            toggleFullScreenButton.title = f ? 'Exit Full Screen' : 'Enter Full Screen';
            // حفظ الحالة في Local Storage
            localStorage.setItem('canteenAppFullScreen', f ? '1' : '0');
            // إعادة الصفحة للأعلى عند تفعيل full screen
            if (f) window.scrollTo(0, 0);
        });
        discoverButton?.addEventListener('click', () => { if (isDiscoveryModeActivated) { showScreen('screen-8'); } else { console.warn("Discover button clicked but Discovery Mode is not activated."); } });
        discoveryBundlesScroller?.addEventListener('click', (e) => { const bundleButton = e.target.closest('.add-bundle-button'); if (bundleButton) { const card = bundleButton.closest('.offer-card'); const bundleId = card?.dataset.bundleId; if (bundleId) { addBundleToCart(bundleId, bundleButton); } } });
        discoverySuggestionsGrid?.addEventListener('click', (e) => { const suggestionButton = e.target.closest('.add-suggestion-button'); if (suggestionButton) { const card = suggestionButton.closest('.suggestion-grid-item'); const suggestionId = card?.dataset.suggestionId; if (suggestionId) { addSuggestionToCart(suggestionId, suggestionButton); } } });
        discoveryCategoriesContainer?.addEventListener('click', e => { const categoryItem = e.target.closest('.discovery-category-item'); const priceButton = e.target.closest('.price-button'); if (categoryItem && !priceButton) { const itemId = categoryItem.dataset.id; if(itemId) { showItemPreview(itemId); } } });
    
        // --- Settings Panel Event Listeners ---
        if (settingsBtn) { settingsBtn.addEventListener('click', (e) => { e.stopPropagation(); toggleSettingsPanel(); }); }
        if (currentLanguageDisplay) { currentLanguageDisplay.addEventListener('click', (e) => { e.stopPropagation(); toggleSettingsDropdown(languageGroup); }); currentLanguageDisplay.addEventListener('keydown', (e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); toggleSettingsDropdown(languageGroup); } }); }
        if (currentThemeDisplay) { currentThemeDisplay.addEventListener('click', (e) => { e.stopPropagation(); toggleSettingsDropdown(themeGroup); }); currentThemeDisplay.addEventListener('keydown', (e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); toggleSettingsDropdown(themeGroup); } }); }
        if (languageOptions) { languageOptions.addEventListener('click', (e) => { const o = e.target.closest('.option-item[data-lang]'); if (o && !o.classList.contains('active')) { const n = o.dataset.lang; appContainer.classList.add('language-switching'); setTimeout(() => { currentLanguage = n; localStorage.setItem(LS_KEYS.LANGUAGE, currentLanguage); updateLanguageUI(); closeAllSettingsDropdowns(); requestAnimationFrame(() => { appContainer.classList.remove('language-switching'); }); }, parseFloat(getComputedStyle(appContainer).getPropertyValue('--lang-change-speed') || '0.3') * 1000); } else if (o) { closeAllSettingsDropdowns(); } }); }
        if (themeOptions) { themeOptions.addEventListener('click', (e) => { const o = e.target.closest('.option-item[data-theme]'); if (o && !o.classList.contains('active')) { const n = o.dataset.theme; applyTheme(n); updateThemeDisplay(); closeAllSettingsDropdowns(); } else if (o) { closeAllSettingsDropdowns(); } }); }
        if (discoveryModeToggle) { const toggleAction = () => { if (isDiscoveryModeActivated) { isDiscoveryModeActivated = false; localStorage.setItem(LS_KEYS.DISCOVERY_MODE, isDiscoveryModeActivated); updateDiscoveryToggleVisualState(); updateDiscoverButtonVisibility(); } else { showPasscodeModal(); } }; discoveryModeToggle.addEventListener('click', toggleAction); discoveryModeToggle.addEventListener('keydown', (e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); toggleAction(); } }); }
        // --- End Settings Panel Event Listeners ---
    
        // --- Custom Alert Event Listeners ---
                    // --- Canteen Status Toggle Listener (Admin) ---
                    const adminCanteenToggle = document.getElementById('canteen-status-toggle'); // Use unified ID
                    const adminCanteenLabel = document.getElementById('canteen-status-label'); // Use unified ID
                    if (adminCanteenToggle) {
                        adminCanteenToggle.addEventListener('change', () => {
                            const newStatus = adminCanteenToggle.checked;
                            console.log(`Admin toggled canteen status to: ${newStatus ? 'Open' : 'Closed'}`);
                            sendWebSocketMessage({ type: 'admin_set_canteen_status', payload: { isOpen: newStatus } });
                            // Update the label text immediately based on the toggle's new state
                            if(adminCanteenLabel) {
                                const labelKey = newStatus ? 'canteen_status_open' : 'canteen_status_closed';
                                adminCanteenLabel.dataset.langKey = labelKey; // Update key for language changes
                                adminCanteenLabel.textContent = getText(labelKey);
                            }
                        });
                    }
        customAlertCloseBtn?.addEventListener('click', hideCustomAlert);
        customAlertOverlay?.addEventListener('click', (e) => { if (e.target === customAlertOverlay) { hideCustomAlert(); } });
        // --- Passcode Modal Event Listeners ---
        passcodeModalOk?.addEventListener('click', handlePasscodeSubmit);
        passcodeModalCancel?.addEventListener('click', hidePasscodeModal);
        passcodeModalOverlay?.addEventListener('click', (e) => { if (e.target === passcodeModalOverlay) { hidePasscodeModal(); } });
        passcodeModalInput?.addEventListener('keypress', (e) => { if (e.key === 'Enter') { handlePasscodeSubmit(); } });
        // --- End Passcode Modal Functions ---
    
         // --- Custom Confirm Modal Event Listeners ---
        customConfirmOkBtn?.addEventListener('click', () => {
            if (currentConfirmCallback) {
                currentConfirmCallback(); // Execute the stored confirm action
            }
            hideCustomConfirm();
        });
        customConfirmCancelBtn?.addEventListener('click', () => {
            if (currentCancelCallback) {
                currentCancelCallback(); // Execute the stored cancel action (optional)
            }
            hideCustomConfirm();
        });
        customConfirmModalOverlay?.addEventListener('click', (e) => {
             if (e.target === customConfirmModalOverlay) {
                 if (currentCancelCallback) currentCancelCallback(); // Treat clicking overlay as cancel
                 hideCustomConfirm();
             }
        });
        // --- End Custom Confirm Modal Listeners ---
    
        // --- START: Product & Category Management Listeners (Screen 9 specific - REFINED) ---
        appContainer.addEventListener('click', e => {
            // Ensure we are on Screen 9 before doing anything
            if (!currentScreen || currentScreen.id !== 'screen-9') return;
    
            // --- Back Button Logic ---
            if (e.target.id === 'product-mgmt-back-button' || e.target.closest('#product-mgmt-back-button')) {
                e.preventDefault(); // Prevent default button behavior
                e.stopPropagation(); // Stop further processing if back button clicked
                if (currentMgmtView === 'products') {
                    showScreen9View('categories');
                } else {
                    const backButton = document.getElementById('product-mgmt-back-button');
                    const targetScreenId = backButton?.dataset.target || 'screen-5';
                     showScreen(targetScreenId);
                }
                return; // Exit listener after handling back button
            }
    
            const categoryContainer = currentScreen.querySelector('#category-view-container');
            const productContainer = currentScreen.querySelector('#product-view-container');
    
            // --- Category View Actions ---
            if (categoryContainer?.classList.contains('active')) {
                const addCategoryForm = categoryContainer.querySelector('#add-category-form'); // Scope search
                 // *** REFINED CHECK FOR ADD CATEGORY BUTTON ***
                 const addCategoryButtonTarget = e.target.id === 'add-new-category-button' ? e.target : e.target.closest('#add-new-category-button');
                if (addCategoryButtonTarget && addCategoryForm?.contains(addCategoryButtonTarget)) {
                     console.log("Add Category Button Click Detected in Listener"); // <<< ADD LOG
                     handleAddCategory();
                     return; // Prevent other actions
                }
                // Click on Category Item (to enter it)
                const categoryItem = e.target.closest('.category-list-item');
                 // Edit/Delete Category buttons are handled by listeners added in renderCategoryList
                if (categoryItem && !e.target.closest('.category-actions')) { // Check not clicking actions
                     showScreen9View('products', categoryItem.dataset.categoryKey);
                     return; // Prevent other actions
                }
            }
    
            // --- Product View Actions ---
            if (productContainer?.classList.contains('active')) {
                const addProductForm = productContainer.querySelector('#add-product-form-container'); // Scope search
                 // *** REFINED CHECK FOR ADD PRODUCT BUTTON ***
                 const addProductButtonTarget = e.target.id === 'add-new-product-button' ? e.target : e.target.closest('#add-new-product-button');
                if (addProductButtonTarget && addProductForm?.contains(addProductButtonTarget)) {
                     console.log("Add Product Button Click Detected in Listener"); // <<< ADD LOG
                     handleAddNewProduct();
                     return; // Prevent other actions if this button was clicked
                }
                // Edit/Remove Product buttons -> Handled by listeners added in renderProductGridForCategory
            }
         });
         // --- END: Product Management Listeners ---
    
    
        // --- Edit Product Modal Listeners ---
        editProductSaveButton?.addEventListener('click', handleSaveProductEdit);
        editProductCancelButton?.addEventListener('click', hideEditProductModal);
        editProductModalOverlay?.addEventListener('click', (e) => { if (e.target === editProductModalOverlay) { hideEditProductModal(); } });
        editProductModalBox?.addEventListener('keypress', (e) => {
             // Allow enter key submit only if focus is on an input/select within the modal
             if (e.key === 'Enter' && (e.target.tagName === 'INPUT' || e.target.tagName === 'SELECT') && editProductModalBox.contains(e.target)) {
                 e.preventDefault(); // Prevent default form submission if it were a form
                 handleSaveProductEdit();
             }
        });
        // --- End Edit Product Modal Listeners ---
    
        // --- Edit Category Modal Listeners ---
        editCategorySaveButton?.addEventListener('click', handleSaveCategoryEdit);
        editCategoryCancelButton?.addEventListener('click', hideEditCategoryModal);
        editCategoryModalOverlay?.addEventListener('click', (e) => { if (e.target === editCategoryModalOverlay) { hideEditCategoryModal(); } });
        editCategoryModalBox?.addEventListener('keypress', (e) => {
             // Allow enter key submit only if focus is on an input within the modal
             if (e.key === 'Enter' && e.target.tagName === 'INPUT' && editCategoryModalBox.contains(e.target)) {
                  e.preventDefault(); // Prevent default form submission
                  handleSaveCategoryEdit();
             }
        });
        // --- End Edit Category Modal Listeners ---
    
        // --- START: Config Management Listeners ---
        exportConfigButton?.addEventListener('click', exportConfig);
    
        importConfigButton?.addEventListener('click', () => {
            // Trigger the hidden file input click
            importConfigInput?.click();
        });
    
        importConfigInput?.addEventListener('change', (event) => {
                    console.log("DEBUG: Toggle listener FIRED!");
            const file = event.target.files[0];
            if (file) {
                console.log("File selected for import:", file.name);
                importConfig(file);
            } else {
                 console.log("No file selected.");
                  if(importConfigErrorMsg) {
                      importConfigErrorMsg.textContent = getText('import_config_error_generic');
                      importConfigErrorMsg.style.display = 'block';
                  }
            }
        });
        // --- END: Config Management Listeners ---
    
                        // --- START: Enter Key Submit Logic ---
                        loginEmailInput?.addEventListener('keypress', (e) => {
                            if (e.key === 'Enter') {
                                e.preventDefault();
                                loginSubmitButton?.click();
                            }
                        });
                        loginPasswordInput?.addEventListener('keypress', (e) => {
                            if (e.key === 'Enter') {
                                e.preventDefault();
                                loginSubmitButton?.click();
                            }
                        });
            
                        registerEmailInput?.addEventListener('keypress', (e) => {
                            if (e.key === 'Enter') {
                                e.preventDefault();
                                registerSubmitButton?.click();
                            }
                        });
                        registerPasswordInput?.addEventListener('keypress', (e) => {
                            if (e.key === 'Enter') {
                                e.preventDefault();
                                registerSubmitButton?.click();
                            }
                        });
                        registerPasswordConfirmInput?.addEventListener('keypress', (e) => {
                            if (e.key === 'Enter') {
                                e.preventDefault();
                                registerSubmitButton?.click();
                            }
                        });
            
                        // Admin Login Fields
                        adminEmailInput?.addEventListener('keypress', (e) => {
                            if (e.key === 'Enter') {
                                e.preventDefault();
                                adminLoginSubmitButton?.click(); // Trigger admin login button click
                            }
                        });
                        adminPasswordInput?.addEventListener('keypress', (e) => {
                            if (e.key === 'Enter') {
                                e.preventDefault();
                                adminLoginSubmitButton?.click();
                            }
                        });
                        // --- END: Enter Key Submit Logic ---

        // Listener for order view toggle buttons (Current/Archived)
        orderViewToggleButtons.forEach(button => {
            button.addEventListener('click', () => {
                const newViewMode = button.dataset.viewMode;
                if (newViewMode !== currentOrderLogView) {
                    currentOrderLogView = newViewMode;
                    orderViewToggleButtons.forEach(btn => {
                        btn.classList.toggle('active', btn.dataset.viewMode === currentOrderLogView);
                    });
                    clearOrderPreview(); // Clear preview when switching views
                    renderOrderLog(); // Re-render with the new view mode
                    handleOrderSearch(); // Also re-apply search filter to the new view
                }
            });
        });

        // Make sure the orderSearchInput listener for 'input' is also within DOMContentLoaded
        orderSearchInput?.addEventListener('input', () => { 
            // If search input is cleared, re-run search which respects current view mode
            if (orderSearchInput.value.trim() === '') { 
                handleOrderSearch(); 
            }
        });

        // --- Initialization ---
        loadTranslations(); // Load saved translations first
        loadProducts(); // Load saved products (may replace default baseMenuData)
        loadOrders(); // Load saved orders
        initializeCategories(); // Load/build categories order and sync with current baseMenuData
    
        applyTheme(currentTheme); // Apply theme based on loaded state
        updateLanguageUI(); // Update UI based on loaded language and data
        // --- استرجاع حالة الـ Full Screen عند تحميل الصفحة ---
        if (localStorage.getItem('canteenAppFullScreen') === '1') {
            bodyElement.classList.add('full-screen-mode');
            if (toggleFullScreenButton) {
                toggleFullScreenButton.innerHTML = '<i class="fas fa-compress"></i>';
                toggleFullScreenButton.title = 'Exit Full Screen';
            }
        }
        if (currentUser) {
            updateUserInfoUI();
            console.log('[auto-login] Navigating to screen-3');
            showScreen('screen-3');
        } else {
            console.log('[auto-login] Navigating to screen-1');
            showScreen('screen-1'); // Show initial screen
        }
        updateCartUI(); // Initial cart render (might validate empty cart)
        updateDiscoverButtonVisibility();
        updateDiscoveryToggleVisualState();
        updateCanteenStatusIndicator(); // <<< Call initially to set indicator based on default/loaded state
        updateAdminStatusToggle(); // <<< Call initially to set toggle based on default/loaded state

        // Discovery Mode Passcode Event Listener - MOVED HERE
        if (passcodeModalInput) {
            passcodeModalInput.addEventListener('keypress', (e) => {
                if (e.key === 'Enter') {
                    handlePasscodeSubmit();
                }
            });
        }

        connectWebSocket(); 
    }); // <<< ENSURE THIS IS THE ACTUAL END of the DOMContentLoaded listener

    // Event listener for the new Discovery screen back button
    discoveryBackButton?.addEventListener('click', () => {
        console.log('[Debug] Discovery back button clicked. Current previousScreenId:', previousScreenId); // DEBUG
        // Navigate to previousScreenId if available, otherwise default to screen-3
        const targetScreenId = previousScreenId || 'screen-3';
        console.log('[Debug] Discovery back button navigating to:', targetScreenId); // DEBUG
        showScreen(targetScreenId);
    });

    initializeApplication();

    console.log('[Debug] discoveryBackButton element after caching:', discoveryBackButton); // ADDED FOR DEBUGGING

    // Add a loading/connecting screen if not present
    if (!document.getElementById('screen-0')) {
        const loadingScreen = document.createElement('div');
        loadingScreen.className = 'screen';
        loadingScreen.id = 'screen-0';
        loadingScreen.innerHTML = '<div class="screen-content"><h2>Connecting...</h2><p>Please wait while connecting to the server.</p></div>';
        document.querySelector('.app-container').prepend(loadingScreen);
    }

    let isWebSocketConnected = false;

    // --- إخفاء شاشة التحميل بعد 5 ثواني مهما كان ---
    setTimeout(() => {
        const loader = document.getElementById('loader-overlay');
        if(loader) loader.remove();
    }, 5000);

    // --- إخفاء شاشة connecting (screen-0) بعد 5 ثواني ---
    setTimeout(() => {
        const connectingScreen = document.getElementById('screen-0');
        if (connectingScreen) connectingScreen.style.display = 'none';
    }, 5000);

    // --- حذف جميع عناصر screen-0 بعد 5 ثواني ---
    setTimeout(() => {
        document.querySelectorAll('#screen-0').forEach(el => el.remove());
    }, 5000);

    // --- منع إعادة إنشاء شاشة connecting بعد 5 ثواني ---
    setTimeout(() => {
        window.disableConnectingScreen = true;
        document.querySelectorAll('#screen-0').forEach(el => el.remove());
    }, 5000);

    // عند إنشاء شاشة connecting في نهاية الملف:
    if (!window.disableConnectingScreen && !document.getElementById('screen-0')) {
        const loadingScreen = document.createElement('div');
        loadingScreen.className = 'screen';
        loadingScreen.id = 'screen-0';
        loadingScreen.innerHTML = '<div class="screen-content"><h2>Connecting...</h2><p>Please wait while connecting to the server.</p></div>';
        document.querySelector('.app-container').prepend(loadingScreen);
    }

    // --- مراقبة مستمرة لحذف screen-0 إذا ظهرت بعد 5 ثواني ---
    setInterval(() => {
        if (window.disableConnectingScreen) {
            document.querySelectorAll('#screen-0').forEach(el => el.remove());
        }
    }, 1000);

    // بعد DOMContentLoaded مباشرة:
    setTimeout(() => {
        window.disableConnectingScreen = true;
        document.querySelectorAll('#screen-0').forEach(el => el.remove());
    }, 5000);
    // ... existing code ...
    // عند أي محاولة لإنشاء شاشة connecting:
    if (!window.disableConnectingScreen && !document.getElementById('screen-0')) {
        const loadingScreen = document.createElement('div');
        loadingScreen.className = 'screen';
        loadingScreen.id = 'screen-0';
        loadingScreen.innerHTML = '<div class="screen-content"><h2>Connecting...</h2><p>Please wait while connecting to the server.</p></div>';
        document.querySelector('.app-container').prepend(loadingScreen);
    }
    // ... existing code ...

    // بعد DOMContentLoaded مباشرة:
    const connectingScreenTimeout = Date.now() + 5000;
    setInterval(() => {
        if (Date.now() > connectingScreenTimeout) {
            document.querySelectorAll('#screen-0').forEach(el => el.remove());
            window.disableConnectingScreen = true;
        }
    }, 500);
    // ... existing code ...
    // عند أي محاولة لإنشاء شاشة connecting:
    if (!window.disableConnectingScreen && !document.getElementById('screen-0')) {
        const loadingScreen = document.createElement('div');
        loadingScreen.className = 'screen';
        loadingScreen.id = 'screen-0';
        loadingScreen.innerHTML = '<div class="screen-content"><h2>Connecting...</h2><p>Please wait while connecting to the server.</p></div>';
        document.querySelector('.app-container').prepend(loadingScreen);
    }
    // ... existing code ...

    // ... existing code ...
    // عند أي محاولة لإنشاء شاشة connecting:
    if ((Date.now() - connectingScreenStart) < 5000 && !document.getElementById('screen-0')) {
        const loadingScreen = document.createElement('div');
        loadingScreen.className = 'screen';
        loadingScreen.id = 'screen-0';
        loadingScreen.innerHTML = '<div class="screen-content"><h2>Connecting...</h2><p>Please wait while connecting to the server.</p></div>';
        document.querySelector('.app-container').prepend(loadingScreen);
    }
    // ... existing code ...

    // دالة لإظهار شاشة connecting
    function showConnectingScreen() {
        if (connectingScreenEverTimedOut) return;
        console.log('[DEBUG] showConnectingScreen called');
        if (!document.getElementById('screen-0')) {
            const loadingScreen = document.createElement('div');
            loadingScreen.className = 'screen';
            loadingScreen.id = 'screen-0';
            loadingScreen.innerHTML = '<div class="screen-content"><h2>Connecting...</h2><p>Please wait while connecting to the server.</p></div>';
            document.querySelector('.app-container').prepend(loadingScreen);
            console.log('[DEBUG] screen-0 created');
        }
        // فقط أول مرة: شغل التايمر
        if (!window.connectingScreenTimeout) {
            window.connectingScreenTimeout = setTimeout(() => {
                connectingScreenEverTimedOut = true;
                hideConnectingScreen();
                console.log('[DEBUG] 5 seconds passed, auto-hiding connecting screen');
            }, 5000);
        }
    }
    // دالة لإخفاء شاشة connecting
    function hideConnectingScreen() {
        console.log('[DEBUG] hideConnectingScreen called');
        const els = document.querySelectorAll('#screen-0');
        for (const el of els) {
            el.remove();
            console.log('[DEBUG] screen-0 removed');
        }
        if (window.connectingScreenTimeout) clearTimeout(window.connectingScreenTimeout);
        window.connectingScreenTimeout = null;
    }
    // ... existing code ...
    // في connectWebSocket:
    ws.onopen = () => {
        console.log('[DEBUG] ws.onopen - connection established');
        isWebSocketConnected = true;
        hideConnectingScreen();
        // ... باقي الكود ...
    };
    ws.onclose = () => {
        console.log('[DEBUG] ws.onclose - connection lost');
        showConnectingScreen();
        // ... باقي الكود ...
    };
