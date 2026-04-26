/**
 * @fileoverview Main entry point for the Accesco backend API.
 * Initializes the Express application, configures global middleware, 
 * mounts modular route handlers, and starts the HTTP server.
 * @module server
 */

const express = require("express");
const app = express();

// ==========================================
// Global Middleware
// ==========================================

/**
 * Built-in middleware function in Express.
 * Parses incoming requests with JSON payloads and is based on body-parser.
 */
app.use(express.json());

// ==========================================
// Route Imports & Mounting
// ==========================================

const searchRoutes = require("./routes/search");
const authRoutes = require("./routes/authRoutes");
const userRoutes = require("./routes/userRoutes");
const cartRoutes = require('./routes/cartRoutes');
const orderRoutes = require('./routes/orderRoutes');
const notificationRoutes = require("./routes/notificationRoutes");
const dinexRoutes = require('./routes/dinexRoutes');

/**
 * Mount API Routers
 * - /api/search: Item search functionality
 * - /api/auth: Firebase authentication and phone verification
 * - /api/user: Profile and delivery address management
 * - /api/cart: Shopping cart operations
 * - /api/orders: Order processing and history
 * - /api/notifications: User notification retrieval
 * - /api/dinex: Restaurant booking system operations
 */
app.use("/api/search", searchRoutes);
app.use("/api/auth", authRoutes);
app.use("/api/user", userRoutes);
app.use('/api/cart', cartRoutes);
app.use('/api/orders', orderRoutes);
app.use("/api/notifications", notificationRoutes);
app.use('/api/dinex', dinexRoutes);

// ==========================================
// Server Initialization
// ==========================================

const PORT = 5000;

/**
 * Starts the Express HTTP server.
 * Binds to "0.0.0.0" to accept connections from any IP on the local network,
 * allowing the Flutter app on physical devices to communicate with the backend.
 */
app.listen(PORT, "0.0.0.0", () => {
  console.log(`✅ Server running on http://192.168.1.7:${PORT}`);
  console.log(`🚀 Ready to receive requests from your phone!`);
});