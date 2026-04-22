import 'package:flutter/foundation.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../models/ride.dart';

class CartProvider with ChangeNotifier {
  final List<CartItem> _items = [];
  final List<Ride> _rides = [];

  List<CartItem> get items => _items;
  List<Ride> get rides => _rides;

  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);
  int get totalItemsCount => itemCount + _rides.length;

  double get subtotal => _items.fold(0, (sum, item) => sum + item.totalPrice);
  double get ridesTotal => _rides.fold(0, (sum, ride) => sum + ride.price);
  double get grandSubtotal => subtotal + ridesTotal;

  double get deliveryCharges => subtotal > 500 ? 0 : 40;
  double get tax => grandSubtotal * 0.05;
  double get total => grandSubtotal + deliveryCharges + tax;

  void addItem(Product product) {
    final existingIndex = _items.indexWhere((item) => item.product.id == product.id);
    
    if (existingIndex >= 0) {
      _items[existingIndex].quantity++;
    } else {
      _items.add(CartItem(product: product));
    }
    notifyListeners();
  }
  
  // Helper method to check if product is in cart
  bool isInCart(int productId) {
    return _items.any((item) => item.product.id == productId);
  }
  
  // Helper method to get quantity of a product
  int getQuantity(int productId) {
    final index = _items.indexWhere((item) => item.product.id == productId);
    return index >= 0 ? _items[index].quantity : 0;
  }
  
  // Helper method to decrease quantity by 1
  void decreaseQuantity(int productId) {
    final index = _items.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      if (_items[index].quantity > 1) {
        _items[index].quantity--;
      } else {
        _items.removeAt(index);
      }
      notifyListeners();
    }
  }

  void removeItem(int productId) {
    _items.removeWhere((item) => item.product.id == productId);
    notifyListeners();
  }

  void updateQuantity(int productId, int quantity) {
    final index = _items.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      if (quantity > 0) {
        _items[index].quantity = quantity;
      } else {
        _items.removeAt(index);
      }
      notifyListeners();
    }
  }

  void incrementQuantity(int productId) {
    final index = _items.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      _items[index].quantity++;
      notifyListeners();
    }
  }

  void decrementQuantity(int productId) {
    final index = _items.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      if (_items[index].quantity > 1) {
        _items[index].quantity--;
      } else {
        _items.removeAt(index);
      }
      notifyListeners();
    }
  }

  // Ride management
  void addRide(Ride ride) {
    _rides.add(ride);
    notifyListeners();
  }

  void removeRide(String rideId) {
    _rides.removeWhere((ride) => ride.id == rideId);
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    _rides.clear();
    notifyListeners();
  }
}
