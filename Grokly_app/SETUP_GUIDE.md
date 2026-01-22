# Quick Commerce Platform - Setup Guide

## Project Overview

Grokly is a complete quick commerce platform built with Flutter. It allows users to browse products, manage shopping carts, and complete orders quickly with a focus on speed and user experience.

## Architecture Overview

### State Management Pattern
The app uses **Provider** for state management with clean separation of concerns:

```
Screens (UI)
    ↓
Providers (State Management)
    ↓
Services (Business Logic)
```

### Key Components

#### Models
- `Product`: Represents a product with pricing, ratings, and stock info
- `CartItem`: Represents an item in the shopping cart
- `User`: Represents authenticated user data
- `Order`: Represents a completed order with status tracking

#### Services
- `ProductService`: Handles product data (currently uses mock data)
- `CartService`: Manages cart operations with local storage
- `AuthService`: Handles user authentication (currently mock)

#### Providers
- `ProductProvider`: Manages product state and filtering
- `CartProvider`: Manages cart state and operations
- `AuthProvider`: Manages authentication and user state

## Running the Application

### Prerequisites
```bash
# Check Flutter and Dart versions
flutter --version
dart --version

# Should be Flutter 3.10.7+ and Dart 3.10.7+
```

### Setup Steps

1. **Navigate to project**
   ```bash
   cd c:\Users\chhet\OneDrive\Desktop\app\grokly_app
   ```

2. **Get dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

   For specific device:
   ```bash
   flutter run -d <device_id>
   ```

### Testing on Different Platforms

#### Android
```bash
flutter run -d emulator-5554
```

#### iOS
```bash
flutter run -d iphone
```

#### Web
```bash
flutter run -d chrome
```

#### Windows
```bash
flutter run -d windows
```

## User Flow

### New User Flow
```
1. Launch App → Login Screen
2. Click "Don't have account?" → Signup Screen
3. Enter details and create account → Home Screen
4. Browse products → Add to cart
5. Click cart → Cart Screen
6. Review items → Checkout
7. Enter address → Order Confirmation
8. Order confirmed → Continue Shopping
```

### Existing User Flow
```
1. Launch App → Login Screen
2. Enter credentials → Home Screen
3. Browse/Search products → Select product
4. View details → Add to cart
5. Continue shopping or checkout
6. Complete order
```

## Mock Data & Testing

### Pre-loaded Products
The app comes with 6 products across different categories:

| Product | Category | Price | Discount |
|---------|----------|-------|----------|
| Fresh Apples | Fruits | ₹150 | ₹30 |
| Organic Milk | Dairy | ₹80 | ₹10 |
| Whole Wheat Bread | Bakery | ₹60 | ₹10 |
| Tomatoes (1kg) | Vegetables | ₹40 | ₹5 |
| Greek Yogurt | Dairy | ₹120 | ₹20 |
| Bananas Bundle | Fruits | ₹50 | ₹10 |

### Testing Login
- Email: `test@example.com` (or any email)
- Password: `password123` (or any password)
- Note: Currently uses mock authentication

## Key Features

### 1. Authentication
- Sign up with name, email, password
- Login with credentials
- Profile management

### 2. Product Discovery
- Browse all products
- Search by name/description/tags
- Filter by category
- View detailed product information
- See ratings and reviews

### 3. Shopping Cart
- Add/remove items
- Adjust quantities
- Local persistence
- Real-time total calculation

### 4. Checkout
- Enter delivery address
- Confirm phone number
- Review order summary
- Select payment method
- Get order confirmation

### 5. Order Management
- Instant order confirmation
- Order ID tracking
- Delivery status (mock)

## Pricing Logic

### Discount Calculation
```dart
discount = originalPrice - discountedPrice
discountPercentage = (discount / originalPrice) * 100
```

### Delivery Fees
- Orders ≥ ₹500: FREE
- Orders < ₹500: ₹50

### Order Total
```
total = subtotal + deliveryFee
```

## Routes & Navigation

| Route | Screen | Purpose |
|-------|--------|---------|
| `/login` | LoginScreen | User authentication |
| `/signup` | SignupScreen | New user registration |
| `/home` | HomeScreen | Product listing |
| `/product-detail` | ProductDetailScreen | Product details |
| `/cart` | CartScreen | Shopping cart review |
| `/checkout` | CheckoutScreen | Order placement |
| `/order-confirmation` | OrderConfirmationScreen | Order confirmation |

## Storage

### Local Storage (SharedPreferences)
- `current_user`: Currently logged-in user data
- `cart_items`: Shopping cart items

### In-Memory Storage (Providers)
- Product list and filtered results
- Cart items and totals
- User authentication state

## Code Examples

### Adding to Cart
```dart
final cartProvider = context.read<CartProvider>();
await cartProvider.addToCart(product, quantity);
```

### Searching Products
```dart
final productProvider = context.read<ProductProvider>();
await productProvider.searchProducts("apples");
```

### Getting Cart Total
```dart
final total = cartProvider.total;
final subtotal = cartProvider.subtotal;
```

## Performance Considerations

1. **Image Caching**: Using CachedNetworkImage for efficient loading
2. **Lazy Loading**: Products loaded only when needed
3. **State Isolation**: Separate providers for cart, products, and auth
4. **Local Storage**: Fast access to cart data via SharedPreferences

## Troubleshooting

### Build Issues
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter run
```

### Hot Reload Not Working
```bash
# Use hot restart instead
# Press 'R' in terminal or use:
flutter run -R
```

### Dependencies Not Found
```bash
flutter pub upgrade
flutter pub get
```

## Next Steps for Backend Integration

1. Replace `mock` implementations in services with real API calls
2. Update `ProductService` to fetch from backend API
3. Implement real authentication in `AuthService`
4. Integrate payment gateway
5. Add order tracking API
6. Implement push notifications

## Development Tips

1. Use `flutter analyze` to check code quality
2. Run `flutter format` to format code
3. Use `flutter test` to run unit tests
4. Monitor performance with DevTools: `flutter pub global run devtools`

## Environment Setup Notes

- Target SDK: Android 34+, iOS 14.0+
- Material 3 enabled for modern UI
- GoRouter for type-safe navigation
- Provider for state management

---

For more information, see [COMMERCE_README.md](COMMERCE_README.md)
