# Grokly - Quick Commerce Platform

A fast and efficient quick commerce app built with Flutter that enables users to browse products, manage carts, and complete orders with minimal friction.

## Features

### User Authentication
- **User Registration**: Create a new account with name, email, and password
- **User Login**: Secure login with existing credentials
- **Profile Management**: Update user information and addresses

### Product Browsing
- **Product Catalog**: Browse all available products with detailed information
- **Product Search**: Search products by name, description, or tags
- **Category Filtering**: Filter products by categories (Fruits, Dairy, Bakery, Vegetables, etc.)
- **Product Details**: View detailed product information including:
  - High-quality product images
  - Pricing with discount information
  - Product ratings and reviews
  - Stock availability
  - Complete product description

### Shopping Cart
- **Add to Cart**: Quickly add products to your shopping cart
- **Quantity Management**: Adjust product quantities in the cart
- **Remove Items**: Remove unwanted items from the cart
- **Cart Persistence**: Cart data is saved locally using SharedPreferences
- **Real-time Cart Updates**: Cart badge shows current item count

### Pricing & Discounts
- **Dynamic Pricing**: Clear display of original and discounted prices
- **Discount Calculation**: Automatic calculation of discount percentages
- **Subtotal & Total**: Real-time calculation of order totals
- **Free Delivery**: Automatic free delivery for orders above ₹500

### Checkout
- **Delivery Address**: Enter or select delivery address
- **Contact Information**: Add phone number for order updates
- **Order Summary**: Review all items before placing order
- **Payment Methods**: Cash on Delivery (COD) support
- **Order Confirmation**: Receive order confirmation with order ID and total amount

### Order Management
- **Quick Order Placement**: 30-minute delivery promise
- **Order Tracking**: Monitor order status
- **Order History**: View past orders

## Project Structure

```
lib/
├── main.dart                          # App entry point
├── config/
│   ├── app_router.dart               # Navigation configuration
│   └── app_theme.dart                # Theme settings
├── models/
│   ├── product.dart                  # Product model
│   ├── cart_item.dart                # Cart item model
│   ├── order.dart                    # Order model
│   └── user.dart                     # User model
├── services/
│   ├── product_service.dart          # Product API service
│   ├── cart_service.dart             # Cart management service
│   └── auth_service.dart             # Authentication service
├── providers/
│   ├── product_provider.dart         # Product state management
│   ├── cart_provider.dart            # Cart state management
│   └── auth_provider.dart            # Authentication state management
├── screens/
│   ├── auth/
│   │   ├── login_screen.dart         # Login page
│   │   └── signup_screen.dart        # Registration page
│   ├── home/
│   │   ├── home_screen.dart          # Product listing page
│   │   └── product_detail_screen.dart # Product details page
│   ├── cart/
│   │   └── cart_screen.dart          # Shopping cart page
│   └── checkout/
│       ├── checkout_screen.dart      # Checkout page
│       └── order_confirmation_screen.dart # Order confirmation page
└── widgets/
    ├── common_widgets.dart           # Shared widgets
    └── product_card.dart             # Product card component
```

## Key Technologies

### State Management
- **Provider**: Lightweight state management for managing user, product, and cart states

### Networking & Storage
- **HTTP**: API communication (ready for backend integration)
- **SharedPreferences**: Local data persistence for cart and user data

### UI & Navigation
- **GoRouter**: Type-safe routing and navigation
- **CachedNetworkImage**: Efficient image loading and caching
- **Material 3**: Modern Material Design components

### Utilities
- **Intl**: Internationalization and number formatting
- **UUID**: Unique ID generation

## Getting Started

### Prerequisites
- Flutter SDK 3.10.7 or higher
- Dart SDK 3.10.7 or higher

### Installation

1. Clone the repository
2. Navigate to project directory: `cd grokly_app`
3. Install dependencies: `flutter pub get`
4. Run the app: `flutter run`

## Current Features (Phase 1)

✅ User Authentication (Mock)
✅ Product Browsing & Search
✅ Shopping Cart Management
✅ Order Checkout
✅ Order Confirmation
✅ Category Filtering
✅ Discount Display
✅ Local Data Persistence

## Future Enhancements (Phase 2)

- [ ] Real backend API integration
- [ ] Payment gateway integration
- [ ] Order tracking in real-time
- [ ] Push notifications
- [ ] Wishlist feature
- [ ] Multiple delivery addresses
- [ ] Order reviews and ratings
- [ ] Referral program
- [ ] Promotional codes/Coupons
- [ ] User wallet
- [ ] Saved payment methods
- [ ] Live chat support
- [ ] Multi-language support

## Mock Data

The app comes with mock data for demonstration:

### Products
- Fresh Apples (Fruits)
- Organic Milk (Dairy)
- Whole Wheat Bread (Bakery)
- Tomatoes (Vegetables)
- Greek Yogurt (Dairy)
- Bananas Bundle (Fruits)

### Mock User Account
- Email: Use any email to login
- Password: Any password works (mock authentication)

## Delivery Policy

- **Standard Delivery**: 30 minutes for orders within service area
- **Free Delivery**: For orders above ₹500
- **Delivery Fee**: ₹50 for orders below ₹500

## Contact & Support

For issues, feature requests, or suggestions, please contact the development team.

## License

This project is proprietary and confidential.
