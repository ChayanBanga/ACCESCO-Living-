/**
 * @module routes/cartRoutes
 * @description Defines the API endpoints for managing the user's shopping cart.
 * All routes in this module require authentication via a valid Firebase ID token.
 */

const express = require("express");
const router = express.Router();
const verifyFirebaseToken = require("../middleware/firebaseAuth");
const { getCart, addToCart, updateQuantity, removeFromCart } = require("../controllers/cartController");

/**
 * @route GET /
 * @description Retrieves the current user's shopping cart items and billing summary.
 * @access Protected
 * @middleware verifyFirebaseToken
 */
router.get("/", verifyFirebaseToken, getCart);

/**
 * @route POST /add
 * @description Adds a new product to the cart or increments its quantity if it already exists.
 * @access Protected
 * @middleware verifyFirebaseToken
 */
router.post("/add", verifyFirebaseToken, addToCart);

/**
 * @route PUT /update
 * @description Updates the quantity of a specific product currently in the cart.
 * @access Protected
 * @middleware verifyFirebaseToken
 */
router.put("/update", verifyFirebaseToken, updateQuantity);

/**
 * @route DELETE /remove
 * @description Completely removes a specific product from the user's cart.
 * @access Protected
 * @middleware verifyFirebaseToken
 */
router.delete("/remove", verifyFirebaseToken, removeFromCart);

module.exports = router;