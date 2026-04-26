/**
 * @module routes/authRoutes
 * @description Defines the authentication endpoints for the application, handling phone number verification and Firebase login.
 */

const express = require("express");
const router = express.Router();

const { firebaseLogin } = require("../controllers/authController");
const verifyFirebaseToken = require("../middleware/firebaseAuth");
const db = require("../config/db"); // Needed for the quick check

/**
 * @route POST /api/auth/check-phone
 * @description Checks if a given phone number already exists in the local MySQL database. 
 * Typically used by the client app to determine whether to prompt for registration details before triggering a Firebase OTP.
 * @access Public
 * @param {import('express').Request} req - Express request object.
 * @param {Object} req.body - The request payload.
 * @param {string} req.body.phone - The phone number to verify.
 * @param {import('express').Response} res - Express response object.
 * @returns {Promise<void>} JSON response indicating whether the user exists (`exists: true|false`).
 */
router.post("/check-phone", async (req, res) => {
    const { phone } = req.body;

    if (!phone) {
        return res.status(400).json({ success: false, message: "Phone number is required" });
    }

    try {
        const [rows] = await db.execute('SELECT id FROM users WHERE phone = ?', [phone]);
        
        if (rows.length > 0) {
            return res.json({ 
                success: true, 
                exists: true, 
                message: "User already exists" 
            });
        } else {
            return res.json({ 
                success: true, 
                exists: false, 
                message: "User does not exist" 
            });
        }
    } catch (error) {
        console.error("❌ Phone Check Error:", error.message);
        res.status(500).json({ 
            success: false, 
            message: "Database error", 
            error: error.message 
        });
    }
});

/**
 * @route POST /api/auth/login
 * @description Authenticates a user by verifying their Firebase ID token, then logs them in or creates a new account locally.
 * @access Protected (Requires Firebase Bearer Token)
 * @middleware verifyFirebaseToken - Extracts and validates the Firebase token from the Authorization header.
 * @controller firebaseLogin - Handles the database logic for syncing the Firebase user.
 */
router.post("/login", verifyFirebaseToken, firebaseLogin);

module.exports = router;