/**
 * @module controllers/orderController
 * @description Handles order creation from carts, history retrieval, and smart module-based notification routing.
 */

const db = require("../config/db");

/**
 * Processes checkout by creating an order from the user's active cart.
 * Calculates billing, guesses the app module (e.g., Grokly, Swadisht) based on cart items,
 * transfers items to order history, clears the cart, and dispatches a notification.
 * * @async
 * @function createOrder
 * @param {import('express').Request} req - Express request object.
 * @param {Object} req.body - The request payload.
 * @param {number|string} req.body.address_id - The ID of the selected delivery address.
 * @param {import('express').Response} res - Express response object.
 * @returns {Promise<void>} JSON response containing the new order ID and total amount.
 */
const createOrder = async (req, res) => {
    try {
        const uid = req.user.uid;
        const { address_id } = req.body;

        if (!address_id) {
            return res.status(400).json({ success: false, message: "Delivery address is required" });
        }

        // Get user ID
        const [user] = await db.execute('SELECT id FROM users WHERE firebase_uid = ?', [uid]);
        if (user.length === 0) return res.status(404).json({ success: false, message: "User not found" });
        const userId = user[0].id;

        // Get Cart ID
        const [cart] = await db.execute('SELECT id FROM cart WHERE user_id = ?', [userId]);
        if (cart.length === 0) return res.status(400).json({ success: false, message: "Cart is empty" });
        const cartId = cart[0].id;

        // Get Cart Items
        const [items] = await db.execute('SELECT * FROM cart_items WHERE cart_id = ?', [cartId]);
        if (items.length === 0) return res.status(400).json({ success: false, message: "Cart is empty" });

        // Calculate Totals
        let subtotal = 0;
        items.forEach(item => {
            subtotal += parseFloat(item.price) * item.quantity;
        });
        
        const delivery_fee = subtotal > 0 ? 40 : 0; // Flat ₹40 delivery fee
        const tax = subtotal * 0.05; // 5% tax
        const total_amount = subtotal + delivery_fee + tax;

        // Create the Order
        const [orderResult] = await db.execute(
            `INSERT INTO orders (user_id, address_id, subtotal, delivery_fee, tax, total_amount) 
             VALUES (?, ?, ?, ?, ?, ?)`,
            [userId, address_id, subtotal, delivery_fee, tax, total_amount]
        );
        const orderId = orderResult.insertId;

        // ✅ SMART MODULE DETECTION: Guess the app module based on the items in the cart
        let moduleName = "Accesso";
        if (items.length > 0) {
            const firstItem = items[0].name.toLowerCase();
            const groklyKeywords = ['milk', 'rice', 'tomato', 'paneer', 'egg', 'oil', 'apple', 'banana', 'grocery'];
            const swadishtKeywords = ['pizza', 'biryani', 'chicken', 'dosa', 'burger', 'pasta', 'fries', 'wrap', 'coffee'];
            const instastyleKeywords = ['shirt', 'dress', 'jean', 'shoe', 'knit', 'jacket', 'co-ord', 'blazer'];

            if (groklyKeywords.some(k => firstItem.includes(k))) moduleName = "Grokly";
            else if (swadishtKeywords.some(k => firstItem.includes(k))) moduleName = "Swadisht";
            else if (instastyleKeywords.some(k => firstItem.includes(k))) moduleName = "Instastyle";
        }

        // Move items to order_items
        for (const item of items) {
            await db.execute(
                `INSERT INTO order_items (order_id, product_id, name, price, image_url, emoji, quantity) 
                 VALUES (?, ?, ?, ?, ?, ?, ?)`,
                [orderId, item.product_id, item.name, item.price, item.image_url, item.emoji, item.quantity]
            );
        }

        // Clear Cart
        await db.execute('DELETE FROM cart_items WHERE cart_id = ?', [cartId]);

        // ✅ Notification includes the specific Module Name (Grokly, Swadisht, etc.)
        await db.execute(
            'INSERT INTO notifications (user_id, type, title, message, target_id) VALUES (?, ?, ?, ?, ?)',
            [
                uid, 
                'order', 
                `${moduleName} Order Confirmed! 🎉`, 
                `Your ${moduleName} order #${orderId} has been successfully placed and is being prepared.`, 
                orderId
            ]
        );

        res.status(200).json({ 
            success: true, 
            message: "Order created successfully!", 
            data: { orderId: orderId, total_amount: total_amount } 
        });

    } catch (error) {
        console.error("Order Creation Error:", error);
        res.status(500).json({ success: false, message: error.message });
    }
};

/**
 * Retrieves a list of all past orders for the authenticated user, sorted by newest first.
 * Attaches a summary of items to each order to assist the client app in identifying the module.
 * * @async
 * @function getOrders
 * @param {import('express').Request} req - Express request object.
 * @param {import('express').Response} res - Express response object.
 * @returns {Promise<void>} JSON response containing an array of order records.
 */
const getOrders = async (req, res) => {
    try {
        const uid = req.user.uid;
        const [user] = await db.execute('SELECT id FROM users WHERE firebase_uid = ?', [uid]);
        if (user.length === 0) return res.status(404).json({ success: false, message: "User not found" });
        const userId = user[0].id;

        // Fetch all orders
        const [orders] = await db.execute('SELECT * FROM orders WHERE user_id = ? ORDER BY created_at DESC', [userId]);

        // ✅ Fetch items inside the order so Flutter can read names to determine module identity
        for (let i = 0; i < orders.length; i++) {
            const [items] = await db.execute('SELECT name, emoji FROM order_items WHERE order_id = ?', [orders[i].id]);
            orders[i].items = items;
        }

        res.status(200).json({ success: true, data: orders });
    } catch (error) {
        console.error("Fetch Orders Error:", error);
        res.status(500).json({ success: false, message: error.message });
    }
};

/**
 * Retrieves the complete details of a specific order by its ID, including all associated items.
 * * @async
 * @function getOrderDetails
 * @param {import('express').Request} req - Express request object.
 * @param {Object} req.params - URL parameters.
 * @param {number|string} req.params.id - The unique identifier of the order.
 * @param {import('express').Response} res - Express response object.
 * @returns {Promise<void>} JSON response containing the order metadata and an array of its items.
 */
const getOrderDetails = async (req, res) => {
    try {
        const orderId = req.params.id;
        
        const [order] = await db.execute('SELECT * FROM orders WHERE id = ?', [orderId]);
        if (order.length === 0) return res.status(404).json({ success: false, message: "Order not found" });

        const [items] = await db.execute('SELECT * FROM order_items WHERE order_id = ?', [orderId]);

        res.status(200).json({ 
            success: true, 
            data: { order: order[0], items: items } 
        });
    } catch (error) {
        console.error("Fetch Order Details Error:", error);
        res.status(500).json({ success: false, message: error.message });
    }
};

module.exports = { createOrder, getOrders, getOrderDetails };