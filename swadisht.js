// Supabase Configuration
const SUPABASE_URL = 'https://mnphmmrtckqgtvcfhfwj.supabase.co'; // Add your Supabase URL
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ucGhtbXJ0Y2txZ3R2Y2ZoZndqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg4OTk0NDMsImV4cCI6MjA4NDQ3NTQ0M30.y_4ziH6M8TjO0KQUwvWR7oBY-l9PQxt3EQVCO2XUPNw'; // Add your Supabase Anon Key

// Initialize Supabase Client
const supabaseClient = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// ============ RESTAURANT OPERATIONS ============

/**
 * Fetch all active restaurants from the database
 */
async function fetchRestaurants() {
  try {
    const { data, error } = await supabaseClient
      .from('restraunts')
      .select('*')
      .eq('is_active', true);

    if (error) {
      console.error('Error fetching restaurants:', error);
      return [];
    }

    return data || [];
  } catch (error) {
    console.error('Error in fetchRestaurants:', error);
    return [];
  }
}

/**
 * Fetch a specific restaurant by ID
 */
async function fetchRestaurantById(restrauntId) {
  try {
    const { data, error } = await supabaseClient
      .from('restraunts')
      .select('*')
      .eq('restraunt_id', restrauntId)
      .single();

    if (error) {
      console.error('Error fetching restaurant:', error);
      return null;
    }

    return data;
  } catch (error) {
    console.error('Error in fetchRestaurantById:', error);
    return null;
  }
}

// ============ FOOD ITEMS OPERATIONS ============

/**
 * Fetch all available food items
 */
async function fetchFoodItems() {
  try {
    const { data, error } = await supabaseClient
      .from('food_items')
      .select('*')
      .eq('is_available', true);

    if (error) {
      console.error('Error fetching food items:', error);
      return [];
    }

    return data || [];
  } catch (error) {
    console.error('Error in fetchFoodItems:', error);
    return [];
  }
}

/**
 * Fetch food items by restaurant ID
 */
async function fetchFoodItemsByRestaurant(restrauntId) {
  try {
    const { data, error } = await supabaseClient
      .from('food_items')
      .select('*')
      .eq('restraunt_id', restrauntId)
      .eq('is_available', true);

    if (error) {
      console.error('Error fetching food items for restaurant:', error);
      return [];
    }

    return data || [];
  } catch (error) {
    console.error('Error in fetchFoodItemsByRestaurant:', error);
    return [];
  }
}

/**
 * Fetch a specific food item by ID
 */
async function fetchFoodItemById(foodId) {
  try {
    const { data, error } = await supabaseClient
      .from('food_items')
      .select('*')
      .eq('food_id', foodId)
      .single();

    if (error) {
      console.error('Error fetching food item:', error);
      return null;
    }

    return data;
  } catch (error) {
    console.error('Error in fetchFoodItemById:', error);
    return null;
  }
}

// ============ ORDERS OPERATIONS ============

/**
 * Create a new order in the database
 */
async function createOrder(userId, restrauntId, totalAmount, orderItems) {
  try {
    // Create the order
    const { data: orderData, error: orderError } = await supabaseClient
      .from('orders')
      .insert({
        user_id: userId,
        restraunt_id: restrauntId,
        order_status: 'pending',
        total_amount: totalAmount,
        order_time: new Date().toISOString()
      })
      .select()
      .single();

    if (orderError) {
      console.error('Error creating order:', orderError);
      return { success: false, error: orderError };
    }

    const orderId = orderData.order_id;

    // Add order items to the order_items table
    const orderItemsFormatted = orderItems.map(item => ({
      order_id: orderId,
      food_id: item.food_id,
      quantity: item.quantity,
      price: item.price,
      food_image_url: item.food_image_url
    }));

    const { data: itemsData, error: itemsError } = await supabaseClient
      .from('order_items')
      .insert(orderItemsFormatted)
      .select();

    if (itemsError) {
      console.error('Error adding order items:', itemsError);
      return { success: false, error: itemsError, orderId };
    }

    return {
      success: true,
      orderId,
      order: orderData,
      orderItems: itemsData
    };
  } catch (error) {
    console.error('Error in createOrder:', error);
    return { success: false, error };
  }
}

/**
 * Fetch orders for a specific user
 */
async function fetchUserOrders(userId) {
  try {
    const { data, error } = await supabaseClient
      .from('orders')
      .select('*')
      .eq('user_id', userId)
      .order('order_time', { ascending: false });

    if (error) {
      console.error('Error fetching user orders:', error);
      return [];
    }

    return data || [];
  } catch (error) {
    console.error('Error in fetchUserOrders:', error);
    return [];
  }
}

/**
 * Fetch a specific order with its items
 */
async function fetchOrderDetails(orderId) {
  try {
    // Fetch order
    const { data: orderData, error: orderError } = await supabaseClient
      .from('orders')
      .select('*')
      .eq('order_id', orderId)
      .single();

    if (orderError) {
      console.error('Error fetching order:', orderError);
      return null;
    }

    // Fetch order items
    const { data: itemsData, error: itemsError } = await supabaseClient
      .from('order_items')
      .select('*')
      .eq('order_id', orderId);

    if (itemsError) {
      console.error('Error fetching order items:', itemsError);
      return null;
    }

    return {
      order: orderData,
      items: itemsData || []
    };
  } catch (error) {
    console.error('Error in fetchOrderDetails:', error);
    return null;
  }
}

/**
 * Update order status
 */
async function updateOrderStatus(orderId, newStatus) {
  try {
    const { data, error } = await supabaseClient
      .from('orders')
      .update({ order_status: newStatus })
      .eq('order_id', orderId)
      .select()
      .single();

    if (error) {
      console.error('Error updating order status:', error);
      return { success: false, error };
    }

    return { success: true, data };
  } catch (error) {
    console.error('Error in updateOrderStatus:', error);
    return { success: false, error };
  }
}

/**
 * Fetch all orders for a specific restaurant
 */
async function fetchRestaurantOrders(restrauntId) {
  try {
    const { data, error } = await supabaseClient
      .from('orders')
      .select('*')
      .eq('restraunt_id', restrauntId)
      .order('order_time', { ascending: false });

    if (error) {
      console.error('Error fetching restaurant orders:', error);
      return [];
    }

    return data || [];
  } catch (error) {
    console.error('Error in fetchRestaurantOrders:', error);
    return [];
  }
}

// ============ ORDER ITEMS OPERATIONS ============

/**
 * Fetch all items in an order
 */
async function fetchOrderItems(orderId) {
  try {
    const { data, error } = await supabaseClient
      .from('order_items')
      .select('*')
      .eq('order_id', orderId);

    if (error) {
      console.error('Error fetching order items:', error);
      return [];
    }

    return data || [];
  } catch (error) {
    console.error('Error in fetchOrderItems:', error);
    return [];
  }
}

/**
 * Add an order item to an existing order
 */
async function addOrderItem(orderId, foodId, quantity, price, foodImageUrl) {
  try {
    const { data, error } = await supabaseClient
      .from('order_items')
      .insert({
        order_id: orderId,
        food_id: foodId,
        quantity,
        price,
        food_image_url: foodImageUrl
      })
      .select()
      .single();

    if (error) {
      console.error('Error adding order item:', error);
      return { success: false, error };
    }

    return { success: true, data };
  } catch (error) {
    console.error('Error in addOrderItem:', error);
    return { success: false, error };
  }
}

// ============ CART MANAGEMENT ============

class Swadisht {
  constructor() {
    this.cart = [];
    this.loadCartFromStorage();
  }

  /**
   * Add item to cart
   */
  addToCart(foodItem) {
    const existingItem = this.cart.find(item => item.food_id === foodItem.food_id);

    if (existingItem) {
      existingItem.quantity += 1;
    } else {
      this.cart.push({
        ...foodItem,
        quantity: 1
      });
    }

    this.saveCartToStorage();
    return this.cart;
  }

  /**
   * Remove item from cart
   */
  removeFromCart(foodId) {
    this.cart = this.cart.filter(item => item.food_id !== foodId);
    this.saveCartToStorage();
    return this.cart;
  }

  /**
   * Update item quantity in cart
   */
  updateCartItemQuantity(foodId, quantity) {
    const item = this.cart.find(item => item.food_id === foodId);
    if (item) {
      if (quantity <= 0) {
        this.removeFromCart(foodId);
      } else {
        item.quantity = quantity;
      }
      this.saveCartToStorage();
    }
    return this.cart;
  }

  /**
   * Clear cart
   */
  clearCart() {
    this.cart = [];
    this.saveCartToStorage();
    return this.cart;
  }

  /**
   * Get cart items
   */
  getCart() {
    return this.cart;
  }

  /**
   * Calculate total amount
   */
  calculateTotal() {
    return this.cart.reduce((total, item) => total + (item.price * item.quantity), 0);
  }

  /**
   * Save cart to local storage
   */
  saveCartToStorage() {
    localStorage.setItem('swadisht_cart', JSON.stringify(this.cart));
  }

  /**
   * Load cart from local storage
   */
  loadCartFromStorage() {
    const savedCart = localStorage.getItem('swadisht_cart');
    if (savedCart) {
      this.cart = JSON.parse(savedCart);
    }
  }

  /**
   * Group cart items by restaurant
   */
  groupByRestaurant() {
    const grouped = {};
    this.cart.forEach(item => {
      if (!grouped[item.restraunt_id]) {
        grouped[item.restraunt_id] = [];
      }
      grouped[item.restraunt_id].push(item);
    });
    return grouped;
  }

  /**
   * Checkout - create order from cart
   */
  async checkout(userId) {
    if (this.cart.length === 0) {
      return { success: false, message: 'Cart is empty' };
    }

    const grouped = this.groupByRestaurant();
    const totalAmount = this.calculateTotal();

    // Assuming single restaurant order (can be extended for multiple restaurants)
    const restrauntId = Object.keys(grouped)[0];

    const orderItems = this.cart.map(item => ({
      quantity: item.quantity,
      price: item.price,
      food_image_url: item.image_url
    }));

    const result = await createOrder(userId, restrauntId, totalAmount, orderItems);

    if (result.success) {
      this.clearCart();
    }

    return result;
  }
}

// Initialize Swadisht instance
const swadisht = new Swadisht();

// ============ EXPORT FOR MODULE USE ============
// If using module bundler, uncomment:
/*
export {
  swadisht,
  fetchRestaurants,
  fetchRestaurantById,
  fetchFoodItems,
  fetchFoodItemsByRestaurant,
  fetchFoodItemById,
  createOrder,
  fetchUserOrders,
  fetchOrderDetails,
  updateOrderStatus,
  fetchRestaurantOrders,
  fetchOrderItems,
  addOrderItem
};
*/
