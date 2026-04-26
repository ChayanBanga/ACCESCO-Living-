/**
 * @module controllers/userController
 * @description Handles user profile management, including fetching/updating personal details and managing delivery addresses.
 */

const db = require("../config/db");

/**
 * Retrieves the authenticated user's profile data, joined with their default delivery address.
 * Uses a LEFT JOIN to ensure profile data is returned even if no default address exists.
 * * @async
 * @function getProfile
 * @param {import('express').Request} req - Express request object.
 * @param {Object} req.user - Decoded Firebase user object.
 * @param {string} req.user.uid - The unique Firebase User ID.
 * @param {import('express').Response} res - Express response object.
 * @returns {Promise<void>} JSON response containing the user profile and default address details.
 */
const getProfile = async (req, res) => {
    try {
        const uid = req.user.uid; 

        // We use LEFT JOIN to get the default address from the addresses table
        // if it exists, otherwise those fields will be NULL
        const query = `
            SELECT 
                u.id, u.full_name, u.email, u.phone, u.role, u.profile_image, u.city, u.created_at,
                a.full_address, a.pincode, a.state as addr_state
            FROM users u
            LEFT JOIN addresses a ON u.id = a.user_id AND a.is_default = TRUE
            WHERE u.firebase_uid = ?
        `;

        const [rows] = await db.execute(query, [uid]);

        if (rows.length === 0) {
            return res.status(404).json({ success: false, message: "User not found in database" });
        }

        res.status(200).json({
            success: true,
            user: rows[0]
        });
    } catch (error) {
        console.error("❌ Get Profile Error:", error.message);
        res.status(500).json({ success: false, message: "Internal Server Error" });
    }
};

/**
 * Updates the basic profile information of the authenticated user.
 * * @async
 * @function updateProfile
 * @param {import('express').Request} req - Express request object.
 * @param {Object} req.body - Profile details to update.
 * @param {string} req.body.full_name - The user's updated full name.
 * @param {string} req.body.email - The user's updated email address.
 * @param {string} req.body.city - The user's updated city.
 * @param {string} req.body.profile_image - URL to the user's updated profile image.
 * @param {import('express').Response} res - Express response object.
 * @returns {Promise<void>} JSON response indicating successful update.
 */
const updateProfile = async (req, res) => {
    try {
        const uid = req.user.uid;
        const { full_name, email, city, profile_image } = req.body;

        await db.execute(
            'UPDATE users SET full_name = ?, email = ?, city = ?, profile_image = ? WHERE firebase_uid = ?',
            [full_name, email, city, profile_image, uid]
        );

        res.status(200).json({ 
            success: true, 
            message: "Profile updated successfully" 
        });
    } catch (error) {
        console.error("❌ Update Profile Error:", error.message);
        res.status(500).json({ success: false, message: error.message });
    }
};

/**
 * Saves a new delivery address for the user. If marked as default, removes the default status from existing addresses.
 * * @async
 * @function saveAddress
 * @param {import('express').Request} req - Express request object.
 * @param {Object} req.body - Address details.
 * @param {string} req.body.full_address - The complete street address.
 * @param {string} req.body.city - The city.
 * @param {string} req.body.state - The state.
 * @param {string} req.body.pincode - The postal code.
 * @param {boolean} [req.body.is_default=true] - Whether this address should be set as the primary/default.
 * @param {string} [req.body.address_label='Home'] - A label for the address (e.g., 'Home', 'Work').
 * @param {import('express').Response} res - Express response object.
 * @returns {Promise<void>} JSON response indicating successful save.
 */
const saveAddress = async (req, res) => {
    try {
        const uid = req.user.uid;
        const { full_address, city, state, pincode, is_default, address_label } = req.body;

        const [user] = await db.execute('SELECT id FROM users WHERE firebase_uid = ?', [uid]);
        if (user.length === 0) return res.status(404).json({ message: "User not found" });
        const userId = user[0].id;

        if (is_default) {
            await db.execute('UPDATE addresses SET is_default = FALSE WHERE user_id = ?', [userId]);
        }

        // Insert including the address_label
        await db.execute(
            'INSERT INTO addresses (user_id, full_address, city, state, pincode, is_default, address_label) VALUES (?, ?, ?, ?, ?, ?, ?)',
            [userId, full_address, city, state, pincode, is_default !== undefined ? is_default : true, address_label || 'Home']
        );

        res.status(200).json({ success: true, message: "Address saved successfully" });
    } catch (error) {
        console.error("❌ Save Address Error:", error.message);
        res.status(500).json({ success: false, message: error.message });
    }
};

/**
 * Retrieves all saved addresses for the authenticated user, ordered with the default address first.
 * * @async
 * @function getAddresses
 * @param {import('express').Request} req - Express request object.
 * @param {import('express').Response} res - Express response object.
 * @returns {Promise<void>} JSON response containing an array of addresses.
 */
const getAddresses = async (req, res) => {
    try {
        const uid = req.user.uid;
        
        const [user] = await db.execute('SELECT id FROM users WHERE firebase_uid = ?', [uid]);
        if (user.length === 0) return res.status(404).json({ message: "User not found" });
        const userId = user[0].id;

        // Fetch all addresses, default ones first
        const [addresses] = await db.execute(
            'SELECT * FROM addresses WHERE user_id = ? ORDER BY is_default DESC', 
            [userId]
        );

        res.status(200).json({ success: true, addresses });
    } catch (error) {
        console.error("❌ Get Addresses Error:", error.message);
        res.status(500).json({ success: false, message: error.message });
    }
};

/**
 * Changes the user's default delivery address to the specified address ID.
 * * @async
 * @function setDefaultAddress
 * @param {import('express').Request} req - Express request object.
 * @param {Object} req.body - Request payload.
 * @param {number|string} req.body.addressId - The ID of the address to set as default.
 * @param {import('express').Response} res - Express response object.
 * @returns {Promise<void>} JSON response indicating success.
 */
const setDefaultAddress = async (req, res) => {
    try {
        const uid = req.user.uid;
        const { addressId } = req.body;

        const [user] = await db.execute('SELECT id FROM users WHERE firebase_uid = ?', [uid]);
        if (user.length === 0) return res.status(404).json({ message: "User not found" });
        const userId = user[0].id;

        // 1. Remove 'default' status from ALL addresses for this user
        await db.execute('UPDATE addresses SET is_default = FALSE WHERE user_id = ?', [userId]);

        // 2. Set the newly selected address as default
        await db.execute('UPDATE addresses SET is_default = TRUE WHERE id = ? AND user_id = ?', [addressId, userId]);

        res.status(200).json({ success: true, message: "Default address updated" });
    } catch (error) {
        console.error("❌ Set Default Address Error:", error.message);
        res.status(500).json({ success: false, message: error.message });
    }
};

module.exports = { getProfile, updateProfile, saveAddress, getAddresses, setDefaultAddress };