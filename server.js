const WebSocket = require('ws');
const fs = require('fs');
const path = require('path');
const bcrypt = require('bcrypt');

// --- Data Persistence Setup ---
const DATA_DIR = path.join(__dirname, 'data');
const ORDERS_FILE = path.join(DATA_DIR, 'orders.json');
const PRODUCTS_FILE = path.join(DATA_DIR, 'products.json');
const CATEGORIES_FILE = path.join(DATA_DIR, 'categories.json');
const TRANSLATIONS_FILE = path.join(DATA_DIR, 'translations.json');
const STATUS_FILE = path.join(DATA_DIR, 'canteenStatus.json');
const USERS_FILE = path.join(DATA_DIR, 'users.json');

// Ensure data directory exists
if (!fs.existsSync(DATA_DIR)) {
    try {
        fs.mkdirSync(DATA_DIR);
        console.log(`Data directory created: ${DATA_DIR}`);
    } catch (err) {
        console.error(`Error creating data directory: ${DATA_DIR}`, err);
        process.exit(1); // Exit if cannot create data directory
    }
}

// Helper function to load data from a file
function loadDataFromFile(filePath, defaultData = []) {
    try {
        if (fs.existsSync(filePath)) {
            const fileData = fs.readFileSync(filePath, 'utf-8');
            const jsonData = JSON.parse(fileData);
            console.log(`Data loaded successfully from ${filePath}`);

            // Special handling for orders remains
            if (filePath === ORDERS_FILE) {
                // Ensure jsonData for orders is an array before mapping
                if (!Array.isArray(jsonData)) {
                    console.warn(`Order data from ${filePath} is not an array. Using default empty array.`);
                    return []; // Return empty array if order data is invalid
                }
                return jsonData.map(order => ({ ...order, timestamp: new Date(order.timestamp) }));
            }

            // *** REVISED Logic for Arrays vs Objects ***
            if (Array.isArray(defaultData)) {
                // If default is array, we expect an array from file
                if (Array.isArray(jsonData)) {
                    console.log(`Returning array data directly from ${filePath}`);
                    return jsonData; // Use valid array from file
                } else {
                    console.warn(`Loaded data from ${filePath} is not an array as expected. Using default data.`);
                    return defaultData; // Use default array if file data is not array
                }
            } else {
                // If default is object, merge file data (if object) with default
                if (typeof jsonData === 'object' && jsonData !== null && !Array.isArray(jsonData)) {
                    return { ...defaultData, ...jsonData }; // Merge objects
                } else {
                     console.warn(`Loaded data from ${filePath} is not an object as expected for merging. Using default data.`);
                     return defaultData; // Use default object if file data is not object
                }
            }
        } else {
            console.log(`Data file not found: ${filePath}. Using default data.`);
            return defaultData;
        }
    } catch (error) {
        console.error(`Error loading data from ${filePath}. Using default data.`, error);
        return defaultData;
    }
}

// Helper function to save data to a file
function saveDataToFile(filePath, data) {
    try {
        const jsonData = JSON.stringify(data, null, 2); // Pretty print JSON
        fs.writeFileSync(filePath, jsonData, 'utf-8');
        // console.log(`Data saved successfully to ${filePath}`); // Can be noisy
    } catch (error) {
        console.error(`Error saving data to ${filePath}.`, error);
    }
}

// --- Server-Side Order ID Generation ---
function generateOrderIdOnServer() {
    const now = new Date();
    const day = String(now.getDate()).padStart(2, '0');
    const month = String(now.getMonth() + 1).padStart(2, '0');
    const year = now.getFullYear();
    const todayStr = `${year}-${month}-${day}`;

    let maxSequenceToday = 0;
    // Find the highest sequence number among orders placed *today*
    allOrders.forEach(order => {
        // Check if the order has a valid timestamp
        if (order.timestamp instanceof Date && !isNaN(order.timestamp)) {
            const orderDate = new Date(order.timestamp);
            const orderDateStr = `${orderDate.getFullYear()}-${String(orderDate.getMonth() + 1).padStart(2, '0')}-${String(orderDate.getDate()).padStart(2, '0')}`;

            // Check if the order was placed today and has the expected ID format
            if (orderDateStr === todayStr && order.id && typeof order.id === 'string' && order.id.startsWith('ORD-')) {
                const parts = order.id.split('-');
                // Expected format: ORD-Sequence-Day-Month
                if (parts.length === 4) {
                    const sequence = parseInt(parts[1], 10);
                    if (!isNaN(sequence) && sequence > maxSequenceToday) {
                        maxSequenceToday = sequence;
                    }
                }
            }
        } else {
             console.warn(`Order ${order.id || '(unknown ID)'} has invalid or missing timestamp.`);
        }
    });

    const nextSequence = maxSequenceToday + 1;
    const newOrderId = `ORD-${nextSequence}-${day}-${month}`;
    console.log(`Generated Server-Side Order ID: ${newOrderId} (Max sequence today was ${maxSequenceToday})`);
    return newOrderId;
}

// --- Default Data (used if files don't exist) ---
const defaultProducts = [
    {id: 'coffee', price: 30, image: '/images/coffee.jpg', category: 'sweet', quantity: 999, name_key: 'item_name_coffee', description_key: 'item_desc_coffee'},
    {id: 'pizza', price: 70, image: '/images/pizza.jpg', category: 'lunch', quantity: 999, name_key: 'item_name_pizza', description_key: 'item_desc_pizza'},
    {id: 'cookies', price: 20, image: '/images/cookies.jpg', category: 'sweet', quantity: 999, name_key: 'item_name_cookies', description_key: 'item_desc_cookies'},
    {id: 'fries', price: 35, image: '/images/fries.jpg', category: 'snacks', quantity: 999, name_key: 'item_name_fries', description_key: 'item_desc_fries'},
    {id: 'burger', price: 60, image: '/images/burger.jpg', category: 'lunch', quantity: 999, name_key: 'item_name_burger', description_key: 'item_desc_burger'},
    {id: 'soda', price: 15, image: '/images/soda.jpg', category: 'snacks', quantity: 999, name_key: 'item_name_soda', description_key: 'item_desc_soda'},
    {id: 'salad', price: 45, image: '/images/salad.jpg', category: 'lunch', quantity: 999, name_key: 'item_name_salad', description_key: 'item_desc_salad'},
    {id: 'cake', price: 40, image: '/images/cake.jpg', category: 'sweet', quantity: 999, name_key: 'item_name_cake', description_key: 'item_desc_cake'},
    {id: 'croissant', price: 25, image: '/images/croissant.jpg', category: 'sweet', quantity: 999, name_key: 'item_name_croissant', description_key: 'item_desc_croissant'},
    {id: 'pasta', price: 55, image: '/images/pasta.jpg', category: 'lunch', quantity: 999, name_key: 'item_name_pasta', description_key: 'item_desc_pasta'},
    {id: 'chips', price: 10, image: '/images/chips.jpg', category: 'snacks', quantity: 999, name_key: 'item_name_chips', description_key: 'item_desc_chips'},
    {id: 'juice', price: 20, image: '/images/juice.jpg', category: 'sweet', quantity: 999, name_key: 'item_name_juice', description_key: 'item_desc_juice'},
    {id: 'sandwich', price: 50, image: '/images/sandwich.jpg', category: 'lunch', quantity: 999, name_key: 'item_name_sandwich', description_key: 'item_desc_sandwich'},
    {id: 'muffin', price: 22, image: '/images/muffin.jpg', category: 'sweet', quantity: 999, name_key: 'item_name_muffin', description_key: 'item_desc_muffin'},
    {id: 'onionrings', price: 30, image: '/images/onionrings.jpg', category: 'snacks', quantity: 999, name_key: 'item_name_onionrings', description_key: 'item_desc_onionrings'},
    {id: 'soup', price: 35, image: '/images/soup.jpg', category: 'lunch', quantity: 999, name_key: 'item_name_soup', description_key: 'item_desc_soup'}
];
const defaultCategories = [
    { key: 'sweet', name_key: 'sort_sweet', productIds: ['coffee', 'cookies', 'cake', 'croissant', 'juice', 'muffin'] },
    { key: 'lunch', name_key: 'sort_lunch', productIds: ['pizza', 'burger', 'salad', 'pasta', 'sandwich', 'soup'] },
    { key: 'snacks', name_key: 'sort_snacks', productIds: ['fries', 'soda', 'chips', 'onionrings'] }
];
const defaultTranslations = {
    welcome_title: { en: "Welcome to<br>EVA Canteen", ar: "أهلاً بكم في<br>كانتين إيفا" },
    canteen_name: { en: "EVA Canteen", ar: "كانتين إيفا" },
    item_name_coffee: { en: "Coffee", ar: "قهوة" }, item_name_pizza: { en: "Pizza", ar: "بيتزا" },
    item_name_cookies: { en: "Cookies", ar: "كوكيز" }, item_name_fries: { en: "French fries", ar: "بطاطس مقلية" },
    item_name_burger: { en: "Burger", ar: "برجر" }, item_name_soda: { en: "Soda", ar: "صودا" },
    item_name_salad: { en: "Salad", ar: "سلطة" }, item_name_cake: { en: "Cake Slice", ar: "شريحة كيك" },
    item_name_croissant: { en: "Croissant", ar: "كرواسون" }, item_name_pasta: { en: "Pasta Aglio e Olio", ar: "باستا أليو إي أوليو" },
    item_name_chips: { en: "Potato Chips", ar: "رقائق البطاطس" }, item_name_juice: { en: "Orange Juice", ar: "عصير برتقال" },
    item_name_sandwich: { en: "Club Sandwich", ar: "كلوب ساندويتش" }, item_name_muffin: { en: "Muffin", ar: "مافن" },
    item_name_onionrings: { en: "Onion Rings", ar: "حلقات بصل" }, item_name_soup: { en: "Soup of the Day", ar: "شوربة اليوم" },
    item_desc_coffee: { en: "A rich and aromatic blend, perfect to kickstart your day or enjoy a relaxing break.", ar: "مزيج غني وعطري، مثالي لبدء يومك أو الاستمتاع باستراحة مريحة." },
    item_desc_pizza: { en: "Classic cheese pizza with a tangy tomato sauce and a crispy crust. Always a favorite!", ar: "بيتزا جبنة كلاسيكية بصلصة طماطم منعشة وقشرة مقرمشة. الخيار المفضل دائماً!" },
    sort_sweet: { en: "Sweet", ar: "حلويات" }, sort_lunch: { en: "Lunch", ar: "غداء" }, sort_snacks: { en: "Snacks", ar: "خفيف" },
    bundle_discount_applied: { en: "Bundle Discount", ar: "خصم الحزمة" },
    currency_symbol: { en: "L.E", ar: "ج.م" },
    canteen_closed_login_alert: { en: "Sorry, the canteen is currently closed. Please try again later.", ar: "عذراً، الكانتين مغلق حالياً. يرجى المحاولة مرة أخرى لاحقاً." },
    canteen_closed_signup_alert: { en: "Sorry, the canteen is currently closed. Account registration is unavailable.", ar: "عذراً، الكانتين مغلق حالياً. تسجيل الحسابات غير متاح." },
    error_title: { en: "Error", ar: "خطأ" },
    canteen_closed_indicator: { en: "Canteen is currently CLOSED", ar: "الكانتين مغلق حالياً" },
    canteen_status_title: { en: "Canteen Status", ar: "حالة الكانتين" },
    canteen_status_open: { en: "Open", ar: "مفتوح" },
    canteen_status_closed: { en: "Closed", ar: "مغلق" },
    canteen_status_hint: { en: "Toggle to open or close the canteen for regular users.", ar: "بدّل لفتح أو إغلاق الكانتين للمستخدمين العاديين." },
    info_title: { en: "Information", ar: "معلومات" },
    force_logout_canteen_closed: { en: "The canteen has been closed by management. You have been logged out.", ar: "تم إغلاق الكانتين من قبل الإدارة. تم تسجيل خروجك." },
    product_out_of_stock_alert: { en: "Sorry, '{name}' is out of stock!", ar: "عذراً، '{name}' نفذ من المخزون!" }
};
const defaultStatus = { isOpen: true };
const defaultUsers = [];

// --- In-memory Data Stores (initialized from files or defaults) ---
let allOrders = loadDataFromFile(ORDERS_FILE, []);
let baseMenuData = loadDataFromFile(PRODUCTS_FILE, defaultProducts);
let categories = loadDataFromFile(CATEGORIES_FILE, defaultCategories);
let translations = loadDataFromFile(TRANSLATIONS_FILE, defaultTranslations);
let canteenStatus = loadDataFromFile(STATUS_FILE, defaultStatus);
let allUsers = loadDataFromFile(USERS_FILE, defaultUsers);

// Check if newly added keys exist after loading from file
// console.log(`[Server Startup] Does translations object have 'info_title'? `, translations.hasOwnProperty('info_title'));
// console.log(`[Server Startup] Does translations object have 'force_logout_canteen_closed'? `, translations.hasOwnProperty('force_logout_canteen_closed'));

const wss = new WebSocket.Server({ port: 8080, host: '0.0.0.0' });

// Store connected clients and their roles
const clients = new Map(); // Use Map for better client management { ws: { isManagement: false } }

console.log('WebSocket server started on port 8080');

wss.on('connection', (ws) => {
    console.log('Client connected');
    const clientInfo = { isManagement: false }; // Initialize client info
    clients.set(ws, clientInfo);

    // --- Send ONLY essential non-sensitive data immediately --- 
    // Client will request the rest when ready.
    ws.send(JSON.stringify({ type: 'initial_translations', payload: translations }));
    ws.send(JSON.stringify({ type: 'initial_canteen_status', payload: canteenStatus }));
    console.log('Sent initial status and translations to new client.');

    ws.on('message', (message) => {
        console.log(`[Server] Raw message received: ${message}`);
        let parsedMessage;
        try {
            parsedMessage = JSON.parse(message);
            console.log(`[Server] Parsed message type: ${parsedMessage.type}`);
            // Avoid logging large payloads like initial data
            if (!['initial_products', 'initial_categories', 'initial_translations', 'initial_orders'].includes(parsedMessage.type) && parsedMessage.payload) {
                console.log('Received Payload:', JSON.stringify(parsedMessage.payload));
            } else if (!parsedMessage.payload) {
                console.log('Received message with no payload.');
            }

            const clientInfo = clients.get(ws);
            if (!clientInfo) {
                console.error("Received message from unknown client, closing connection.");
                ws.terminate(); // Close connection from unknown source
                return;
            }

            // --- Message Handling ---
            switch (parsedMessage.type) {
                case 'request_initial_data':
                    console.log(`Client requested initial data.`);
                    // Send product/category data ONLY if canteen is open
                    if (canteenStatus.isOpen) {
                        ws.send(JSON.stringify({ type: 'initial_products', payload: baseMenuData }));
                        ws.send(JSON.stringify({ type: 'initial_categories', payload: categories }));
                        console.log('Sent initial products and categories upon request (canteen open).');
                    } else {
                        console.log('Canteen closed, not sending products/categories upon request.');
                    }
                    // Note: Status and translations were already sent on connection.
                    // Orders are only sent upon management identification.
                    break;

                case 'identify_management':
                    console.log('Management client identified');
                    clientInfo.isManagement = true;
                    clients.set(ws, clientInfo); // Update client role
                    // Send initial orders specifically to this management client
                    ws.send(JSON.stringify({ type: 'initial_orders', payload: allOrders }));
                    // Also send products/categories *regardless* of canteen status for management
                    ws.send(JSON.stringify({ type: 'initial_products', payload: baseMenuData }));
                    ws.send(JSON.stringify({ type: 'initial_categories', payload: categories }));
                    console.log('Sent orders, products, and categories to identified management client.');
                    break;

                // --- NEW: User Registration ---
                case 'register_user':
                    const { email: regEmail, password: regPassword, profilePic: regProfilePic } = parsedMessage.payload;
                    if (!regEmail || !regPassword || !regProfilePic) {
                        ws.send(JSON.stringify({ type: 'register_error', payload: { message: 'Missing registration details.' } }));
                        break;
                    }

                    // Check if email already exists
                    if (allUsers.some(user => user.email === regEmail)) {
                        ws.send(JSON.stringify({ type: 'register_error', payload: { message: 'Email already registered.' } }));
                        break;
                    }

                    // Hash the password
                    bcrypt.hash(regPassword, 10, (err, hashedPassword) => { // Use salt rounds = 10
                        if (err) {
                            console.error("Error hashing password:", err);
                            ws.send(JSON.stringify({ type: 'register_error', payload: { message: 'Server error during registration.' } }));
                            return;
                        }

                        // Add new user
                        const newUser = {
                            email: regEmail,
                            passwordHash: hashedPassword, // Store the hash, NOT the password
                            profilePic: regProfilePic
                        };
                        allUsers.push(newUser);
                        saveDataToFile(USERS_FILE, allUsers); // Save updated user list

                        console.log(`User registered successfully: ${regEmail}`);
                        // Send success message (don't send password hash back)
                        ws.send(JSON.stringify({ type: 'register_success', payload: { email: newUser.email, profilePic: newUser.profilePic } }));
                    });
                    break;

                // --- NEW: User Login ---
                case 'login_user':
                    console.log('[Server] Entered login_user case.');
                    const { email: loginEmail, password: loginPassword } = parsedMessage.payload;
                    if (!loginEmail || !loginPassword) {
                        ws.send(JSON.stringify({ type: 'login_error', payload: { message: 'Missing login details.' } }));
                        break;
                    }

                    // Find user by email
                    const user = allUsers.find(u => u.email === loginEmail);
                    if (!user) {
                        console.log(`Login attempt failed: Email not found - ${loginEmail}`);
                        ws.send(JSON.stringify({ type: 'login_error', payload: { message: 'Invalid email or password.' } }));
                        break;
                    }

                    // Compare password with stored hash
                    bcrypt.compare(loginPassword, user.passwordHash, (err, result) => {
                        if (err) {
                            console.error("Error comparing password:", err);
                            ws.send(JSON.stringify({ type: 'login_error', payload: { message: 'Server error during login.' } }));
                            return;
                        }

                        if (result) {
                            // Passwords match!
                            console.log(`User logged in successfully: ${loginEmail}`);
                            // Send success with user info (excluding hash)
                            ws.send(JSON.stringify({ type: 'login_success', payload: { email: user.email, profilePic: user.profilePic } }));
                        } else {
                            // Passwords don't match
                            console.log(`Login attempt failed: Incorrect password for - ${loginEmail}`);
                            ws.send(JSON.stringify({ type: 'login_error', payload: { message: 'Invalid email or password.' } }));
                        }
                    });
                    break;
                // --- END: New User Auth Cases ---

                case 'place_order':
                    // SERVER-SIDE CHECK: Is canteen open OR is it a management client placing order?
                    if (!canteenStatus.isOpen && !clientInfo.isManagement) {
                        console.warn(`Order rejected: Canteen is closed. Client Order ID: ${parsedMessage.payload?.id}`);
                        ws.send(JSON.stringify({ type: 'order_rejected', payload: { reason: 'Canteen is currently closed.', orderId: parsedMessage.payload?.id } }));
                        break; // Stop processing this order
                    }

                    const newOrder = parsedMessage.payload;
                    // Basic validation (excluding ID check now)
                    if (newOrder && newOrder.timestamp && Array.isArray(newOrder.items)) {
                         // Ensure timestamp is a valid date object
                         newOrder.timestamp = new Date(newOrder.timestamp);

                         // <<< Generate and Assign Server-Side ID >>>
                         const serverGeneratedId = generateOrderIdOnServer();
                         const clientTempId = newOrder.id; // Store client temp ID for logging if needed
                         newOrder.id = serverGeneratedId; // OVERWRITE the ID

                        console.log(`Processing order request (Client ID: ${clientTempId}) -> Server ID: ${newOrder.id}`);

                        // Prevent duplicate REAL order IDs (unlikely but good practice)
                        if (!allOrders.some(o => o.id === newOrder.id)) {
                            allOrders.unshift(newOrder); // Add to beginning with the correct ID
                            saveDataToFile(ORDERS_FILE, allOrders); // SAVE ORDERS

                            // --- Decrease Product Quantities --- (Keep this logic)
                            let productsChanged = false;
                            newOrder.items.forEach(item => {
                                if (!item.isDiscount && item.id) { 
                                     const productIndex = baseMenuData.findIndex(p => p.id === item.id);
                                     if (productIndex > -1) {
                                         const product = baseMenuData[productIndex];
                                         if (product.quantity !== 999) { 
                                             const orderedQuantity = item.quantity || 0;
                                             const newQuantity = Math.max(0, product.quantity - orderedQuantity); 
                                             if (product.quantity !== newQuantity) {
                                                 product.quantity = newQuantity;
                                                 productsChanged = true;
                                                 console.log(`Decreased quantity for ${product.id} to ${newQuantity}`);
                                             }
                                         }
                                     } else {
                                          console.warn(`Product ID ${item.id} from order ${newOrder.id} not found in baseMenuData.`);
                                     }
                                }
                            });

                            // Broadcast the new order ONLY to identified management clients
                            broadcastToManagement(JSON.stringify({ type: 'new_order', payload: newOrder })); // Broadcast with REAL ID

                            // Broadcast product updates & SAVE if quantities changed
                            if (productsChanged) {
                                broadcast(JSON.stringify({ type: 'products_updated', payload: baseMenuData }));
                                saveDataToFile(PRODUCTS_FILE, baseMenuData); // SAVE PRODUCTS
                            }

                            // <<< Send confirmation back to the specific client with the real ID >>>
                            ws.send(JSON.stringify({ type: 'order_confirmed_by_server', payload: newOrder })); 
                            console.log(`Sent order confirmation with server ID ${newOrder.id} back to client.`);

                        } else {
                            console.warn(`Generated Server Order ID collision (Should be very rare): ${newOrder.id}. Ignored.`);
                            // Optionally notify the client about the collision/failure?
                            // ws.send(JSON.stringify({ type: 'order_failed', payload: { reason: 'Order ID collision', clientTempId: clientTempId } }));
                        }
                    } else {
                         console.warn('Invalid place_order message received (missing timestamp or items?):', parsedMessage);
                         // Optionally notify the client about the invalid request?
                         // ws.send(JSON.stringify({ type: 'order_failed', payload: { reason: 'Invalid order data' } }));
                    }
                    break;
                 case 'get_orders':
                     if (clientInfo.isManagement) {
                         console.log(`Management client requested orders.`);
                         ws.send(JSON.stringify({ type: 'initial_orders', payload: allOrders }));
                     }
                     break;

                // --- START: Admin Actions ---
                case 'admin_product_added':
                    // Revised to check for translations in payload
                    if (clientInfo.isManagement && parsedMessage.payload && parsedMessage.payload.product && parsedMessage.payload.categoryKey && parsedMessage.payload.translations) {
                        const { product, categoryKey, translations: newTranslations } = parsedMessage.payload;
                        console.log('Admin action: Adding product', product.id, 'to category', categoryKey);
                        // Validate product data
                        if (product.id && product.name_key && product.price !== undefined && product.category === categoryKey && !baseMenuData.some(p => p.id === product.id)) {
                            // Add product
                            baseMenuData.push(product);
                            // Add product ID to the correct category
                            const catIndex = categories.findIndex(c => c.key === categoryKey);
                            if (catIndex > -1) {
                                categories[catIndex].productIds.push(product.id);
                                // Broadcast updated categories
                                broadcast(JSON.stringify({ type: 'categories_updated', payload: categories }));
                            } else {
                                console.warn(`Category ${categoryKey} not found while adding product ${product.id}`);
                            }
                            
                            // --- Update translations using received data --- 
                            let translationsChanged = false;
                            if (newTranslations && typeof newTranslations === 'object') {
                                 Object.assign(translations, newTranslations); // Merge the new keys/values
                                 translationsChanged = true;
                                 console.log(`Added/Updated translations for new product: ${product.id}`);
                            }

                            // Save updated data
                            saveDataToFile(PRODUCTS_FILE, baseMenuData);
                            saveDataToFile(CATEGORIES_FILE, categories);
                            saveDataToFile(TRANSLATIONS_FILE, translations);

                            // Broadcast updated products and possibly translations
                            broadcast(JSON.stringify({ type: 'products_updated', payload: baseMenuData }));
                            if (translationsChanged) {
                                broadcast(JSON.stringify({ type: 'translations_updated', payload: translations }));
                            }
                            // TODO: Persist changes
                        } else {
                            console.warn('Invalid product data or product ID already exists:', product.id);
                        }
                    } else {
                         console.warn('Unauthorized or invalid admin_product_added attempt.');
                    }
                    break;

                case 'admin_product_updated':
                    // Revised to handle new payload structure
                    if (clientInfo.isManagement && parsedMessage.payload && parsedMessage.payload.productId && parsedMessage.payload.updatedFields) {
                        const { productId, updatedFields, originalCategoryKey, newCategoryKey } = parsedMessage.payload;
                        console.log('Admin action: Updating product', productId);
                         const index = baseMenuData.findIndex(p => p.id === productId);
                         if (index > -1) {
                             // --- Update product data in baseMenuData --- 
                             // Update only the relevant fields, preserving others if needed
                             baseMenuData[index].price = updatedFields.price;
                             baseMenuData[index].quantity = updatedFields.quantity;
                             baseMenuData[index].image = updatedFields.image;
                             baseMenuData[index].category = updatedFields.category; // newCategoryKey is the same as updatedFields.category
                             // name_key and description_key should generally not change during an edit

                             // --- Update translations object --- 
                             let translationsChanged = false;
                             if (updatedFields.name_key && translations[updatedFields.name_key]) {
                                 if (translations[updatedFields.name_key].en !== updatedFields.name_en || translations[updatedFields.name_key].ar !== updatedFields.name_ar) {
                                     translations[updatedFields.name_key].en = updatedFields.name_en;
                                     translations[updatedFields.name_key].ar = updatedFields.name_ar;
                                     translationsChanged = true;
                                     console.log(`Updated translations for name key: ${updatedFields.name_key}`);
                                 }
                             } else if (updatedFields.name_key) {
                                  // If key exists in product but not translations, add it (should be rare for updates)
                                  translations[updatedFields.name_key] = { en: updatedFields.name_en, ar: updatedFields.name_ar };
                                  translationsChanged = true;
                                  console.log(`Added missing translations for name key: ${updatedFields.name_key}`);
                             }

                             if (updatedFields.description_key && translations[updatedFields.description_key]) {
                                  if (translations[updatedFields.description_key].en !== updatedFields.description_en || translations[updatedFields.description_key].ar !== updatedFields.description_ar) {
                                     translations[updatedFields.description_key].en = updatedFields.description_en;
                                     translations[updatedFields.description_key].ar = updatedFields.description_ar;
                                     translationsChanged = true;
                                     console.log(`Updated translations for desc key: ${updatedFields.description_key}`);
                                  }
                             } else if (updatedFields.description_key) {
                                  translations[updatedFields.description_key] = { en: updatedFields.description_en, ar: updatedFields.description_ar };
                                  translationsChanged = true;
                                  console.log(`Added missing translations for desc key: ${updatedFields.description_key}`);
                             }

                             // --- Handle category change --- 
                             if (originalCategoryKey !== newCategoryKey) {
                                 console.log(`Category changed for ${productId}: ${originalCategoryKey} -> ${newCategoryKey}`);
                                 // Remove from old category
                                 const oldCatIndex = categories.findIndex(c => c.key === originalCategoryKey);
                                 if (oldCatIndex > -1) {
                                     categories[oldCatIndex].productIds = categories[oldCatIndex].productIds.filter(pid => pid !== productId);
                                 }
                                 // Add to new category
                                 const newCatIndex = categories.findIndex(c => c.key === newCategoryKey);
                                 if (newCatIndex > -1) {
                                     if (!categories[newCatIndex].productIds.includes(productId)) {
                                          categories[newCatIndex].productIds.push(productId);
                                     }
                                 }
                                 // Broadcast category update
                                 broadcast(JSON.stringify({ type: 'categories_updated', payload: categories }));
                             }
                             // --- Broadcast updates --- 
                             broadcast(JSON.stringify({ type: 'products_updated', payload: baseMenuData }));
                             if (translationsChanged) {
                                 broadcast(JSON.stringify({ type: 'translations_updated', payload: translations }));
                             }
                             // Save updated data
                             saveDataToFile(PRODUCTS_FILE, baseMenuData);
                             if (originalCategoryKey !== newCategoryKey) saveDataToFile(CATEGORIES_FILE, categories);
                             if (translationsChanged) saveDataToFile(TRANSLATIONS_FILE, translations); // <<< SAVE TRANSLATIONS
                             // TODO: Persist changes
                         } else {
                             console.warn('Product not found for update:', productId);
                         }
                    } else {
                         console.warn('Unauthorized or invalid admin_product_updated attempt.');
                    }
                    break;

                case 'admin_product_removed':
                     if (clientInfo.isManagement && parsedMessage.payload && parsedMessage.payload.productId && parsedMessage.payload.categoryKey) {
                         const { productId, categoryKey } = parsedMessage.payload;
                         console.log('Admin action: Removing product', productId, 'from category', categoryKey);
                         const index = baseMenuData.findIndex(p => p.id === productId);
                         if (index > -1) {
                             const removedProduct = baseMenuData.splice(index, 1)[0]; // Remove from products

                             // Remove from category list
                             const catIndex = categories.findIndex(c => c.key === categoryKey);
                             if (catIndex > -1) {
                                 categories[catIndex].productIds = categories[catIndex].productIds.filter(pid => pid !== productId);
                                 // Broadcast category update
                                 broadcast(JSON.stringify({ type: 'categories_updated', payload: categories }));
                             }

                             // Optional: Clean up translations if no longer used by any product
                             // This requires checking all remaining products - can be complex
                             const isNameKeyUsed = baseMenuData.some(p => p.name_key === removedProduct.name_key);
                             const isDescKeyUsed = baseMenuData.some(p => p.description_key === removedProduct.description_key);
                             let translationsChanged = false;
                             if (!isNameKeyUsed && translations[removedProduct.name_key]) {
                                 delete translations[removedProduct.name_key];
                                 translationsChanged = true;
                             }
                             if (!isDescKeyUsed && translations[removedProduct.description_key]) {
                                 delete translations[removedProduct.description_key];
                                 translationsChanged = true;
                             }

                             // Broadcast updates
                             broadcast(JSON.stringify({ type: 'products_updated', payload: baseMenuData }));
                             if (translationsChanged) {
                                 broadcast(JSON.stringify({ type: 'translations_updated', payload: translations }));
                             }
                             // Save updated data
                             saveDataToFile(PRODUCTS_FILE, baseMenuData);
                             saveDataToFile(CATEGORIES_FILE, categories);
                             if (translationsChanged) {
                                 saveDataToFile(TRANSLATIONS_FILE, translations);
                             }
                             // TODO: Persist changes
                         } else {
                             console.warn('Product not found for deletion:', productId);
                         }
                     } else {
                          console.warn('Unauthorized or invalid admin_product_removed attempt.');
                     }
                     break;

                case 'admin_category_added':
                    if (clientInfo.isManagement && parsedMessage.payload && parsedMessage.payload.category && parsedMessage.payload.translations) {
                        const { category, translations: newTranslations } = parsedMessage.payload;
                        console.log('Admin action: Adding category', category.key);
                        // Validate
                        if (category.key && category.name_key && Array.isArray(category.productIds) && !categories.some(c => c.key === category.key)) {
                            // Add category
                            categories.push(category);
                            // Add translations
                            Object.assign(translations, newTranslations); // Merge new translations

                            // Broadcast updates
                            broadcast(JSON.stringify({ type: 'categories_updated', payload: categories }));
                            broadcast(JSON.stringify({ type: 'translations_updated', payload: translations }));
                             // Save updated data
                             saveDataToFile(CATEGORIES_FILE, categories);
                             saveDataToFile(TRANSLATIONS_FILE, translations);
                             // TODO: Persist changes
                        } else {
                             console.warn('Invalid category data or category key already exists:', category.key);
                        }
                    } else {
                         console.warn('Unauthorized or invalid admin_category_added attempt.');
                    }
                    break;

                case 'admin_category_updated':
                     if (clientInfo.isManagement && parsedMessage.payload && parsedMessage.payload.categoryKey && parsedMessage.payload.nameKey && parsedMessage.payload.translations) {
                         const { categoryKey, nameKey, translations: updatedTranslations } = parsedMessage.payload;
                         console.log('Admin action: Updating category', categoryKey);
                         const catIndex = categories.findIndex(c => c.key === categoryKey);
                         if (catIndex > -1) {
                             // Update name key if needed (though it usually doesn't change)
                             categories[catIndex].name_key = nameKey;
                             // Update translations
                             Object.assign(translations, updatedTranslations);

                             // Broadcast updates
                             broadcast(JSON.stringify({ type: 'categories_updated', payload: categories })); // Re-broadcast categories in case name_key changed
                             broadcast(JSON.stringify({ type: 'translations_updated', payload: translations }));
                             // Save updated data
                             saveDataToFile(CATEGORIES_FILE, categories);
                             saveDataToFile(TRANSLATIONS_FILE, translations);
                             // TODO: Persist changes
                         } else {
                              console.warn('Category not found for update:', categoryKey);
                         }
                     } else {
                          console.warn('Unauthorized or invalid admin_category_updated attempt.');
                     }
                     break;

                 case 'admin_category_deleted':
                      if (clientInfo.isManagement && parsedMessage.payload && parsedMessage.payload.categoryKey && parsedMessage.payload.nameKey) {
                          const { categoryKey, nameKey } = parsedMessage.payload;
                          console.log('Admin action: Deleting category', categoryKey);
                          const catIndex = categories.findIndex(c => c.key === categoryKey);
                          if (catIndex > -1) {
                              // Ensure category is empty before deleting (important!)
                              if (categories[catIndex].productIds.length > 0) {
                                   console.warn(`Attempted to delete non-empty category: ${categoryKey}. Ignoring.`);
                                   // Optionally send an error message back to the specific admin client
                                   // ws.send(JSON.stringify({ type: 'admin_error', payload: { message: `Cannot delete non-empty category ${categoryKey}` }}));
                                   break; // Stop processing this message
                              }

                              // Remove category
                              categories.splice(catIndex, 1);
                              // Remove translation
                              if (translations[nameKey]) {
                                  delete translations[nameKey];
                                  broadcast(JSON.stringify({ type: 'translations_updated', payload: translations }));
                                  saveDataToFile(TRANSLATIONS_FILE, translations); // <<< SAVE TRANSLATIONS
                              }

                              // Broadcast category update
                              broadcast(JSON.stringify({ type: 'categories_updated', payload: categories }));
                              // Save updated data
                              saveDataToFile(CATEGORIES_FILE, categories);
                              // TODO: Persist changes
                          } else {
                               console.warn('Category not found for deletion:', categoryKey);
                          }
                      } else {
                           console.warn('Unauthorized or invalid admin_category_deleted attempt.');
                      }
                      break;

                case 'admin_categories_reordered': // New case for reordering
                    if (clientInfo.isManagement && Array.isArray(parsedMessage.payload)) {
                         // Basic validation: Check if payload structure looks like categories array
                        const isValidPayload = parsedMessage.payload.every(cat => cat && cat.key && cat.name_key && Array.isArray(cat.productIds));
                        if (isValidPayload) {
                            console.log('Admin action: Reordering categories/products');
                            categories = parsedMessage.payload; // Replace server's array with the new order
                            // Broadcast the update to all clients
                            broadcast(JSON.stringify({ type: 'categories_updated', payload: categories }));
                            // Save updated data
                            saveDataToFile(CATEGORIES_FILE, categories);
                             // TODO: Persist changes
                        } else {
                             console.warn('Invalid payload structure for admin_categories_reordered.');
                        }
                    } else {
                         console.warn('Unauthorized or invalid admin_categories_reordered attempt.');
                    }
                    break;

                case 'admin_config_imported': // New case for importing config
                    if (clientInfo.isManagement && parsedMessage.payload && parsedMessage.payload.products && parsedMessage.payload.categories && parsedMessage.payload.translations) {
                         console.log('Admin action: Importing configuration...');
                         const { products, categories: importedCategories, translations: importedTranslations } = parsedMessage.payload;
                        
                         // Basic validation (can be improved)
                         const isValidProducts = Array.isArray(products);
                         const isValidCategories = Array.isArray(importedCategories) && importedCategories.every(cat => cat && cat.key && cat.name_key && Array.isArray(cat.productIds));
                         const isValidTranslations = typeof importedTranslations === 'object';

                         if (isValidProducts && isValidCategories && isValidTranslations) {
                             // Replace server data with imported data
                             baseMenuData = products;
                             categories = importedCategories;
                             translations = importedTranslations;
                             console.log('Server data replaced with imported configuration.');

                             // Save the new data to files
                             saveDataToFile(PRODUCTS_FILE, baseMenuData);
                             saveDataToFile(CATEGORIES_FILE, categories);
                             saveDataToFile(TRANSLATIONS_FILE, translations);
                             console.log('Imported configuration saved to files.');

                             // Broadcast updates to all clients
                             broadcast(JSON.stringify({ type: 'products_updated', payload: baseMenuData }));
                             broadcast(JSON.stringify({ type: 'categories_updated', payload: categories }));
                             broadcast(JSON.stringify({ type: 'translations_updated', payload: translations }));
                             console.log('Broadcasted configuration updates to all clients.');

                         } else {
                             console.warn('Invalid payload structure for admin_config_imported.');
                             // Optionally notify the admin client about the error
                         }
                    } else {
                         console.warn('Unauthorized or invalid admin_config_imported attempt.');
                    }
                    break;

                case 'admin_set_canteen_status':
                    if (clientInfo.isManagement && parsedMessage.payload && typeof parsedMessage.payload.isOpen === 'boolean') {
                        const newStatus = parsedMessage.payload.isOpen;
                        if (canteenStatus.isOpen !== newStatus) {
                            canteenStatus.isOpen = newStatus;
                            console.log(`Admin action: Canteen status set to ${canteenStatus.isOpen ? 'Open' : 'Closed'}`);
                            saveDataToFile(STATUS_FILE, canteenStatus);
                            broadcast(JSON.stringify({ type: 'canteen_status_updated', payload: canteenStatus }));
                        } else {
                             console.log(`Canteen status already ${canteenStatus.isOpen ? 'Open' : 'Closed'}. No change.`);
                        }
                    } else {
                         console.warn('Unauthorized or invalid admin_set_canteen_status attempt.');
                    }
                    break;

                // --- END: Admin Actions ---

                default:
                    console.log('Unknown message type received:', parsedMessage.type);
            }

        } catch (error) {
            console.error('[Server] Failed to parse message or error in handler:', error, message);
        }
    });

    ws.on('close', () => {
        console.log(`Client disconnected (Was Management: ${clients.get(ws)?.isManagement})`);
        clients.delete(ws); // Remove client from map
    });

    ws.on('error', (error) => {
        console.error('WebSocket error:', error);
        if (clients.has(ws)) {
             console.log(`Removing client due to error (Was Management: ${clients.get(ws)?.isManagement})`);
             clients.delete(ws); // Clean up on error
        }
    });
});

// --- Broadcast Functions ---
function broadcast(message) {
    // console.log(`Broadcasting to ${clients.size} clients`); // Can be noisy
    clients.forEach((info, client) => {
        if (client.readyState === WebSocket.OPEN) {
            try {
                client.send(message);
            } catch (error) {
                 console.error(`Failed to send message to client: ${error}`);
                 // Optionally remove client if send fails repeatedly
                 // clients.delete(client);
            }
        }
    });
}

function broadcastToManagement(message) {
    // console.log(`Broadcasting to management clients`); // Can be noisy
    clients.forEach((info, client) => {
        if (info.isManagement && client.readyState === WebSocket.OPEN) {
             try {
                client.send(message);
             } catch (error) {
                  console.error(`Failed to send message to management client: ${error}`);
                  // Optionally remove client
                  // clients.delete(client);
             }
        }
    });
}

// Optional: Add periodic cleanup for closed connections in the map
setInterval(() => {
    let cleanedCount = 0;
    clients.forEach((info, client) => {
        if (client.readyState !== WebSocket.OPEN && client.readyState !== WebSocket.CONNECTING) {
            clients.delete(client);
            cleanedCount++;
        }
    });
    if (cleanedCount > 0) {
        console.log(`Cleaned up ${cleanedCount} stale client connection(s) from map.`);
    }
}, 60000); // Check every 60 seconds

// --- Graceful Shutdown (Example) ---
process.on('SIGINT', () => {
    console.log('\nShutting down WebSocket server...');
    console.log('Saving final data state...');
    saveDataToFile(ORDERS_FILE, allOrders);
    saveDataToFile(PRODUCTS_FILE, baseMenuData);
    saveDataToFile(CATEGORIES_FILE, categories);
    saveDataToFile(TRANSLATIONS_FILE, translations);
    saveDataToFile(STATUS_FILE, canteenStatus);
    console.log('Data saving complete.');

    wss.close((err) => {
        if (err) {
            console.error('Error closing WebSocket server:', err);
        } else {
            console.log('WebSocket server closed.');
        }
        process.exit(err ? 1 : 0);
    });

    // Force close connections if server close hangs
    setTimeout(() => {
        console.log('Forcing remaining connections to close.');
        clients.forEach((info, client) => {
            client.terminate();
        });
        process.exit(1);
    }, 5000); // Wait 5 seconds before force closing
}); 