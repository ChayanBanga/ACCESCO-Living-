/**
 * @module controllers/notificationController
 * @description Handles the retrieval of user-specific notifications.
 */

const db = require('../config/db');

/**
 * Fetches all notifications for the authenticated user, sorted by creation date in descending order (newest first).
 * * @async
 * @function getNotifications
 * @param {import('express').Request} req - Express request object.
 * @param {Object} req.user - Decoded Firebase user object injected by authentication middleware.
 * @param {string} req.user.uid - The unique Firebase User ID used to query the user's notifications.
 * @param {import('express').Response} res - Express response object.
 * @returns {Promise<void>} JSON response containing an array of notifications on success (200), or an error message on failure (500).
 */
const getNotifications = async (req, res) => {
    try {
        // Fetch notifications for this specific user, newest first
        const [notifications] = await db.execute(
            'SELECT * FROM notifications WHERE user_id = ? ORDER BY created_at DESC',
            [req.user.uid]
        );
        res.status(200).json({ success: true, data: notifications });
    } catch (error) {
        console.error("Fetch Notifications Error:", error);
        res.status(500).json({ success: false, message: error.message });
    }
};

module.exports = { getNotifications };