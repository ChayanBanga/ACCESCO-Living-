/**
 * @module routes/search
 * @description Provides a search endpoint to filter available items based on a text query.
 */

const express = require("express");
const router = express.Router();
const items = require("../config/data");

/**
 * @route GET /
 * @description Performs a case-insensitive search across items using the provided query string.
 * @access Public
 * @param {import('express').Request} req - Express request object.
 * @param {Object} req.query - URL query parameters.
 * @param {string} [req.query.q] - The search term to filter item names.
 * @param {import('express').Response} res - Express response object.
 * @returns {void} JSON response containing an array of matched items, or an empty array if no query is provided.
 */
router.get("/", (req, res) => {
  const query = req.query.q?.toLowerCase();

  if (!query) {
    return res.json([]);
  }

  const results = items.filter(item =>
    item.name.toLowerCase().includes(query)
  );

  res.json(results);
});

module.exports = router;