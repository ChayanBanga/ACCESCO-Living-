# Grokly Platform - Quick Reference Guide

## 🚀 Quick Start (60 seconds)

### On Windows
```bash
cd c:\Users\chhet\OneDrive\Desktop\app\grokly_app
setup.bat
```

### On macOS/Linux
```bash
cd ~/Desktop/app/grokly_app
bash setup.sh
```

### Manual Start
```bash
flutter clean
flutter pub get
flutter run
```

---

## 🔐 Demo Credentials

- **Email**: Any email (e.g., `test@example.com`)
- **Password**: Any password (e.g., `password123`)
- **Note**: Authentication is mocked for testing

---

## 📱 App Flow

```
START
  ↓
SIGNUP/LOGIN
  ↓
HOME SCREEN (Product Listing)
  ├→ Click Search → Search Products
  ├→ Click Category Filter → Filter by Category
  ├→ Click Product → Product Details
  │   └→ Add to Cart
  └→ Click Cart Icon → Shopping Cart
      ├→ Edit Quantities
      ├→ Remove Items
      └→ Checkout
          ├→ Enter Address
          ├→ Enter Phone
          └→ Place Order
              ↓
          ORDER CONFIRMATION
```

---

## 🛒 Shopping Cart Features

| Feature | How to Use |
|---------|-----------|
| Add to Cart | Tap "Add to Cart" on product card or details page |
| View Cart | Tap cart icon (top right) with item count badge |
| Adjust Quantity | Use +/- buttons in cart |
| Remove Item | Tap trash icon in cart item |
| Free Delivery | Automatic when cart total > ₹500 |

---

## 🔍 Search & Filter

### Search Products
1. Tap search bar at top of home screen
2. Type product name, description, or tag
3. Results update in real-time

### Filter by Category
1. Scroll through category chips at top
2. Select: All, Fruits, Dairy, Bakery, Vegetables
3. Products automatically filtered

---

## 💰 Pricing Information

### Available Products
```
Fresh Apples (Fruits)
  Original: ₹150 → Discounted: ₹120 (20% OFF)

Organic Milk (Dairy)
  Original: ₹80 → Discounted: ₹70 (12% OFF)

Whole Wheat Bread (Bakery)
  Original: ₹60 → Discounted: ₹50 (16% OFF)

Tomatoes (Vegetables)
  Original: ₹40 → Discounted: ₹35 (12% OFF)

Greek Yogurt (Dairy)
  Original: ₹120 → Discounted: ₹100 (16% OFF)

Bananas Bundle (Fruits)
  Original: ₹50 → Discounted: ₹40 (20% OFF)
```

### Delivery Charges
- Order Total < ₹500: ₹50 Delivery Fee
- Order Total ≥ ₹500: FREE Delivery
- Estimated Delivery: 30 minutes

---

## 📋 File Structure Reference

```
lib/
├── main.dart                          App entry point
├── config/
│   ├── app_router.dart               Navigation routes
│   └── app_theme.dart                Theme configuration
├── models/                           Data models
├── services/                         Business logic
├── providers/                        State management
├── screens/                          UI screens
└── widgets/                          Reusable components
```

---

## 🔧 Common Tasks

### Run on Specific Device
```bash
# List devices
flutter devices

# Run on specific device
flutter run -d <device_id>
```

### Run on Android Emulator
```bash
flutter run -d emulator-5554
```

### Run on iOS Simulator
```bash
flutter run -d iphone
```

### Run on Chrome (Web)
```bash
flutter run -d chrome
```

### Debug Mode
```bash
flutter run --debug
```

### Release Mode
```bash
flutter run --release
```

---

## 📊 State Management

### Providers Used
```dart
AuthProvider          → User authentication state
ProductProvider       → Products, search, filter
CartProvider         → Cart items, totals
```

### Accessing Providers
```dart
// Read-only
context.read<CartProvider>().cartItems

// Listen to changes
context.watch<CartProvider>().total

// Multiple providers
Consumer2<CartProvider, ProductProvider>(...)
```

---

## 💾 Data Persistence

### Stored Locally
- User login session (SharedPreferences)
- Shopping cart items (SharedPreferences)
- User profile data (SharedPreferences)

### No Internet Required
✅ All core features work offline
✅ Data syncs when backend is ready

---

## 🎨 UI Components

### Screens
- `LoginScreen` - User authentication
- `SignupScreen` - New user registration
- `HomeScreen` - Product listing with search/filter
- `ProductDetailScreen` - Product information
- `CartScreen` - Shopping cart
- `CheckoutScreen` - Order placement
- `OrderConfirmationScreen` - Order confirmation

### Widgets
- `ProductCard` - Individual product display
- `LoadingWidget` - Loading indicator
- `ErrorWidget` - Error message display
- `EmptyWidget` - No items state
- `SearchBar` - Product search input

---

## 🐛 Troubleshooting

### App Won't Start
```bash
# Try clean rebuild
flutter clean
flutter pub get
flutter run
```

### Hot Reload Not Working
```bash
# Press 'R' in terminal for hot restart
# Or kill and restart flutter run
```

### Can't Log In
- Use any email and password (it's mocked)
- Make sure to fill all fields

### Cart Not Saving
- Restart the app
- Cart is saved in SharedPreferences
- Will persist between app launches

### Images Not Loading
- Check internet connection for placeholder image
- Images are cached after first load

---

## 📈 Performance Tips

1. **Minimize Widgets**: Provider Consumer pattern reduces rebuilds
2. **Image Caching**: CachedNetworkImage handles optimization
3. **Lazy Loading**: Products load on demand
4. **Local Storage**: Fast data access via SharedPreferences

---

## 🔗 Dependencies Overview

| Package | Purpose | Version |
|---------|---------|---------|
| provider | State management | 6.1.0 |
| go_router | Navigation | 13.0.0 |
| http | API calls | 1.1.0 |
| shared_preferences | Local storage | 2.2.0 |
| cached_network_image | Image caching | 3.3.0 |
| intl | Formatting | 0.19.0 |
| uuid | ID generation | 4.0.0 |

---

## ✅ Testing Checklist

### Basic Flow
- [ ] Sign up with new account
- [ ] Log in with credentials
- [ ] View all products
- [ ] Search for a product
- [ ] Filter by category
- [ ] View product details
- [ ] Add item to cart
- [ ] View shopping cart
- [ ] Adjust quantity
- [ ] Remove item
- [ ] Proceed to checkout
- [ ] Enter address
- [ ] Enter phone number
- [ ] Confirm order
- [ ] See confirmation screen

### Edge Cases
- [ ] Empty cart checkout
- [ ] Search with no results
- [ ] Out of stock items
- [ ] Large quantity additions
- [ ] Cart persistence after restart

---

## 🎯 Key Numbers

- **Products**: 6 demo items
- **Categories**: 4 (Fruits, Dairy, Bakery, Vegetables)
- **Routes**: 7 screens
- **Models**: 4 data classes
- **Services**: 3 business logic services
- **Providers**: 3 state managers
- **Widgets**: 15+ reusable components

---

## 📞 Need Help?

### Documentation
1. `IMPLEMENTATION_SUMMARY.md` - Complete overview
2. `COMMERCE_README.md` - Feature documentation
3. `SETUP_GUIDE.md` - Detailed setup instructions
4. `DEVELOPMENT_CHECKLIST.md` - Testing checklist

### Code Examples
All service implementations are well-commented and can serve as references.

---

**Version**: 1.0.0 (MVP)
**Status**: ✅ Ready for Testing & Development
**Last Updated**: January 22, 2026
