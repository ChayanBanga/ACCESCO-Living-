/**
 * @module routes/dinexRoutes
 * @description Defines API endpoints for DineX restaurant reservations.
 * All routes require authentication via a valid Firebase ID token.
 */

const express = require('express');
const router = express.Router();
const { bookTable, getUserBookings } = require('../controllers/dinexController');
const verifyToken = require('../middleware/firebaseAuth'); 

/**
 * @route POST /book
 * @description Submits a new restaurant table reservation for the authenticated user.
 * @access Protected
 * @middleware verifyToken
 */
router.post('/book', verifyToken, bookTable);

/**
 * @route GET /bookings
 * @description Retrieves the booking history (past and upcoming reservations) for the authenticated user.
 * @access Protected
 * @middleware verifyToken
 */
router.get('/bookings', verifyToken, getUserBookings);

module.exports = router;