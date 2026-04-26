/**
 * @module controllers/cartController
 * @description Handles shopping cart operations including fetching, adding, updating, and removing items.
 */

const db = require("../config/db");

/**
 * Retrieves the existing cart ID for a user or creates a new cart if one doesn't exist.
 * * @async
 * @function getOrCreateCartId
 * @param {number} userId - The local database ID of the user.
 * @returns {Promise<number>} The ID of the user's cart.
 */
const getOrCreateCartId = async (userId) => {
    const [cart] = await db.execute('SELECT id FROM cart WHERE user_id = ?', [userId]);
    if (cart.length > 0) return cart[0].id;
    
    const [newCart] = await db.execute('INSERT INTO cart (user_id) VALUES (?)', [userId]);
    return newCart.insertId;
};

/**
 * Fetches the user's cart items and calculates the order summary (subtotal, taxes, delivery).
 * * @async
 * @function getCart
 * @param {import('express').Request} req - Express request object containing the Firebase UID in `req.user`.
 * @param {import('express').Response} res - Express response object.
 * @returns {Promise<void>} JSON response with cart items and pricing summary.
 */
const getCart = async (req, res) => {
    try {
        const uid = req.user.uid;
        const [user] = await db.execute('SELECT id FROM users WHERE firebase_uid = ?', [uid]);
        if (user.length === 0) return res.status(404).json({ success: false, message: "User not found" });
        
        const userId = user[0].id;
        const cartId = await getOrCreateCartId(userId);

        // Fetch everything directly from cart_items
        const [items] = await db.execute('SELECT product_id, name, price, image_url, emoji, quantity FROM cart_items WHERE cart_id = ?', [cartId]);

        let subtotal = 0;
        items.forEach(item => {
            subtotal += parseFloat(item.price) * item.quantity;
        });

        const deliveryCharges = subtotal > 0 ? 40 : 0;
        const tax = subtotal * 0.05;
        const total = subtotal + deliveryCharges + tax;

        res.status(200).json({
            success: true,
            data: { items, summary: { subtotal, deliveryCharges, tax, total } }
        });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
};

/**
 * Adds a product to the user's cart or increments its quantity if it already exists.
 * * @async
 * @function addToCart
 * @param {import('express').Request} req - Express request object.
 * @param {Object} req.body - The product details sent from the client.
 * @param {string|number} req.body.product_id - The unique identifier of the product.
 * @param {number} [req.body.quantity=1] - The quantity to add.
 * @param {string} req.body.name - The product name.
 * @param {number} req.body.price - The product price.
 * @param {string} [req.body.image_url] - URL of the product image.
 * @param {string} [req.body.emoji] - Emoji representation of the product.
 * @param {import('express').Response} res - Express response object.
 * @returns {Promise<void>} JSON response indicating success.
 */
const addToCart = async (req, res) => {
    try {
        const uid = req.user.uid;
        
        const { product_id, quantity, name, price, image_url, emoji } = req.body;
        
        const [user] = await db.execute('SELECT id FROM users WHERE firebase_uid = ?', [uid]);
        const userId = user[0].id;
        const cartId = await getOrCreateCartId(userId);

        await db.execute(`
            INSERT INTO cart_items (cart_id, product_id, name, price, image_url, emoji, quantity) 
            VALUES (?, ?, ?, ?, ?, ?, ?) 
            ON DUPLICATE KEY UPDATE quantity = quantity + VALUES(quantity)
        `, [cartId, product_id, name, price, image_url, emoji, quantity || 1]);

        res.status(200).json({ success: true, message: "Added" });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
};

/**
 * Updates the quantity of a specific product in the user's cart. 
 * Removes the item entirely if the updated quantity is 0 or less.
 * * @async
 * @function updateQuantity
 * @param {import('express').Request} req - Express request object.
 * @param {Object} req.body - Request body.
 * @param {string|number} req.body.product_id - The unique identifier of the product.
 * @param {number} req.body.quantity - The new quantity.
 * @param {import('express').Response} res - Express response object.
 * @returns {Promise<void>} JSON response indicating success.
 */
const updateQuantity = async (req, res) => {
    try {
        const uid = req.user.uid;
        const { product_id, quantity } = req.body;
        
        const [user] = await db.execute('SELECT id FROM users WHERE firebase_uid = ?', [uid]);
        const cartId = await getOrCreateCartId(user[0].id);

        if (quantity <= 0) {
            await db.execute('DELETE FROM cart_items WHERE cart_id = ? AND product_id = ?', [cartId, product_id]);
        } else {
            await db.execute('UPDATE cart_items SET quantity = ? WHERE cart_id = ? AND product_id = ?', [quantity, cartId, product_id]);
        }
        res.status(200).json({ success: true });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
};

/**
 * Completely removes a specific product from the user's cart.
 * * @async
 * @function removeFromCart
 * @param {import('express').Request} req - Express request object.
 * @param {Object} req.body - Request body.
 * @param {string|number} req.body.product_id - The unique identifier of the product to remove.
 * @param {import('express').Response} res - Express response object.
 * @returns {Promise<void>} JSON response indicating success.
 */
const removeFromCart = async (req, res) => {
    try {
        const uid = req.user.uid;
        const { product_id } = req.body;
        
        const [user] = await db.execute('SELECT id FROM users WHERE firebase_uid = ?', [uid]);
        const cartId = await getOrCreateCartId(user[0].id);

        await db.execute('DELETE FROM cart_items WHERE cart_id = ? AND product_id = ?', [cartId, product_id]);
        res.status(200).json({ success: true });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
};

module.exports = { getCart, addToCart, updateQuantity, removeFromCart };