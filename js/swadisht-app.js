// ===== GLOBAL VARIABLES =====
let allFoodItems = [];
let allRestaurants = [];
let menuItems = [];
let currentFilteredItems = [];
let isLoading = true;

// ===== INITIALIZATION =====
document.addEventListener('DOMContentLoaded', async function() {
    console.log('DOMContentLoaded triggered');
    console.log('supabaseClient available:', typeof supabaseClient !== 'undefined');
    console.log('swadisht available:', typeof swadisht !== 'undefined');
    
    isLoading = true;
    await loadRestaurants();
    await loadFoodItems();
    setupEventListeners();
    isLoading = false;
});

// ===== DATABASE LOADING FUNCTIONS =====
async function loadRestaurants() {
    try {
        console.log('loadRestaurants started...');
        const restaurants = await fetchRestaurants();
        console.log('Restaurants received:', restaurants);
        
        if (restaurants && restaurants.length > 0) {
            allRestaurants = restaurants;
            populateRestaurantFilter();
            console.log('Restaurants loaded:', restaurants.length);
        } else {
            console.warn('No restaurants found or empty response');
            allRestaurants = [];
        }
    } catch (error) {
        console.error('Error loading restaurants:', error);
        allRestaurants = [];
        showNotification('Unable to load restaurants. Please try refreshing the page.', 'warning');
    }
}

async function loadFoodItems() {
    try {
        console.log('loadFoodItems started...');
        const foodItems = await fetchFoodItems();
        console.log('Food items received:', foodItems);
        
        if (foodItems && foodItems.length > 0) {
            allFoodItems = foodItems;
            displayMenuItems(foodItems);
            buildMenuItemsList(foodItems);
            console.log('Food items displayed successfully');
        } else {
            console.warn('No food items found or empty response');
            allFoodItems = [];
            displayMenuItems([]);
        }
    } catch (error) {
        console.error('Error loading food items:', error);
        allFoodItems = [];
        displayMenuItems([]);
        showNotification('Unable to load food items. Please check your connection and try again.', 'warning');
    }
}

// ===== DISPLAY FUNCTIONS =====
function displayMenuItems(items) {
    const container = document.getElementById('menu-container');
    
    if (!items || items.length === 0) {
        container.innerHTML = `
            <div class="col-span-full text-center py-12">
                <i class="fas fa-utensils text-4xl text-gray-400 mb-4"></i>
                <p class="text-gray-600 text-lg">No dishes available at the moment</p>
                <p class="text-gray-500 text-sm mt-2">We're updating our menu. Please check back soon!</p>
            </div>
        `;
        return;
    }

    let html = '';
    items.forEach(item => {
        const imageUrl = item.image_url || 'https://via.placeholder.com/400x300?text=' + encodeURIComponent(item.name);
        const isAvailable = item.is_available !== false;
        
        html += `
            <div class="menu-item bg-white rounded-lg shadow-md overflow-hidden transition duration-300 ${!isAvailable ? 'opacity-50' : ''}">
                <img src="${imageUrl}" alt="${item.name}" class="w-full h-48 object-cover">
                <div class="p-6">
                    <h3 class="text-xl font-semibold text-gray-800 mb-2">${item.name}</h3>
                    <p class="text-gray-600 mb-4 text-sm">${item.description || 'Delicious Indian dish'}</p>
                    <div class="flex justify-between items-center">
                        <span class="text-2xl font-bold text-orange-600">₹${item.price}</span>
                        <button onclick="addToCartFromDB(${item.food_id}, '${item.name}', ${item.price}, '${imageUrl}', ${item.restaurant_id})" 
                            class="order-btn text-white px-4 py-2 rounded-lg ${!isAvailable ? 'opacity-50 cursor-not-allowed' : ''}"
                            ${!isAvailable ? 'disabled' : ''}>
                            ${isAvailable ? 'Add to Cart' : 'Unavailable'}
                        </button>
                    </div>
                </div>
            </div>
        `;
    });

    container.innerHTML = html;
}

function buildMenuItemsList(items) {
    menuItems = items.map(item => ({
        element: document.querySelector(`[data-food-id="${item.food_id}"]`),
        title: item.name.toLowerCase(),
        description: (item.description || '').toLowerCase(),
        foodId: item.food_id,
        item: item
    }));
}

function populateRestaurantFilter() {
    const filter = document.getElementById('restaurant-filter');
    
    // Add restaurant options
    allRestaurants.forEach(restaurant => {
        const option = document.createElement('option');
        option.value = restaurant.restaurant_id;
        option.textContent = restaurant.name;
        filter.appendChild(option);
    });
}

// ===== CART MANAGEMENT FUNCTIONS =====
function addToCartFromDB(foodId, name, price, imageUrl, restaurantId) {
    swadisht.addToCart({
        food_id: foodId,
        name: name,
        price: price,
        image_url: imageUrl,
        restaurant_id: restaurantId
    });
    updateCart();
    showNotification(`${name} added to cart!`);
}

function updateCart() {
    const cartItems = document.getElementById('cart-items');
    const totalPrice = document.getElementById('total-price');
    const cartCount = document.getElementById('cart-count');
    const mobileCartCount = document.getElementById('mobile-cart-count');

    const cart = swadisht.getCart();

    if (cart.length === 0) {
        cartItems.innerHTML = '<p class="text-gray-500 text-center">Your cart is empty</p>';
        cartCount.classList.add('hidden');
        mobileCartCount.classList.add('hidden');
    } else {
        let itemsHtml = '<div class="space-y-4">';
        cart.forEach((item, index) => {
            itemsHtml += `
                <div class="flex justify-between items-center bg-gray-50 p-4 rounded-lg border-l-4 border-orange-400">
                    <div class="flex-1">
                        <p class="font-semibold text-gray-800">${item.name}</p>
                        <p class="text-sm text-gray-600">₹${item.price} x ${item.quantity}</p>
                    </div>
                    <div class="flex items-center gap-2">
                        <button onclick="updateQuantity(${index}, -1)" class="text-gray-600 hover:text-gray-800 px-2 py-1 border rounded">-</button>
                        <span class="px-3">${item.quantity}</span>
                        <button onclick="updateQuantity(${index}, 1)" class="text-gray-600 hover:text-gray-800 px-2 py-1 border rounded">+</button>
                        <button onclick="removeFromCartDB(${index})" class="text-red-500 hover:text-red-700 ml-2">
                            <i class="fas fa-trash"></i>
                        </button>
                    </div>
                </div>
            `;
        });
        itemsHtml += '</div>';
        cartItems.innerHTML = itemsHtml;
        cartCount.textContent = cart.length;
        mobileCartCount.textContent = cart.length;
        cartCount.classList.remove('hidden');
        mobileCartCount.classList.remove('hidden');
    }

    const total = swadisht.calculateTotal();
    totalPrice.textContent = `₹${total.toFixed(2)}`;
}

function updateQuantity(index, change) {
    const cart = swadisht.getCart();
    const newQuantity = cart[index].quantity + change;
    swadisht.updateCartItemQuantity(cart[index].food_id, newQuantity);
    updateCart();
}

function removeFromCartDB(index) {
    const cart = swadisht.getCart();
    swadisht.removeFromCart(cart[index].food_id);
    updateCart();
    showNotification('Item removed from cart');
}

async function placeOrder() {
    const cart = swadisht.getCart();
    const userId = document.getElementById('user-id').value.trim();

    if (!userId) {
        showNotification('Please enter your User ID to place order', 'warning');
        return;
    }

    if (cart.length === 0) {
        showNotification('Please add items to your cart first!', 'warning');
        return;
    }

    try {
        // Get the first restaurant from cart
        const restaurantId = cart[0].restaurant_id;

        // Prepare order items
        const orderItems = cart.map(item => ({
            food_id: item.food_id,
            quantity: item.quantity,
            price: item.price,
            food_image_url: item.image_url
        }));

        // Create order in database
        const result = await createOrder(userId, restaurantId, swadisht.calculateTotal(), orderItems);

        if (result.success) {
            showNotification(`Order #${result.orderId} placed successfully! We will contact you soon.`, 'success');
            swadisht.clearCart();
            updateCart();
            document.getElementById('user-id').value = '';
        } else {
            showNotification('Error placing order: ' + (result.error?.message || 'Unknown error'), 'warning');
        }
    } catch (error) {
        console.error('Error placing order:', error);
        showNotification('Error placing order. Please try again.', 'warning');
    }
}

// ===== NOTIFICATION SYSTEM =====
function showNotification(message, type = 'success') {
    const container = document.getElementById('toast-container');
    if (!container) {
        alert(message);
        return;
    }

    const toast = document.createElement('div');
    const toastClass = type === 'success' ? 'toast-success' : 'toast-info';
    toast.className = `toast ${toastClass}`;
    toast.innerHTML = `
        <span>${message}</span>
        <button aria-label="Close" onclick="this.parentElement.remove()">&times;</button>
    `;
    container.appendChild(toast);

    requestAnimationFrame(() => {
        toast.classList.add('show');
    });

    setTimeout(() => {
        toast.classList.remove('show');
        setTimeout(() => toast.remove(), 200);
    }, 2500);
}

// ===== RESTAURANT FILTER =====
async function filterByRestaurant(restaurantId) {
    if (restaurantId === '') {
        displayMenuItems(allFoodItems);
    } else {
        const filtered = await fetchFoodItemsByRestaurant(parseInt(restaurantId));
        displayMenuItems(filtered);
    }
}

// ===== SEARCH FUNCTIONALITY =====
function searchDishes(query) {
    const searchTerm = query.toLowerCase().trim();
    
    const normalize = (word) => {
        const map = {
            'biriyani': 'biryani',
            'biriani': 'biryani'
        };
        return map[word] || word;
    };

    const levenshtein = (a, b) => {
        if (a === b) return 0;
        const al = a.length, bl = b.length;
        if (al === 0) return bl;
        if (bl === 0) return al;
        const v0 = new Array(bl + 1).fill(0);
        const v1 = new Array(bl + 1).fill(0);
        for (let j = 0; j <= bl; j++) v0[j] = j;
        for (let i = 0; i < al; i++) {
            v1[0] = i + 1;
            for (let j = 0; j < bl; j++) {
                const cost = a[i] === b[j] ? 0 : 1;
                v1[j + 1] = Math.min(v1[j] + 1, v0[j + 1] + 1, v0[j] + cost);
            }
            for (let j = 0; j <= bl; j++) v0[j] = v1[j];
        }
        return v1[bl];
    };

    const tokens = searchTerm === '' ? [] : searchTerm.split(/\s+/).map(normalize).filter(Boolean);

    let filteredItems = allFoodItems;

    if (tokens.length > 0) {
        filteredItems = allFoodItems.filter(item => {
            const title = item.name.toLowerCase();
            const description = (item.description || '').toLowerCase();

            return tokens.every(token => {
                if (title.includes(token) || description.includes(token)) return true;
                
                const words = (title + ' ' + description).split(/\s+/);
                return words.some(w => {
                    const d = levenshtein(w, token);
                    return d <= 1 && Math.min(w.length, token.length) > 2;
                });
            });
        });
    }

    displayMenuItems(filteredItems);
}

function clearSearch() {
    document.getElementById('search-input').value = '';
    searchDishes('');
}

function clearMobileSearch() {
    document.getElementById('mobile-search-input').value = '';
    searchDishes('');
}

// ===== MOBILE MENU =====
function toggleMenu() {
    const menu = document.getElementById('mobile-menu');
    menu.classList.toggle('hidden');
}

// ===== EVENT LISTENERS =====
function setupEventListeners() {
    const searchInput = document.getElementById('search-input');
    const mobileSearchInput = document.getElementById('mobile-search-input');
    const restaurantFilter = document.getElementById('restaurant-filter');

    if (searchInput) {
        searchInput.addEventListener('input', function(e) {
            searchDishes(e.target.value);
        });
    }

    if (mobileSearchInput) {
        mobileSearchInput.addEventListener('input', function(e) {
            searchDishes(e.target.value);
        });
    }

    if (restaurantFilter) {
        restaurantFilter.addEventListener('change', function(e) {
            filterByRestaurant(e.target.value);
        });
    }

    // Smooth scrolling for navigation links
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', function (e) {
            e.preventDefault();
            const target = document.querySelector(this.getAttribute('href'));
            if (target) {
                target.scrollIntoView({
                    behavior: 'smooth'
                });
            }
        });
    });

    // Load initial cart from storage
    updateCart();
}
