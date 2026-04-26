/**
 * @module controllers/authController
 * @description Handles authentication-related logic, integrating Firebase Auth with the local MySQL database.
 */

const db = require("../config/db");

/**
 * Authenticates a user via Firebase token, creating a new account if one does not exist,
 * or updating and returning the existing user profile.
 * * @async
 * @function firebaseLogin
 * @param {import('express').Request} req - Express request object.
 * @param {Object} req.body - The request body containing optional user details.
 * @param {string} [req.body.name] - The user's full name (provided from Flutter UI).
 * @param {string} [req.body.email] - The user's email address (provided from Flutter UI).
 * @param {Object} req.user - The decoded Firebase user object injected by authentication middleware.
 * @param {string} req.user.uid - The unique Firebase User ID.
 * @param {string} [req.user.phone_number] - The user's phone number extracted from Firebase.
 * @param {import('express').Response} res - Express response object.
 * @returns {Promise<void>} Sends a JSON response with status 200 (Login) or 201 (Sign-Up) containing user data.
 * @throws {Error} 500 - Internal Server Error if a database transaction fails.
 */
const firebaseLogin = async (req, res) => {
    console.log("-----------------------------------------");
    console.log("🚀 Auth Request: Check, Create, or Update User");

    try {
        // Extract data provided by the client (Flutter UI)
        const { name, email } = req.body;
        
        // Extract authenticated data from the Firebase token (via middleware)
        const uid = req.user.uid;
        const phone = req.user.phone_number || "";

        // 1. SEARCH: Check if the user already exists in the database
        const [rows] = await db.execute(
            'SELECT * FROM users WHERE firebase_uid = ?', 
            [uid]
        );

        if (rows.length > 0) {
            // LOGIN & UPDATE LOGIC
            const user = rows[0];
            console.log(`✅ Result: Existing User Found - ${user.full_name}`);
            
            // Sync Name/Email if provided in the request but currently empty/null in the DB
            // Also updates the last_login timestamp
            await db.execute(
                `UPDATE users SET 
                 full_name = COALESCE(NULLIF(?, ''), full_name), 
                 email = COALESCE(NULLIF(?, ''), email), 
                 last_login = NOW() 
                 WHERE id = ?`, 
                [name, email, user.id]
            );

            // Fetch the freshly updated user record to return to the client
            const [updatedRows] = await db.execute('SELECT * FROM users WHERE id = ?', [user.id]);

            return res.status(200).json({
                success: true,
                isNewUser: false,
                message: "Login successful",
                user: updatedRows[0]
            });

        } else {
            // SIGNUP LOGIC
            console.log("🆕 Result: User not found. Executing Sign-Up...");

            const [result] = await db.execute(
                `INSERT INTO users (full_name, email, phone, firebase_uid, is_verified, role, is_active) 
                 VALUES (?, ?, ?, ?, ?, ?, ?)`,
                [
                    name || "Valued Customer", 
                    email || null, 
                    phone, 
                    uid, 
                    true,      
                    'customer', 
                    true       
                ]
            );

            console.log(`✨ Success: New record created with ID: ${result.insertId}`);

            return res.status(201).json({
                success: true,
                isNewUser: true,
                message: "Account created successfully",
                user: {
                    id: result.insertId,
                    full_name: name || "Valued Customer",
                    email: email || null,
                    phone: phone,
                    role: 'customer'
                }
            });
        }

    } catch (error) {
        console.error("❌ DATABASE ERROR:", error.message);
        return res.status(500).json({
            success: false,
            message: "Internal Server Error",
            error: error.message
        });
    }
};

module.exports = { firebaseLogin };