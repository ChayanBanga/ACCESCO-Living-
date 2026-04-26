/**
 * @module middleware/firebaseAuth
 * @description Initializes Firebase Admin SDK and provides middleware for securing routes by verifying Firebase ID tokens.
 */

const admin = require("firebase-admin");

// 1. Import the service account key you just saved
const serviceAccount = require("../config/serviceAccountKey.json");

/**
 * Initializes the Firebase Admin SDK using the provided service account credentials.
 * Ensures the app is initialized only once to prevent errors during multiple imports.
 */
if (!admin.apps.length) {
  try {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
    console.log("✅ Firebase Admin initialized with serviceAccountKey.json");
  } catch (error) {
    console.error("❌ Firebase Admin initialization failed:", error.message);
  }
}

/**
 * Express middleware to authenticate requests via Firebase ID tokens.
 * Extracts the token from the "Authorization" header (expects "Bearer <token>"),
 * verifies it against Firebase, and attaches the decoded user payload to `req.user`.
 * * @async
 * @function verifyFirebaseToken
 * @param {import('express').Request} req - Express request object.
 * @param {Object} req.headers - Request headers.
 * @param {string} [req.headers.authorization] - The authorization header containing the Bearer token.
 * @param {import('express').Response} res - Express response object.
 * @param {import('express').NextFunction} next - Express next middleware function.
 * @returns {Promise<void>} Calls `next()` if the token is valid, otherwise sends a 401 JSON response.
 */
const verifyFirebaseToken = async (req, res, next) => {
  console.log("\n--- [MIDDLEWARE] Auth Check ---");
  
  const authHeader = req.headers.authorization;

  if (!authHeader) {
    console.log("❌ Result: No Authorization header found.");
    return res.status(401).json({
      success: false,
      message: "No token provided"
    });
  }

  // Handle "Bearer <token>" format sent by Flutter
  const token = authHeader.startsWith("Bearer ") 
    ? authHeader.split(" ")[1] 
    : authHeader;

  try {
    console.log("🔑 Verifying token with Firebase...");
    // This will now work because the cert(serviceAccount) matches the phone's project
    const decoded = await admin.auth().verifyIdToken(token);

    console.log(`✅ Success: Token verified. UID: ${decoded.uid}`);
    req.user = decoded; 
    next(); // Move to controllers/authController.js
  } catch (error) {
    console.error("❌ Result: Token Verification Failed");
    console.error(`👉 Message: ${error.message}`);
    
    return res.status(401).json({
      success: false,
      message: "Invalid or expired token",
      error: error.message
    });
  }
};

module.exports = verifyFirebaseToken;