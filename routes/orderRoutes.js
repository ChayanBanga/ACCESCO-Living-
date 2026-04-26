/**
 * @module routes/orderRoutes
 * @description Defines the API endpoints for order management, including creation, listing, and retrieving details.
 * All routes in this module require authentication via a valid Firebase ID token.
 */

const express = require("express");
const router = express.Router();
const verifyFirebaseToken = require("../middleware/firebaseAuth");

const { createOrder, getOrders, getOrderDetails } = require("../controllers/orderController");

/**
 * @route POST /create
 * @description Processes a user's active cart to create a new order, calculates totals, clears the cart, and triggers a confirmation notification.
 * @access Protected
 * @middleware verifyFirebaseToken
 */
router.post("/create", verifyFirebaseToken, createOrder); 

/**
 * @route GET /
 * @description Retrieves a list of all past orders for the currently authenticated user, sorted by most recent first.
 * @access Protected
 * @middleware verifyFirebaseToken
 */
router.get("/", verifyFirebaseToken, getOrders);

/**
 * @route GET /:id
 * @description Retrieves the complete details and itemized list for a specific order by its ID.
 * @access Protected
 * @param {string|number} id - The unique identifier of the order passed as a URL parameter.
 * @middleware verifyFirebaseToken
 */
router.get("/:id", verifyFirebaseToken, getOrderDetails);

module.exports = router;