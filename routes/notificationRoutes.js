/**
 * @module routes/notificationRoutes
 * @description Defines the API endpoints for fetching user notifications.
 * All routes in this module require authentication via a valid Firebase ID token.
 */

const express = require("express");
const router = express.Router();
const verifyFirebaseToken = require("../middleware/firebaseAuth");
const { getNotifications } = require("../controllers/notificationController");

/**
 * @route GET /
 * @description Retrieves all notifications for the currently authenticated user, sorted by newest first.
 * @access Protected
 * @middleware verifyFirebaseToken
 */
router.get("/", verifyFirebaseToken, getNotifications);

module.exports = router;