import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../providers/cart_provider.dart';
import '../models/products_data.dart';
import '../models/product.dart';
import '../utils/app_colors.dart';
import '../widgets/app_drawer.dart';
import 'cart_screen.dart';
import 'dinex_screen.dart';

// ─────────────────────────────────────────────
// ⚠️  REPLACE WITH YOUR ACTUAL GOOGLE PLACES API KEY
//     Enable "Places API (New)" in Google Cloud Console
//     Also enable "Maps SDK for Android/iOS" for future map view
// ─────────────────────────────────────────────
const String kGooglePlacesApiKey = 'AIzaSyDdIvpcgnlZ-kcin6B2lg2U2BxHX-cn9Eg';

// Radius (metres) for nearby restaurant search
const double kSearchRadiusMetres = 5000.0;

// ─────────────────────────────────────────────
// Menu Item model — id is int to match CartProvider
// ─────────────────────────────────────────────
class SwadishMenuItem {
  final int id;
  final String name, description, imageUrl;
  final double price;
  final bool isVeg;

  const SwadishMenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.price,
    required this.isVeg,
  });
}

// ─────────────────────────────────────────────
// Restaurant model — now carries live Places data
// ─────────────────────────────────────────────
class SwadistRestaurant {
  final String id; // Google Place ID
  final String name, cuisine, imageUrl, offer;
  final double rating, distance; // distance in km from user
  final int ratingCount, deliveryTime;
  final bool isPureVeg, isPromoted;
  final List<SwadishMenuItem> menuItems;
  final double lat, lng; // restaurant coordinates

  SwadistRestaurant({
    required this.id,
    required this.name,
    required this.cuisine,
    required this.imageUrl,
    required this.rating,
    required this.ratingCount,
    required this.distance,
    required this.deliveryTime,
    required this.offer,
    required this.isPureVeg,
    required this.isPromoted,
    required this.menuItems,
    required this.lat,
    required this.lng,
  });
}

// ─────────────────────────────────────────────
// Food Category chip model
// ─────────────────────────────────────────────
class _FoodCategory {
  final String name, imageUrl;
  const _FoodCategory({required this.name, required this.imageUrl});
}

// ─────────────────────────────────────────────
// Google Places API (New) service
// ─────────────────────────────────────────────
class _GooglePlacesService {
  static const String _baseUrl = 'https://places.googleapis.com/v1';

  static const List<String> _fieldMask = [
    'places.id',
    'places.displayName',
    'places.rating',
    'places.userRatingCount',
    'places.location',
    'places.photos',
    'places.priceLevel',
    'places.types',
    'places.primaryType',
    'places.primaryTypeDisplayName',
    'places.shortFormattedAddress',
    'places.regularOpeningHours',
    'places.currentOpeningHours',
    'places.editorialSummary',
    'places.dineIn',
    'places.takeout',
    'places.delivery',
    // nextPageToken is returned automatically — do NOT add it here,
    // mixing top-level and places.* fields in the mask causes a 400.
  ];

  // Fetches a single page (up to 20 results).
  // Returns the places list and the nextPageToken (null if no more pages).
  static Future<({List<Map<String, dynamic>> places, String? nextPageToken})>
      _fetchPage({
    required double latitude,
    required double longitude,
    double radiusMetres = kSearchRadiusMetres,
    String? pageToken,
  }) async {
    final url = Uri.parse('$_baseUrl/places:searchNearby');

    // Google Places API (New) rule: when pageToken is present the body must contain
    // ONLY pageToken (+ optionally maxResultCount). Sending any other field causes 400.
    final Map<String, dynamic> requestBody = pageToken != null
        ? {
            'pageToken': pageToken,
            'maxResultCount': 20,
          }
        : {
            'locationRestriction': {
              'circle': {
                'center': {'latitude': latitude, 'longitude': longitude},
                'radius': radiusMetres,
              },
            },
            'includedTypes': ['restaurant', 'cafe'],
            'maxResultCount': 20,
            'rankPreference': 'DISTANCE',
          };

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': kGooglePlacesApiKey,
        'X-Goog-FieldMask': _fieldMask.join(','),
      },
      body: jsonEncode(requestBody),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final places = (data['places'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      final next = data['nextPageToken'] as String?;
      return (places: places, nextPageToken: next);
    } else {
      debugPrint('Places API ${response.statusCode} — body: ${response.body}');
      debugPrint('Request body was: ${jsonEncode(requestBody)}');
      throw Exception('Failed to load restaurants: ${response.statusCode}');
    }
  }

  // Fetches ALL pages for the given location up to [maxPages] (default 5 = 100 results).
  // Calls [onPageLoaded] after each page so the UI can show results progressively.
  static Future<List<Map<String, dynamic>>> searchAllNearbyRestaurants({
    required double latitude,
    required double longitude,
    double radiusMetres = kSearchRadiusMetres,
    int maxPages = 5,
    void Function(List<Map<String, dynamic>> batch)? onPageLoaded,
  }) async {
    final all = <Map<String, dynamic>>[];
    String? pageToken;

    for (int page = 0; page < maxPages; page++) {
      final result = await _fetchPage(
        latitude: latitude,
        longitude: longitude,
        radiusMetres: radiusMetres,
        pageToken: pageToken,
      );

      all.addAll(result.places);
      onPageLoaded?.call(result.places);

      pageToken = result.nextPageToken;
      if (pageToken == null) break; // no more pages

      // Brief pause — Google recommends a short delay between paginated requests
      await Future.delayed(const Duration(milliseconds: 300));
    }

    return all;
  }

  // ── Citywide text search (used when the user types in the search bar) ──────
  // Uses Places API Text Search — no radius restriction, covers all of Bangalore.
  static Future<List<Map<String, dynamic>>> searchCitywideRestaurants({
    required String query,
    // Bias results toward Bangalore centre so the ranking favours the city
    double biasCentreLatitude = 12.9716,
    double biasCentrelongitude = 77.5946,
    double biasRadiusMetres = 30000.0, // 30 km soft bias (not a hard restriction)
  }) async {
    final url = Uri.parse('$_baseUrl/places:searchText');

    final Map<String, dynamic> requestBody = {
      'textQuery': '$query restaurant Bangalore',
      'includedType': 'restaurant',
      'maxResultCount': 20,
      'locationBias': {
        'circle': {
          'center': {
            'latitude': biasCentreLatitude,
            'longitude': biasCentrelongitude,
          },
          'radius': biasRadiusMetres,
        },
      },
    };

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': kGooglePlacesApiKey,
        'X-Goog-FieldMask': _fieldMask.join(','),
      },
      body: jsonEncode(requestBody),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['places'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    } else {
      debugPrint('Text Search ${response.statusCode} — body: ${response.body}');
      return [];
    }
  }

  // Build the photo URL for a Place photo reference
  // photo_name is the full resource name from API: "places/{placeId}/photos/{photoRef}"
  static String buildPhotoUrl(String photoName,
      {int maxHeightPx = 400, int maxWidthPx = 600}) {
    return '$_baseUrl/$photoName/media'
        '?maxHeightPx=$maxHeightPx'
        '&maxWidthPx=$maxWidthPx'
        '&key=$kGooglePlacesApiKey';
  }
}

// ─────────────────────────────────────────────
// Cuisine-based menu generator
// Google Places API has no menu data — we generate
// realistic cuisine-appropriate items for each restaurant
// ─────────────────────────────────────────────
class _MenuGenerator {
  static int _idCounter = 9000; // start high to avoid collision with other screens

  static List<SwadishMenuItem> generate(List<String> placeTypes, String restaurantName) {
    _idCounter += 10;
    final base = _idCounter;

    // Determine dominant cuisine from Google Places types
    if (_hasType(placeTypes, 'pizza_restaurant')) {
      return _pizzaMenu(base);
    } else if (_hasType(placeTypes, 'chinese_restaurant')) {
      return _chineseMenu(base);
    } else if (_hasType(placeTypes, 'south_indian_restaurant') ||
        restaurantName.toLowerCase().contains('dosa') ||
        restaurantName.toLowerCase().contains('idli') ||
        restaurantName.toLowerCase().contains('udupi')) {
      return _southIndianMenu(base);
    } else if (_hasType(placeTypes, 'north_indian_restaurant') ||
        restaurantName.toLowerCase().contains('dhaba') ||
        restaurantName.toLowerCase().contains('punjabi')) {
      return _northIndianMenu(base);
    } else if (_hasType(placeTypes, 'burger_restaurant') ||
        restaurantName.toLowerCase().contains('burger')) {
      return _burgerMenu(base);
    } else if (_hasType(placeTypes, 'biryani_restaurant') ||
        restaurantName.toLowerCase().contains('biryani') ||
        restaurantName.toLowerCase().contains('dum')) {
      return _biryaniMenu(base);
    } else if (_hasType(placeTypes, 'cafe') ||
        _hasType(placeTypes, 'coffee_shop') ||
        restaurantName.toLowerCase().contains('cafe') ||
        restaurantName.toLowerCase().contains('coffee')) {
      return _cafeMenu(base);
    } else if (_hasType(placeTypes, 'fast_food_restaurant')) {
      return _fastFoodMenu(base);
    } else {
      return _multiCuisineMenu(base);
    }
  }

  static bool _hasType(List<String> types, String type) =>
      types.any((t) => t.toLowerCase() == type.toLowerCase());

  static List<SwadishMenuItem> _biryaniMenu(int base) => [
        SwadishMenuItem(
          id: base,
          name: 'Chicken Dum Biryani',
          description: 'Slow-cooked basmati rice layered with spiced chicken, saffron & caramelised onions',
          imageUrl: 'https://images.unsplash.com/photo-1701579231305-d84d8af9a3fd?w=400&fit=crop',
          price: 249,
          isVeg: false,
        ),
        SwadishMenuItem(
          id: base + 1,
          name: 'Mutton Biryani',
          description: 'Tender mutton pieces cooked in aromatic spices with long-grain basmati',
          imageUrl: 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=400&fit=crop',
          price: 319,
          isVeg: false,
        ),
        SwadishMenuItem(
          id: base + 2,
          name: 'Veg Dum Biryani',
          description: 'Seasonal vegetables & paneer dum-cooked with fragrant basmati',
          imageUrl: 'https://images.unsplash.com/photo-1512058564366-18510be2db19?w=400&fit=crop',
          price: 189,
          isVeg: true,
        ),
        SwadishMenuItem(
          id: base + 3,
          name: 'Raita',
          description: 'Chilled yoghurt with cucumber, cumin & fresh coriander',
          imageUrl: 'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=400&fit=crop',
          price: 59,
          isVeg: true,
        ),
        SwadishMenuItem(
          id: base + 4,
          name: 'Egg Biryani',
          description: 'Perfectly boiled eggs layered in spiced rice with fresh herbs',
          imageUrl: 'https://images.unsplash.com/photo-1603133872878-684f208fb84b?w=400&fit=crop',
          price: 199,
          isVeg: false,
        ),
      ];

  static List<SwadishMenuItem> _southIndianMenu(int base) => [
        SwadishMenuItem(
          id: base,
          name: 'Masala Dosa',
          description: 'Crisp golden dosa filled with spiced potato bhaji, served with sambar & chutneys',
          imageUrl: 'https://images.unsplash.com/photo-1668236543090-82eba5ee5976?w=400&fit=crop',
          price: 109,
          isVeg: true,
        ),
        SwadishMenuItem(
          id: base + 1,
          name: 'Idli Sambar (3 pcs)',
          description: 'Steamed rice-lentil idlis with tangy sambar & coconut chutney',
          imageUrl: 'https://images.unsplash.com/photo-1630383249896-424e482df921?w=400&fit=crop',
          price: 89,
          isVeg: true,
        ),
        SwadishMenuItem(
          id: base + 2,
          name: 'Rava Uttapam',
          description: 'Thick semolina pancake topped with onion, tomato & green chilli',
          imageUrl: 'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=400&fit=crop',
          price: 119,
          isVeg: true,
        ),
        SwadishMenuItem(
          id: base + 3,
          name: 'Chettinad Chicken Curry',
          description: 'Fiery Chettinad-style chicken curry with freshly ground spices',
          imageUrl: 'https://images.unsplash.com/photo-1598103442097-8b74394b95c8?w=400&fit=crop',
          price: 219,
          isVeg: false,
        ),
        SwadishMenuItem(
          id: base + 4,
          name: 'Filter Coffee',
          description: 'Classic South Indian filter coffee with chicory, served in a dabarah-tumbler',
          imageUrl: 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=400&fit=crop',
          price: 49,
          isVeg: true,
        ),
      ];

  static List<SwadishMenuItem> _northIndianMenu(int base) => [
        SwadishMenuItem(
          id: base,
          name: 'Butter Chicken',
          description: 'Succulent tandoor chicken in rich tomato-cream gravy with kasuri methi',
          imageUrl: 'https://images.unsplash.com/photo-1603894584373-5ac82b2ae398?w=400&fit=crop',
          price: 279,
          isVeg: false,
        ),
        SwadishMenuItem(
          id: base + 1,
          name: 'Dal Makhani',
          description: 'Slow-cooked black lentils in buttery tomato gravy, a Punjabi classic',
          imageUrl: 'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=400&fit=crop',
          price: 199,
          isVeg: true,
        ),
        SwadishMenuItem(
          id: base + 2,
          name: 'Paneer Tikka Masala',
          description: 'Chargrilled cottage cheese in vibrant spiced onion-tomato gravy',
          imageUrl: 'https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=400&fit=crop',
          price: 249,
          isVeg: true,
        ),
        SwadishMenuItem(
          id: base + 3,
          name: 'Garlic Naan (2 pcs)',
          description: 'Soft leavened bread brushed with garlic butter, baked in tandoor',
          imageUrl: 'https://images.unsplash.com/photo-1549931319-a545dcf3bc7b?w=400&fit=crop',
          price: 79,
          isVeg: true,
        ),
        SwadishMenuItem(
          id: base + 4,
          name: 'Seekh Kebab (4 pcs)',
          description: 'Minced lamb kebabs with ginger, green chilli & fresh herbs, off the grill',
          imageUrl: 'https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?w=400&fit=crop',
          price: 239,
          isVeg: false,
        ),
      ];

  static List<SwadishMenuItem> _pizzaMenu(int base) => [
        SwadishMenuItem(
          id: base,
          name: 'Margherita Pizza',
          description: 'Classic tomato base, fresh mozzarella & basil on hand-tossed crust',
          imageUrl: 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=400&fit=crop',
          price: 269,
          isVeg: true,
        ),
        SwadishMenuItem(
          id: base + 1,
          name: 'Pepperoni Pizza',
          description: 'Generous pepperoni slices, mozzarella & oregano on rich tomato base',
          imageUrl: 'https://images.unsplash.com/photo-1534308983496-4fabb1a015ee?w=400&fit=crop',
          price: 349,
          isVeg: false,
        ),
        SwadishMenuItem(
          id: base + 2,
          name: 'BBQ Chicken Pizza',
          description: 'Smoky BBQ sauce, grilled chicken, red onion & cheddar',
          imageUrl: 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=400&fit=crop',
          price: 329,
          isVeg: false,
        ),
        SwadishMenuItem(
          id: base + 3,
          name: 'Pasta Arrabbiata',
          description: 'Penne in spicy tomato-garlic sauce with fresh basil',
          imageUrl: 'https://images.unsplash.com/photo-1645112411341-6c4fd023714a?w=400&fit=crop',
          price: 199,
          isVeg: true,
        ),
        SwadishMenuItem(
          id: base + 4,
          name: 'Cheesy Garlic Bread',
          description: 'Toasted baguette loaded with mozzarella, herbs & roasted garlic',
          imageUrl: 'https://images.unsplash.com/photo-1549931319-a545dcf3bc7b?w=400&fit=crop',
          price: 149,
          isVeg: true,
        ),
      ];

  static List<SwadishMenuItem> _burgerMenu(int base) => [
        SwadishMenuItem(
          id: base,
          name: 'Classic Chicken Burger',
          description: 'Crispy fried chicken thigh, lettuce, pickles & house mayo in a brioche bun',
          imageUrl: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=400&fit=crop',
          price: 219,
          isVeg: false,
        ),
        SwadishMenuItem(
          id: base + 1,
          name: 'BBQ Smash Burger',
          description: 'Double smash patty, cheddar, crispy bacon & smoky BBQ sauce',
          imageUrl: 'https://images.unsplash.com/photo-1553979459-d2229ba7433b?w=400&fit=crop',
          price: 289,
          isVeg: false,
        ),
        SwadishMenuItem(
          id: base + 2,
          name: 'Aloo Tikki Burger',
          description: 'Spiced potato patty, mint chutney, shredded slaw in a sesame bun',
          imageUrl: 'https://images.unsplash.com/photo-1585238342024-78d387f4a707?w=400&fit=crop',
          price: 159,
          isVeg: true,
        ),
        SwadishMenuItem(
          id: base + 3,
          name: 'Loaded Fries',
          description: 'Crispy fries topped with cheese sauce, jalapeños & spring onions',
          imageUrl: 'https://images.unsplash.com/photo-1573080496219-bb080dd4f877?w=400&fit=crop',
          price: 139,
          isVeg: true,
        ),
        SwadishMenuItem(
          id: base + 4,
          name: 'Chicken Wings (6 pcs)',
          description: 'Tossed in buffalo sauce, served with ranch dip',
          imageUrl: 'https://images.unsplash.com/photo-1527477396000-e27163b481c2?w=400&fit=crop',
          price: 249,
          isVeg: false,
        ),
      ];

  static List<SwadishMenuItem> _cafeMenu(int base) => [
        SwadishMenuItem(
          id: base,
          name: 'Cappuccino',
          description: 'Double espresso with velvety steamed milk foam, dusted with cocoa',
          imageUrl: 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=400&fit=crop',
          price: 129,
          isVeg: true,
        ),
        SwadishMenuItem(
          id: base + 1,
          name: 'Avocado Toast',
          description: 'Sourdough with smashed avocado, cherry tomatoes, feta & chilli flakes',
          imageUrl: 'https://images.unsplash.com/photo-1603046891744-76e6300f82ef?w=400&fit=crop',
          price: 199,
          isVeg: true,
        ),
        SwadishMenuItem(
          id: base + 2,
          name: 'Club Sandwich',
          description: 'Triple-decker with grilled chicken, egg, cheese, lettuce & tomato',
          imageUrl: 'https://images.unsplash.com/photo-1481070555726-e2fe8357725f?w=400&fit=crop',
          price: 239,
          isVeg: false,
        ),
        SwadishMenuItem(
          id: base + 3,
          name: 'Brownie Sundae',
          description: 'Warm chocolate brownie with vanilla gelato & hot fudge sauce',
          imageUrl: 'https://images.unsplash.com/photo-1545249390-6bdfa286032f?w=400&fit=crop',
          price: 179,
          isVeg: true,
        ),
        SwadishMenuItem(
          id: base + 4,
          name: 'Cold Brew Coffee',
          description: 'Steeped 18 hours, served over ice with a splash of oat milk',
          imageUrl: 'https://images.unsplash.com/photo-1461023058943-07fcbe16d735?w=400&fit=crop',
          price: 149,
          isVeg: true,
        ),
      ];

  static List<SwadishMenuItem> _chineseMenu(int base) => [
        SwadishMenuItem(
          id: base,
          name: 'Veg Hakka Noodles',
          description: 'Wok-tossed noodles with crunchy vegetables & dark soy sauce',
          imageUrl: 'https://images.unsplash.com/photo-1645112411341-6c4fd023714a?w=400&fit=crop',
          price: 159,
          isVeg: true,
        ),
        SwadishMenuItem(
          id: base + 1,
          name: 'Chicken Fried Rice',
          description: 'Egg-fried rice with diced chicken, spring onions & soy-chilli sauce',
          imageUrl: 'https://images.unsplash.com/photo-1603133872878-684f208fb84b?w=400&fit=crop',
          price: 189,
          isVeg: false,
        ),
        SwadishMenuItem(
          id: base + 2,
          name: 'Manchurian Gravy',
          description: 'Crispy vegetable balls in tangy Manchurian sauce with peppers & onions',
          imageUrl: 'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=400&fit=crop',
          price: 179,
          isVeg: true,
        ),
        SwadishMenuItem(
          id: base + 3,
          name: 'Crispy Chilli Chicken',
          description: 'Battered chicken strips tossed in fiery red chilli & garlic sauce',
          imageUrl: 'https://images.unsplash.com/photo-1598103442097-8b74394b95c8?w=400&fit=crop',
          price: 219,
          isVeg: false,
        ),
        SwadishMenuItem(
          id: base + 4,
          name: 'Hot & Sour Soup',
          description: 'Tangy clear broth with mushrooms, tofu, vinegar & white pepper',
          imageUrl: 'https://images.unsplash.com/photo-1547592180-85f173990554?w=400&fit=crop',
          price: 99,
          isVeg: true,
        ),
      ];

  static List<SwadishMenuItem> _fastFoodMenu(int base) => [
        SwadishMenuItem(
          id: base,
          name: 'Veg Wrap',
          description: 'Grilled paneer tikka, fresh vegetables & mint chutney in a wheat tortilla',
          imageUrl: 'https://images.unsplash.com/photo-1626700051175-6818013e1d4f?w=400&fit=crop',
          price: 149,
          isVeg: true,
        ),
        SwadishMenuItem(
          id: base + 1,
          name: 'Chicken Roll',
          description: 'Juicy grilled chicken strips, caramelised onions & spicy sauce in a paratha',
          imageUrl: 'https://images.unsplash.com/photo-1527477396000-e27163b481c2?w=400&fit=crop',
          price: 179,
          isVeg: false,
        ),
        SwadishMenuItem(
          id: base + 2,
          name: 'Pav Bhaji',
          description: 'Spiced mixed vegetable mash with buttered pav & onion-lemon garnish',
          imageUrl: 'https://images.unsplash.com/photo-1585237421612-70a008356fbe?w=400&fit=crop',
          price: 129,
          isVeg: true,
        ),
        SwadishMenuItem(
          id: base + 3,
          name: 'Masala Fries',
          description: 'Crispy fries tossed with chaat masala, lemon & fresh coriander',
          imageUrl: 'https://images.unsplash.com/photo-1573080496219-bb080dd4f877?w=400&fit=crop',
          price: 109,
          isVeg: true,
        ),
        SwadishMenuItem(
          id: base + 4,
          name: 'Mango Lassi',
          description: 'Thick chilled yoghurt blended with Alphonso mango pulp',
          imageUrl: 'https://images.unsplash.com/photo-1527661591475-527312dd65f5?w=400&fit=crop',
          price: 79,
          isVeg: true,
        ),
      ];

  static List<SwadishMenuItem> _multiCuisineMenu(int base) => [
        SwadishMenuItem(
          id: base,
          name: 'Paneer Butter Masala',
          description: 'Velvety tomato-cream gravy with golden paneer cubes & kasuri methi',
          imageUrl: 'https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=400&fit=crop',
          price: 229,
          isVeg: true,
        ),
        SwadishMenuItem(
          id: base + 1,
          name: 'Chicken Biryani',
          description: 'Aromatic basmati layered with spiced chicken, fried onions & saffron',
          imageUrl: 'https://images.unsplash.com/photo-1701579231305-d84d8af9a3fd?w=400&fit=crop',
          price: 259,
          isVeg: false,
        ),
        SwadishMenuItem(
          id: base + 2,
          name: 'Veg Fried Rice',
          description: 'Wok-tossed basmati with seasonal vegetables, eggs & soy sauce',
          imageUrl: 'https://images.unsplash.com/photo-1512058564366-18510be2db19?w=400&fit=crop',
          price: 169,
          isVeg: true,
        ),
        SwadishMenuItem(
          id: base + 3,
          name: 'Tandoori Chicken (half)',
          description: 'Marinated in yoghurt & spices, roasted in clay tandoor — smoky & juicy',
          imageUrl: 'https://images.unsplash.com/photo-1598103442097-8b74394b95c8?w=400&fit=crop',
          price: 289,
          isVeg: false,
        ),
        SwadishMenuItem(
          id: base + 4,
          name: 'Gulab Jamun (2 pcs)',
          description: 'Soft milk-solid dumplings soaked in rose-cardamom sugar syrup',
          imageUrl: 'https://images.unsplash.com/photo-1588166524941-3bf61a9c41db?w=400&fit=crop',
          price: 89,
          isVeg: true,
        ),
      ];
}

// ─────────────────────────────────────────────
// Main Screen
// ─────────────────────────────────────────────
class SwadistScreen extends StatefulWidget {
  final String initialSearchQuery;
  const SwadistScreen({super.key, this.initialSearchQuery = ''});
  @override
  State<SwadistScreen> createState() => _SwadistScreenState();
}

class _SwadistScreenState extends State<SwadistScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'All';
  String _selectedCategory = 'All';

  final List<String> _filters = [
    'All',
    'Pure Veg',
    'Offers',
    'Fast Delivery',
    'Ratings 4.0+',
  ];

  final List<_FoodCategory> _categories = [
    _FoodCategory(name: 'All', imageUrl: ''),
    _FoodCategory(
      name: 'Biryani',
      imageUrl: 'https://images.unsplash.com/photo-1701579231305-d84d8af9a3fd?w=200&fit=crop',
    ),
    _FoodCategory(
      name: 'Chicken',
      imageUrl: 'https://images.unsplash.com/photo-1598103442097-8b74394b95c8?w=200&fit=crop',
    ),
    _FoodCategory(
      name: 'North Indian',
      imageUrl: 'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=200&fit=crop',
    ),
    _FoodCategory(
      name: 'Pizza',
      imageUrl: 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=200&fit=crop',
    ),
    _FoodCategory(
      name: 'Burgers',
      imageUrl: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=200&fit=crop',
    ),
    _FoodCategory(
      name: 'South Indian',
      imageUrl: 'https://images.unsplash.com/photo-1668236543090-82eba5ee5976?w=200&fit=crop',
    ),
    _FoodCategory(
      name: 'Pasta',
      imageUrl: 'https://images.unsplash.com/photo-1645112411341-6c4fd023714a?w=200&fit=crop',
    ),
  ];

  // Location
  String _locationName = 'Fetching location...';
  bool _locationLoaded = false;
  Position? _userPosition;

  // Restaurants — nearby (<=5 km), shown on the default screen
  List<SwadistRestaurant> _restaurants = [];
  bool _loadingRestaurants = true;
  bool _loadingMore = false; // true while subsequent pages are being fetched
  String? _errorMessage;
  double _actualRadiusKm = kSearchRadiusMetres / 1000.0; // updated after each page loads

  // Citywide search — populated only when the user types in the search bar
  List<SwadistRestaurant> _searchResults = [];
  bool _searchLoading = false;
  Timer? _searchDebounce;

  // Banner
  final PageController _bannerCtrl = PageController(viewportFraction: 1.0);
  int _bannerIndex = 0;
  Timer? _bannerTimer;
  bool _bannerUserScrolling = false;

  // Using the same banner images from the original file
  final List<String> _bannerImages = [
    'assets/images/swadisht_banner_1.png',
    'assets/images/swadisht_banner_2.png',
    'assets/images/swadisht_banner_3.PNG', // "Curated Meals For You!" banner
  ];

  // Scroll controller + per-card keys for auto-scroll from dashboard
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _restaurantKeys = {};

  @override
  void initState() {
    super.initState();
    _fetchLocationAndRestaurants();
    _startBannerAutoPlay();
    if (widget.initialSearchQuery.isNotEmpty) {
      _searchController.text = widget.initialSearchQuery;
      _searchQuery = widget.initialSearchQuery;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerSearch(widget.initialSearchQuery);
        Future.delayed(const Duration(milliseconds: 900), _scrollToFirstMatch);
      });
    }
  }

  void _scrollToFirstMatch() {
    if (!mounted || _restaurantKeys.isEmpty) return;
    final firstKey = _restaurantKeys.values.first;
    final ctx = firstKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          alignment: 0.1);
    }
  }

  void _startBannerAutoPlay() {
    _bannerTimer?.cancel();
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_bannerUserScrolling && _bannerCtrl.hasClients) {
        final next = (_bannerIndex + 1) % _bannerImages.length;
        _bannerCtrl.animateToPage(
          next,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _onBannerScrollStart() {
    _bannerUserScrolling = true;
    _bannerTimer?.cancel();
  }

  void _onBannerScrollEnd() {
    _bannerUserScrolling = false;
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _startBannerAutoPlay();
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerCtrl.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Location + restaurant fetch ──────────────────
  Future<void> _fetchLocationAndRestaurants() async {
    setState(() {
      _loadingRestaurants = true;
      _errorMessage = null;
    });

    try {
      // 1. Check & request location permission
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationName = 'Bangalore, Karnataka';
          _locationLoaded = true;
        });
        await _loadNearbyRestaurants(lat: 12.9716, lng: 77.5946); // Bangalore fallback
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        setState(() {
          _locationName = 'Bangalore, Karnataka';
          _locationLoaded = true;
        });
        await _loadNearbyRestaurants(lat: 12.9716, lng: 77.5946);
        return;
      }

      // 2. Get device position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      setState(() => _userPosition = position);

      // 3. Reverse geocode for display name
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final parts = [
            p.subLocality,
            p.locality,
          ].where((s) => s != null && s.isNotEmpty).toList();
          setState(() {
            _locationName = parts.isNotEmpty ? parts.join(', ') : 'Your Location';
            _locationLoaded = true;
          });
        }
      } catch (_) {
        setState(() {
          _locationName = 'Your Location';
          _locationLoaded = true;
        });
      }

      // 4. Load nearby restaurants from Places API
      await _loadNearbyRestaurants(
        lat: position.latitude,
        lng: position.longitude,
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not fetch restaurants. Please check your connection.';
        _loadingRestaurants = false;
      });
    }
  }

  // ── Converts a raw Places API place map → SwadistRestaurant ─────────
  SwadistRestaurant? _parsePlaceToRestaurant(
    Map<String, dynamic> place, {
    required double userLat,
    required double userLng,
  }) {
    final placeId = place['id'] as String? ?? '';
    final displayName =
        (place['displayName'] as Map?)?.values.first as String? ?? 'Restaurant';
    final rating = (place['rating'] as num?)?.toDouble() ?? 0.0;
    final ratingCount = (place['userRatingCount'] as int?) ?? 0;
    final types = (place['types'] as List<dynamic>?)?.cast<String>() ?? [];
    final primaryType = place['primaryType'] as String? ?? '';

    debugPrint(
        'SWADISHT PLACE: "$displayName" | primary=$primaryType | types=${types.join(",")} | rating=$rating ($ratingCount reviews)');

    // ── CLIENT-SIDE QUALITY FILTER ───────────────────────────────────
    const blockedPrimaryTypes = {
      'grocery_store', 'supermarket', 'convenience_store',
      'butcher_shop', 'meat_market', 'market', 'food_store',
      'liquor_store', 'wholesale_store', 'gas_station',
      'department_store', 'clothing_store', 'hardware_store',
      'home_goods_store', 'pharmacy', 'pet_store', 'florist',
      'laundry', 'car_wash', 'car_repair', 'bank', 'atm',
    };
    if (primaryType.isNotEmpty && blockedPrimaryTypes.contains(primaryType)) {
      debugPrint('  → BLOCKED by primaryType: $primaryType');
      return null;
    }

    final lowerName = displayName.toLowerCase().trim();
    final blockedExactPatterns = [
      RegExp(r'\bchicken\s+(shop|center|centre|corner|stall|point|store|house)\b'),
      RegExp(r'\bmutton\s+(shop|center|centre|corner|stall|point|store|house)\b'),
      RegExp(r'\bmeat\s+(shop|center|centre|corner|stall|point|store|house|market)\b'),
      RegExp(r'\bfish\s+(market|shop|stall|point|center|centre)\b'),
      RegExp(r'\begg\s+(shop|stall|center|centre|store)\b'),
      RegExp(r'\bpoultry\s+(farm|shop|center|centre|stall)\b'),
      RegExp(r'\bbutcher\b'),
      RegExp(r'\bslaughter\b'),
      RegExp(r'\bfresh\s+chicken\b'),
      RegExp(r'\blive\s+chicken\b'),
      RegExp(r'\bbroiler\b'),
      RegExp(r'\bkirana\b'),
      RegExp(r'\bgrocery\b'),
      RegExp(r'\bsupermarket\b'),
      RegExp(r'\bhypermarket\b'),
      RegExp(r'\bgeneral\s+store\b'),
      RegExp(r'\bprovision\s+store\b'),
      RegExp(r'\bdepartmental\s+store\b'),
      RegExp(r'\bwine\s+(shop|store)\b'),
      RegExp(r'\bbeer\s+(shop|store)\b'),
      RegExp(r'\bliquor\s+(shop|store)\b'),
      RegExp(r'\btasmac\b'),
      RegExp(r'\bbevco\b'),
      RegExp(r'\bpharmacy\b'),
      RegExp(r'\bchemist\b'),
      RegExp(r'\bclinic\b'),
      RegExp(r'\bhospital\b'),
      RegExp(r'\bpetrol\b'),
      RegExp(r'\bfuel\s+station\b'),
      RegExp(r'\blaundry\b'),
      RegExp(r'\bdry\s+clean\b'),
      RegExp(r'\bsalon\b'),
      RegExp(r'\bbeauty\s+parlou?r\b'),
      RegExp(r'\bspa\b'),
    ];
    if (blockedExactPatterns.any((re) => re.hasMatch(lowerName))) {
      debugPrint('  → BLOCKED by name pattern: $lowerName');
      return null;
    }

    if (ratingCount == 0) {
      debugPrint('  → BLOCKED: zero reviews');
      return null;
    }
    // ────────────────────────────────────────────────────────────────

    final primaryTypeMap = place['primaryTypeDisplayName'] as Map?;
    final cuisineRaw =
        (primaryTypeMap?.values.first as String?) ?? _guessLabel(types);
    final cuisine = _cleanCuisineLabel(cuisineRaw);

    String photoUrl = _defaultFoodImage(types);
    final photos = place['photos'] as List<dynamic>?;
    if (photos != null && photos.isNotEmpty) {
      final photoName = photos.first['name'] as String?;
      if (photoName != null) {
        photoUrl = _GooglePlacesService.buildPhotoUrl(photoName);
      }
    }

    final location = place['location'] as Map?;
    final placeLat =
        (location?['latitude'] as num?)?.toDouble() ?? userLat;
    final placeLng =
        (location?['longitude'] as num?)?.toDouble() ?? userLng;

    final distanceMetres =
        Geolocator.distanceBetween(userLat, userLng, placeLat, placeLng);
    final distanceKm = distanceMetres / 1000.0;
    final deliveryTime =
        (15 + distanceKm * 3).round().clamp(15, 60);

    final isPureVeg = types.contains('vegetarian_restaurant') ||
        displayName.toLowerCase().contains('veg');

    final priceLevel = place['priceLevel'] as String? ?? '';
    final offer = _generateOffer(rating, priceLevel, ratingCount);
    final isPromoted = rating >= 4.5 && ratingCount >= 200;
    final menuItems = _MenuGenerator.generate(types, displayName);

    return SwadistRestaurant(
      id: placeId,
      name: displayName,
      cuisine: cuisine,
      imageUrl: photoUrl,
      rating: rating,
      ratingCount: ratingCount,
      distance: double.parse(distanceKm.toStringAsFixed(1)),
      deliveryTime: deliveryTime,
      offer: offer,
      isPureVeg: isPureVeg,
      isPromoted: isPromoted,
      menuItems: menuItems,
      lat: placeLat,
      lng: placeLng,
    );
  }

  // ── Google Places API: Nearby Restaurants (paginated) ────────────
  Future<void> _loadNearbyRestaurants({
    required double lat,
    required double lng,
  }) async {
    setState(() {
      _loadingRestaurants = true;
      _loadingMore = false;
      _restaurants = [];
    });

    // Dedupe across pages by Place ID
    final seenIds = <String>{};

    try {
      await _GooglePlacesService.searchAllNearbyRestaurants(
        latitude: lat,
        longitude: lng,
        maxPages: 5, // up to 100 results (5 × 20)
        onPageLoaded: (batch) {
          if (!mounted) return;

          final newEntries = <SwadistRestaurant>[];
          for (final place in batch) {
            final id = place['id'] as String? ?? '';
            if (id.isNotEmpty && seenIds.contains(id)) continue;
            if (id.isNotEmpty) seenIds.add(id);

            final r = _parsePlaceToRestaurant(
              place,
              userLat: lat,
              userLng: lng,
            );
            if (r != null) newEntries.add(r);
          }

          if (newEntries.isEmpty) return;

          setState(() {
            // Merge + re-sort by distance so order stays correct after each page
            final merged = [..._restaurants, ...newEntries]
              ..sort((a, b) => a.distance.compareTo(b.distance));

            _restaurants = merged;
            _loadingRestaurants = false; // first page done → show results
            _loadingMore = true; // still fetching more pages

            if (merged.isNotEmpty) {
              final maxDist = merged.last.distance;
              _actualRadiusKm = (maxDist * 2).ceilToDouble() / 2;
            }
          });
        },
      );

      // All pages done
      if (mounted) {
        setState(() => _loadingMore = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (_restaurants.isEmpty) {
            _errorMessage = 'Couldn\'t load restaurants: ${e.toString()}';
          }
          _loadingRestaurants = false;
          _loadingMore = false;
        });
      }
    }
  }

  // ── Citywide text-search triggered by the search bar ────────────────
  // Searches all of Bangalore — no 5 km restriction.
  Future<void> _triggerSearch(String query) async {
    _searchDebounce?.cancel();

    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _searchLoading = false;
      });
      return;
    }

    // Debounce: wait 500 ms after the user stops typing
    _searchDebounce = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      setState(() => _searchLoading = true);

      try {
        final userLat = _userPosition?.latitude ?? 12.9716;
        final userLng = _userPosition?.longitude ?? 77.5946;

        final rawPlaces = await _GooglePlacesService.searchCitywideRestaurants(
          query: query.trim(),
        );

        if (!mounted) return;

        final results = <SwadistRestaurant>[];
        final seenIds = <String>{};
        for (final place in rawPlaces) {
          final id = place['id'] as String? ?? '';
          if (id.isNotEmpty && seenIds.contains(id)) continue;
          if (id.isNotEmpty) seenIds.add(id);

          final r = _parsePlaceToRestaurant(
            place,
            userLat: userLat,
            userLng: userLng,
          );
          if (r != null) results.add(r);
        }

        // Sort by distance so closest appear first even in citywide results
        results.sort((a, b) => a.distance.compareTo(b.distance));

        setState(() {
          _searchResults = results;
          _searchLoading = false;
        });
      } catch (e) {
        if (mounted) setState(() => _searchLoading = false);
      }
    });
  }

  // ── Helpers ──────────────────────────────────────
  String _guessLabel(List<String> types) {
    const map = {
      'biryani_restaurant': 'Biryani',
      'south_indian_restaurant': 'South Indian',
      'north_indian_restaurant': 'North Indian',
      'pizza_restaurant': 'Pizza',
      'burger_restaurant': 'Burgers',
      'chinese_restaurant': 'Chinese',
      'cafe': 'Café',
      'coffee_shop': 'Coffee',
      'fast_food_restaurant': 'Fast Food',
      'vegetarian_restaurant': 'Pure Veg',
      'seafood_restaurant': 'Seafood',
      'barbecue_restaurant': 'BBQ & Grill',
      'indian_restaurant': 'Indian',
    };
    for (final t in types) {
      if (map.containsKey(t)) return map[t]!;
    }
    return 'Multi Cuisine';
  }

  String _cleanCuisineLabel(String raw) {
    return raw
        .replaceAll('_restaurant', '')
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  String _defaultFoodImage(List<String> types) {
    if (types.contains('pizza_restaurant')) {
      return 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=600&fit=crop';
    } else if (types.contains('south_indian_restaurant')) {
      return 'https://images.unsplash.com/photo-1668236543090-82eba5ee5976?w=600&fit=crop';
    } else if (types.contains('biryani_restaurant')) {
      return 'https://images.unsplash.com/photo-1701579231305-d84d8af9a3fd?w=600&fit=crop';
    } else if (types.contains('burger_restaurant')) {
      return 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=600&fit=crop';
    } else if (types.contains('cafe') || types.contains('coffee_shop')) {
      return 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=600&fit=crop';
    }
    return 'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=600&fit=crop';
  }

  String _generateOffer(double rating, String priceLevel, int ratingCount) {
    if (rating >= 4.5) return '20% OFF on first order';
    if (priceLevel == 'PRICE_LEVEL_INEXPENSIVE') return 'Flat ₹30 OFF on ₹199+';
    if (ratingCount > 500) return '15% OFF | Use SWAD15';
    return 'Free delivery on ₹249+';
  }

  // ── Filtering ────────────────────────────────────
  List<SwadistRestaurant> get _filteredRestaurants {
    // When the user is actively searching, use citywide results (no distance cap).
    // When on the default screen, enforce the 5 km radius.
    final bool isSearching = _searchQuery.isNotEmpty;
    final sourceList = isSearching ? _searchResults : _restaurants;

    return sourceList.where((r) {
      // Default screen: hard 5 km cap (search bypasses this)
      if (!isSearching && r.distance > 5.0) return false;

      // Search query — already filtering the right pool, just match text
      if (isSearching) {
        final q = _searchQuery.toLowerCase();
        final nameMatch = r.name.toLowerCase().contains(q);
        final cuisineMatch = r.cuisine.toLowerCase().contains(q);
        final menuMatch = r.menuItems.any((m) => m.name.toLowerCase().contains(q));
        if (!nameMatch && !cuisineMatch && !menuMatch) return false;
      }

      // Category filter (cuisine-based)
      if (_selectedCategory != 'All') {
        final c = _selectedCategory.toLowerCase();
        if (!r.cuisine.toLowerCase().contains(c) &&
            !r.name.toLowerCase().contains(c)) return false;
      }

      // Filter chips
      switch (_selectedFilter) {
        case 'Pure Veg':
          if (!r.isPureVeg) return false;
          break;
        case 'Offers':
          if (r.offer.isEmpty) return false;
          break;
        case 'Fast Delivery':
          if (r.deliveryTime > 30) return false;
          break;
        case 'Ratings 4.0+':
          if (r.rating < 4.0) return false;
          break;
      }

      return true;
    }).toList();
  }

  // ─────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final cartCount = cart.totalItemsCount;
    final filtered = _filteredRestaurants;

    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      extendBodyBehindAppBar: true,
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        color: AppColors.swadistPrimary,
        onRefresh: _fetchLocationAndRestaurants,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // ── Full-bleed Hero Banner with floating header overlay
            SliverToBoxAdapter(child: _buildHeroBannerWithHeader(topPadding, cartCount)),

            // ── Food categories
            SliverToBoxAdapter(child: _buildCategorySection()),

            // ── Filter chips
            SliverToBoxAdapter(child: _buildFilterSection()),

            // ── "Restaurants near you" / "Search results" header
            SliverToBoxAdapter(child: _buildSectionHeader(filtered.length)),

            // ── Restaurant list or loading state
            if (_loadingRestaurants)
              SliverToBoxAdapter(child: _buildLoadingShimmer())
            else if (_searchLoading)
              SliverToBoxAdapter(child: _buildSearchLoadingIndicator())
            else if (_errorMessage != null)
              SliverToBoxAdapter(child: _buildErrorState())
            else if (filtered.isEmpty)
              SliverToBoxAdapter(child: _buildEmptyState())
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final r = filtered[index];
                    _restaurantKeys[index] ??= GlobalKey();
                    return KeyedSubtree(
                      key: _restaurantKeys[index],
                      child: _buildRestaurantCard(r),
                    );
                  },
                  childCount: filtered.length,
                ),
              ),

            // ── "Loading more" indicator while subsequent pages fetch
            if (_loadingMore && _searchQuery.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.swadistPrimary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Loading more restaurants...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  // ── AppBar ──────────────────────────────────────
  // ── Full-bleed Hero Banner with floating header overlay ─────────
  Widget _buildHeroBannerWithHeader(double topPadding, int cartCount) {
    // Total height: status bar + app-bar-row + venture buttons + search bar + banner peek
    const double appBarRowH   = 52.0;
    const double ventureH     = 76.0;
    const double searchH      = 58.0;
    const double dotsH        = 26.0;
    const double bannerExtra  = 90.0; // extra banner visible below controls
    final double totalH = topPadding + appBarRowH + ventureH + searchH + dotsH + bannerExtra;

    return SizedBox(
      height: totalH,
      child: Stack(
        children: [
          // ── Full-bleed PageView behind everything ──────────────
          Positioned.fill(
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n is ScrollStartNotification && n.dragDetails != null) {
                  _onBannerScrollStart();
                } else if (n is ScrollEndNotification) {
                  _onBannerScrollEnd();
                }
                return false;
              },
              child: PageView.builder(
                controller: _bannerCtrl,
                physics: const BouncingScrollPhysics(),
                itemCount: _bannerImages.length,
                onPageChanged: (i) => setState(() => _bannerIndex = i),
                itemBuilder: (_, i) {
                  // Banner 3 is a wide landscape image ("Curated Meals For You!").
                  // Using fitWidth ensures the full image width is always visible.
                  // The image's own deep-red background fills any remaining vertical space,
                  // so we set the container background to the same colour — no whitespace.
                  final bool isWideBanner = i == 2;
                  return Container(
                    color: isWideBanner ? const Color(0xFF8B1010) : Colors.black,
                    child: Image.asset(
                      _bannerImages[i],
                      fit: isWideBanner ? BoxFit.fitWidth : BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      alignment: Alignment.center,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.swadistPrimary,
                        child: const Center(child: Icon(Icons.restaurant, size: 60, color: Colors.white)),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // ── Dark gradient so text/controls are readable ─────────
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.60),
                      Colors.black.withOpacity(0.30),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.50, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // ── Scroll-indicator dots (above venture buttons area) ──
          Positioned(
            bottom: dotsH + searchH + ventureH - 4,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_bannerImages.length, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _bannerIndex == i ? 20 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: _bannerIndex == i ? Colors.white : Colors.white.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(4),
                ),
              )),
            ),
          ),

          // ── Top row: hamburger | location | cart ────────────────
          Positioned(
            top: topPadding + 4,
            left: 4,
            right: 8,
            child: Row(
              children: [
                Builder(
                  builder: (ctx) => IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white, size: 26),
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                  ),
                ),
                const Icon(Icons.location_on, color: Colors.white70, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _locationLoaded ? _locationName : 'Locating...',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_userPosition != null)
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'Searching all of Bangalore'
                              : 'Within 5 km radius',
                          style: const TextStyle(color: Colors.white60, fontSize: 10),
                        ),
                    ],
                  ),
                ),
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CartScreen()),
                      ),
                    ),
                    if (cartCount > 0)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
                          child: Text('$cartCount',
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900)),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // ── Venture buttons (floating, semi-transparent bg) ─────
          Positioned(
            bottom: searchH + dotsH - 2,
            left: 12,
            right: 12,
            child: _buildVentureButtons(),
          ),

          // ── Floating search bar at the bottom ───────────────────
          Positioned(
            bottom: dotsH,
            left: 16,
            right: 16,
            child: _buildSearchBar(),
          ),
        ],
      ),
    );
  }

  // ── Search bar ──────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 2))],
      ),
        child: TextField(
          controller: _searchController,
          onChanged: (v) {
            setState(() => _searchQuery = v.trim());
            _triggerSearch(v.trim());
          },
          decoration: InputDecoration(
            hintText: 'Search restaurants, cuisines, dishes...',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
            suffixIcon: _searchQuery.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                        _searchResults = [];
                        _searchLoading = false;
                      });
                      _searchDebounce?.cancel();
                    },
                    child: const Icon(Icons.close, size: 18),
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
    );
  }

  // ── Venture Buttons (Zepto-style) ───────────────
  Widget _buildVentureButtons() {
    return Row(
        children: [
          // ── Swadisht (active / selected)
          Expanded(
            child: GestureDetector(
              onTap: () {}, // Already on Swadisht screen
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E8),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.10),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: Border.all(
                    color: AppColors.swadistPrimary.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'swadisht',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.swadistPrimary,
                        letterSpacing: -0.5,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Food Delivery',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: AppColors.swadistPrimary.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // ── DineX
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DinexScreen()),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.07),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: const TextSpan(
                        children: [
                          TextSpan(
                            text: 'Dine',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1A1A2E),
                              letterSpacing: -0.5,
                            ),
                          ),
                          TextSpan(
                            text: 'X',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFE63946),
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Dine-in & Reserve',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // ── Swadisht Cafe
          Expanded(
            child: GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.swadistPrimary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.coffee_outlined,
                            size: 28,
                            color: AppColors.swadistPrimary,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Swadisht Cafe',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'We\'re brewing something special. Coming soon!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 18),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Got it',
                            style: TextStyle(
                              color: AppColors.swadistPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.07),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'cafe',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.swadistPrimary,
                              letterSpacing: -0.5,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B35),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Coming Soon',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
    );
  }

  // ── Food categories ─────────────────────────────
  Widget _buildCategorySection() {
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _categories.length,
        itemBuilder: (_, i) {
          final cat = _categories[i];
          final isSelected = _selectedCategory == cat.name;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat.name),
            child: Container(
              width: 70,
              margin: const EdgeInsets.only(right: 8),
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? AppColors.swadistPrimary : Colors.transparent,
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: cat.imageUrl.isEmpty
                          ? Container(
                              color: AppColors.swadistPrimary.withOpacity(0.1),
                              child: Icon(Icons.restaurant_menu,
                                  color: AppColors.swadistPrimary, size: 28),
                            )
                          : Image.network(
                              cat.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.grey.shade100,
                                child: const Icon(Icons.restaurant, size: 22),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    cat.name,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? AppColors.swadistPrimary
                          : Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Filter chips ─────────────────────────────────
  Widget _buildFilterSection() {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _filters.length,
        itemBuilder: (_, i) {
          final f = _filters[i];
          final selected = _selectedFilter == f;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? AppColors.swadistPrimary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? AppColors.swadistPrimary : Colors.grey.shade300,
                ),
                boxShadow: selected
                    ? [BoxShadow(
                        color: AppColors.swadistPrimary.withOpacity(0.25),
                        blurRadius: 8,
                      )]
                    : [],
              ),
              child: Text(
                f,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : Colors.black87,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Section header ───────────────────────────────
  Widget _buildSectionHeader(int count) {
    final bool isSearching = _searchQuery.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSearching
                      ? 'Results across Bangalore'
                      : 'Restaurants near you',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                if (!_loadingRestaurants && _errorMessage == null)
                  Text(
                    isSearching
                        ? (_searchLoading
                            ? 'Searching Bangalore...'
                            : '$count places found')
                        : (_loadingMore
                            ? '$count places found so far...'
                            : '$count places within 5 km'),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
              ],
            ),
          ),
          if (_locationLoaded && !_loadingRestaurants)
            GestureDetector(
              onTap: _fetchLocationAndRestaurants,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.swadistPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.my_location, size: 14, color: AppColors.swadistPrimary),
                    const SizedBox(width: 4),
                    Text(
                      'Refresh',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.swadistPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Search loading indicator ─────────────────────
  Widget _buildSearchLoadingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.swadistPrimary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Searching across Bangalore...',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── Loading shimmer ──────────────────────────────
  Widget _buildLoadingShimmer() {
    return Column(
      children: List.generate(
        4,
        (_) => Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Container(
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 14, width: 180, color: Colors.grey.shade200),
                    const SizedBox(height: 8),
                    Container(height: 11, width: 120, color: Colors.grey.shade100),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(height: 11, width: 60, color: Colors.grey.shade100),
                        const SizedBox(width: 8),
                        Container(height: 11, width: 60, color: Colors.grey.shade100),
                        const SizedBox(width: 8),
                        Container(height: 11, width: 60, color: Colors.grey.shade100),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Error state ──────────────────────────────────
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.wifi_off_rounded, size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _fetchLocationAndRestaurants,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.swadistPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty state ──────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.restaurant_outlined, size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No restaurants match your filters',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try changing the category or filter',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }

  // ── Restaurant card ──────────────────────────────
  Widget _buildRestaurantCard(SwadistRestaurant r) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _RestaurantMenuScreen(restaurant: r),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Restaurant photo
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  child: Image.network(
                    r.imageUrl,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 160,
                      color: Colors.grey.shade100,
                      child: Center(
                        child: Icon(Icons.restaurant, size: 48, color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                ),

                // Offer badge
                if (r.offer.isNotEmpty)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Color(0xCC000000), Colors.transparent],
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.local_offer, color: Colors.amber, size: 13),
                          const SizedBox(width: 4),
                          Text(
                            r.offer,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Promoted badge
                if (r.isPromoted)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.swadistPrimary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'PROMOTED',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),

                // Pure Veg badge
                if (r.isPureVeg)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade700,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '🌿 PURE VEG',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // ── Info section
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Text(
                    r.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 3),

                  // Cuisine
                  Text(
                    r.cuisine,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Stats row — Rating | Distance | Delivery time
                  Row(
                    children: [
                      // Rating
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: r.rating >= 4.0
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.star, color: Colors.white, size: 11),
                            const SizedBox(width: 2),
                            Text(
                              r.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text('•', style: TextStyle(color: Colors.grey.shade400)),
                      ),

                      // Real distance from user
                      Row(
                        children: [
                          Icon(Icons.near_me_outlined,
                              size: 13, color: Colors.grey.shade600),
                          const SizedBox(width: 3),
                          Text(
                            r.distance < 1.0
                                ? '${(r.distance * 1000).toStringAsFixed(0)} m'
                                : '${r.distance.toStringAsFixed(1)} km',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text('•', style: TextStyle(color: Colors.grey.shade400)),
                      ),

                      // Delivery time
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 13, color: Colors.grey.shade600),
                          const SizedBox(width: 3),
                          Text(
                            '${r.deliveryTime} min',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Rating count
                  if (r.ratingCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${_formatCount(r.ratingCount)} ratings on Google',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '$count';
  }
}

// ─────────────────────────────────────────────
// Restaurant Menu Screen
// ─────────────────────────────────────────────
class _RestaurantMenuScreen extends StatefulWidget {
  final SwadistRestaurant restaurant;
  const _RestaurantMenuScreen({required this.restaurant});

  @override
  State<_RestaurantMenuScreen> createState() => _RestaurantMenuScreenState();
}

class _RestaurantMenuScreenState extends State<_RestaurantMenuScreen> {
  final TextEditingController _menuSearchCtrl = TextEditingController();
  String _menuSearch = '';
  String _menuFilter = 'All';
  final List<String> _menuFilters = ['All', 'Veg', 'Non-Veg'];

  @override
  void dispose() {
    _menuSearchCtrl.dispose();
    super.dispose();
  }

  List<SwadishMenuItem> get _filteredItems {
    return widget.restaurant.menuItems.where((item) {
      // Search
      if (_menuSearch.isNotEmpty) {
        if (!item.name.toLowerCase().contains(_menuSearch.toLowerCase())) return false;
      }
      // Veg filter
      if (_menuFilter == 'Veg' && !item.isVeg) return false;
      if (_menuFilter == 'Non-Veg' && item.isVeg) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.restaurant;
    final cart = context.watch<CartProvider>();
    final cartCount = cart.totalItemsCount;
    final items = _filteredItems;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: CustomScrollView(
        slivers: [
          // ── Hero image + back button
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: AppColors.swadistPrimary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              Stack(
                alignment: Alignment.topRight,
                children: [
                  IconButton(
                    icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CartScreen()),
                    ),
                  ),
                  if (cartCount > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.amber,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$cartCount',
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                ],
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    r.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppColors.swadistPrimary.withOpacity(0.3),
                      child: const Center(child: Icon(Icons.restaurant, size: 60, color: Colors.white30)),
                    ),
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xAA000000)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Restaurant info card
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    r.cuisine,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 12),

                  // Stats row
                  Row(
                    children: [
                      _InfoChip(
                        Icons.star,
                        '${r.rating.toStringAsFixed(1)} (${_shortCount(r.ratingCount)})',
                        r.rating >= 4.0 ? Colors.green.shade700 : Colors.orange.shade700,
                      ),
                      const SizedBox(width: 16),
                      _InfoChip(
                        Icons.near_me_outlined,
                        r.distance < 1.0
                            ? '${(r.distance * 1000).toStringAsFixed(0)} m away'
                            : '${r.distance.toStringAsFixed(1)} km away',
                        Colors.blue.shade600,
                      ),
                      const SizedBox(width: 16),
                      _InfoChip(
                        Icons.access_time,
                        '${r.deliveryTime} min',
                        Colors.grey.shade600,
                      ),
                    ],
                  ),

                  if (r.offer.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.local_offer, size: 14, color: Colors.orange.shade700),
                          const SizedBox(width: 6),
                          Text(
                            r.offer,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 8)),

          // ── Menu search + filter
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Menu',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _menuSearchCtrl,
                    onChanged: (v) => setState(() => _menuSearch = v.trim()),
                    decoration: InputDecoration(
                      hintText: 'Search dishes...',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      prefixIcon: const Icon(Icons.search, size: 18),
                      suffixIcon: _menuSearch.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                _menuSearchCtrl.clear();
                                setState(() => _menuSearch = '');
                              },
                              child: const Icon(Icons.close, size: 16),
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: _menuFilters.map((f) {
                      final selected = _menuFilter == f;
                      return GestureDetector(
                        onTap: () => setState(() => _menuFilter = f),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: selected ? AppColors.swadistPrimary : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: selected ? AppColors.swadistPrimary : Colors.grey.shade300,
                            ),
                          ),
                          child: Text(
                            f,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: selected ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),

          // ── Menu items
          if (items.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Center(
                  child: Text(
                    'No dishes found',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildMenuItemCard(items[index], cart),
                childCount: items.length,
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
      // Bottom cart bar
      bottomNavigationBar: cartCount > 0
          ? SafeArea(
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CartScreen()),
                ),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.swadistPrimary,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.swadistPrimary.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$cartCount item${cartCount > 1 ? 's' : ''}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'View Cart',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
                    ],
                  ),
                ),
              ),
            )
          : null,
    );
  }

  // ── Menu item card ─────────────────────────────
  Widget _buildMenuItemCard(SwadishMenuItem item, CartProvider cart) {
    final cartProduct = Product(
      id: item.id,
      name: item.name,
      price: item.price,
      imageUrl: item.imageUrl,
      category: 'Swadisht',
      description: item.description,
      emoji: '',
    );
    final isInCart = cart.getQuantity(item.id) > 0;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: veg indicator + info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Veg / Non-veg indicator
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: item.isVeg ? Colors.green.shade700 : Colors.red.shade700,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Center(
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: item.isVeg ? Colors.green.shade700 : Colors.red.shade700,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '₹${item.price.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.description,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.isVeg ? 'Pure veg' : 'Non-veg'} • Customisable',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // Right: image + ADD button
              Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      item.imageUrl,
                      width: 100,
                      height: 90,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 100,
                        height: 90,
                        color: Colors.grey.shade100,
                        child: Icon(Icons.restaurant, size: 36, color: Colors.grey.shade400),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (!isInCart)
                    GestureDetector(
                      onTap: () {
                        cart.addItem(cartProduct);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('${item.name} added!'),
                          duration: const Duration(seconds: 1),
                          backgroundColor: const Color(0xFF388E3C),
                        ));
                      },
                      child: Container(
                        width: 100,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.swadistPrimary, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'ADD',
                              style: TextStyle(
                                color: AppColors.swadistPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.add, size: 14, color: AppColors.swadistPrimary),
                          ],
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 100,
                      decoration: BoxDecoration(
                        color: AppColors.swadistPrimary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          InkWell(
                            onTap: () => cart.decreaseQuantity(item.id),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                              child: Icon(Icons.remove, color: Colors.white, size: 16),
                            ),
                          ),
                          Text(
                            '${cart.getQuantity(item.id)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                          InkWell(
                            onTap: () => cart.addItem(cartProduct),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                              child: Icon(Icons.add, color: Colors.white, size: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Divider(height: 1, color: Color(0xFFF0F0F0)),
          ),
        ],
      ),
    );
  }

  String _shortCount(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

// ─────────────────────────────────────────────
// Info chip widget
// ─────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
}