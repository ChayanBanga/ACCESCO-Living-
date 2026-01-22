#!/bin/bash

# Grokly Quick Commerce Platform - Setup Script
# This script sets up and runs the Flutter quick commerce application

echo "======================================"
echo "  Grokly - Quick Commerce Platform"
echo "  Setup & Launch Script"
echo "======================================"
echo ""

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is not installed. Please install Flutter first."
    echo "   Visit: https://flutter.dev/docs/get-started/install"
    exit 1
fi

# Check Flutter version
echo "✓ Checking Flutter installation..."
flutter --version
echo ""

# Navigate to project directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR" || exit 1
echo "✓ Project directory: $SCRIPT_DIR"
echo ""

# Clean previous builds
echo "🧹 Cleaning previous build..."
flutter clean
echo "✓ Clean complete"
echo ""

# Get dependencies
echo "📦 Installing dependencies..."
flutter pub get
echo "✓ Dependencies installed"
echo ""

# Check for available devices
echo "📱 Checking available devices..."
devices=$(flutter devices)
echo "$devices"
echo ""

# Run the app
echo "🚀 Launching Grokly Quick Commerce Platform..."
echo ""
flutter run

# Show instructions
echo ""
echo "======================================"
echo "  Launch Complete!"
echo "======================================"
echo ""
echo "Testing Credentials:"
echo "  Email: test@example.com (or any email)"
echo "  Password: password123 (or any password)"
echo ""
echo "Features to Test:"
echo "  1. Sign up a new account"
echo "  2. Browse products"
echo "  3. Search/filter by category"
echo "  4. Add items to cart"
echo "  5. Complete checkout"
echo "  6. Confirm order"
echo ""
echo "Documentation:"
echo "  - IMPLEMENTATION_SUMMARY.md"
echo "  - COMMERCE_README.md"
echo "  - SETUP_GUIDE.md"
echo "  - DEVELOPMENT_CHECKLIST.md"
echo ""
echo "======================================"
