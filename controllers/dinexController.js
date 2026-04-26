/**
 * @module controllers/dinexController
 * @description Handles DineX restaurant table booking operations, including creating reservations and retrieving booking history.
 */

const db = require('../config/db');

/**
 * Creates a new restaurant table reservation for the authenticated user.
 * * @async
 * @function bookTable
 * @param {import('express').Request} req - Express request object.
 * @param {Object} req.body - The booking details sent from the client (Flutter app).
 * @param {string|number} req.body.restaurantId - Unique identifier of the restaurant.
 * @param {string} req.body.restaurantName - Name of the restaurant.
 * @param {number} req.body.guests - Number of guests for the reservation.
 * @param {string} req.body.date - Date of the booking (e.g., 'YYYY-MM-DD').
 * @param {string} req.body.time - Time of the booking (e.g., 'HH:MM').
 * @param {string} [req.body.imageUrl] - Optional URL of the restaurant's display image.
 * @param {Object} req.user - Decoded Firebase user object from authentication middleware.
 * @param {string} req.user.uid - The unique Firebase User ID.
 * @param {import('express').Response} res - Express response object.
 * @returns {Promise<void>} JSON response indicating success (201) with the insert ID, or an error (400/500).
 */
exports.bookTable = async (req, res) => {
    try {
        // 1. Get the secure User ID from your Firebase Auth Middleware
        const userId = req.user.uid; 

        // 2. Extract the data sent from the Flutter app
        const { restaurantId, restaurantName, guests, date, time, imageUrl } = req.body;

        // 3. Basic validation to ensure no empty bookings slip through
        if (!restaurantId || !restaurantName || !guests || !date || !time) {
            return res.status(400).json({ message: "Missing required booking details." });
        }

        // 4. The MySQL Insert Query
        const query = `
            INSERT INTO dinex_bookings 
            (user_id, restaurant_id, restaurant_name, guests, booking_date, booking_time, image_url) 
            VALUES (?, ?, ?, ?, ?, ?, ?)
        `;
        
        const values = [userId, restaurantId, restaurantName, guests, date, time, imageUrl];

        // 5. Execute the query
        const [result] = await db.execute(query, values);

        // 6. Send success response back to Flutter
        res.status(201).json({ 
            message: "Booking confirmed successfully!",
            bookingId: result.insertId
        });

    } catch (error) {
        console.error("DineX Booking Error:", error);
        res.status(500).json({ message: "Internal server error while saving booking." });
    }
};

/**
 * Retrieves all restaurant reservations for the currently authenticated user.
 * Results are sorted in descending order by booking date and time (newest first).
 * * @async
 * @function getUserBookings
 * @param {import('express').Request} req - Express request object containing the Firebase UID in `req.user`.
 * @param {import('express').Response} res - Express response object.
 * @returns {Promise<void>} JSON response containing an array of booking records (200) or an error (500).
 */
exports.getUserBookings = async (req, res) => {
    try {
        const userId = req.user.uid; 

        // Fetch bookings, newest first
        const query = `
            SELECT * FROM dinex_bookings 
            WHERE user_id = ? 
            ORDER BY booking_date DESC, booking_time DESC
        `;
        
        const [bookings] = await db.execute(query, [userId]);

        res.status(200).json({ bookings });
    } catch (error) {
        console.error("Fetch Bookings Error:", error);
        res.status(500).json({ message: "Internal server error while fetching bookings." });
    }
};