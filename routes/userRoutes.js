/**
 * @module routes/userRoutes
 * @description Defines the API endpoints for managing user profiles and delivery addresses.
 * All routes in this module require authentication via a valid Firebase ID token.
 */

const express = require("express");
const router = express.Router();

const { 
    getProfile, 
    updateProfile, 
    saveAddress, 
    getAddresses, 
    setDefaultAddress 
} = require("../controllers/userController"); 
const verifyFirebaseToken = require("../middleware/firebaseAuth");

// ==========================================
// Profile Management Routes
// ==========================================

/**
 * @route GET /profile
 * @description Retrieves the authenticated user's profile information along with their default delivery address.
 * @access Protected
 * @middleware verifyFirebaseToken
 */
router.get("/profile", verifyFirebaseToken, getProfile);

/**
 * @route PUT /update
 * @description Updates the basic profile information (name, email, city, avatar) of the authenticated user.
 * @access Protected
 * @middleware verifyFirebaseToken
 */
router.put("/update", verifyFirebaseToken, updateProfile);

// ==========================================
// Address Management Routes
// ==========================================

/**
 * @route POST /address
 * @description Adds a new delivery address for the authenticated user. Can optionally set it as the default address.
 * @access Protected
 * @middleware verifyFirebaseToken
 */
router.post("/address", verifyFirebaseToken, saveAddress);

/**
 * @route GET /addresses
 * @description Retrieves a list of all saved delivery addresses for the authenticated user, sorted with the default address first.
 * @access Protected
 * @middleware verifyFirebaseToken
 */
router.get("/addresses", verifyFirebaseToken, getAddresses);

/**
 * @route PUT /address/default
 * @description Updates the user's default delivery address to the specified address ID, removing the default status from all others.
 * @access Protected
 * @middleware verifyFirebaseToken
 */
router.put("/address/default", verifyFirebaseToken, setDefaultAddress);

module.exports = router;