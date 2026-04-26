# Accesco Living - User Backend

This is the Node.js/Express backend dedicated to the **User/Customer App** for Accesco Living. It handles user authentication, profile management, cart sessions, order processing, and dynamic module routing (Grokly, Swadisht, InstaStyle, Dinex).

## Tech Stack
* **Runtime:** Node.js
* **Framework:** Express.js
* **Database:** MySQL
* **Authentication:** Firebase Auth (JWT verification)

## Core Features
* **Smart Order Processing:** Automatically detects app modules based on cart contents to route orders and trigger specific UI themes.
* **Context-Aware Notifications:** Sends tailored push-style notifications directly to the user's inbox, dynamically tagged by module.
* **Dinex Bookings:** Handles table reservations and status tracking.

## Setup Instructions
1. Run `npm install` to install dependencies.
2.Create database in your device using config/database.txt file.
3. Configure your `.env` file with your MySQL credentials and Port.
4. Ensure your Firebase Admin SDK key is in the `config/` directory.
5. Run `node server.js` to start the server.