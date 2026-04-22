import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/app_colors.dart';
import '../widgets/category_chips.dart';
import '../widgets/app_drawer.dart';

// ─────────────────────────────────────────────
// ⚠️  Same API key used in swadisht_screen.dart
//     Enable "Places API (New)" in Google Cloud Console
// ─────────────────────────────────────────────
const String _kGooglePlacesApiKey = 'AIzaSyDdIvpcgnlZ-kcin6B2lg2U2BxHX-cn9Eg';

// Radius (metres) for nearby restaurant search — same as swadisht_screen
const double _kSearchRadiusMetres = 5000.0;

// ─────────────────────────────────────────────
// Google Places API (New) service
// Mirrors the implementation in swadisht_screen.dart
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
    'places.reservable',
  ];

  // Types that are NOT proper sit-down restaurants — used to exclude bad results
  static const Set<String> _excludedTypes = {
    'gas_station',
    'fuel',
    'convenience_store',
    'grocery_store',
    'supermarket',
    'liquor_store',
    'pharmacy',
    'drugstore',
    'clothing_store',
    'department_store',
    'shoe_store',
    'shopping_mall',
    'hardware_store',
    'home_goods_store',
    'furniture_store',
    'electronics_store',
    'book_store',
    'pet_store',
    'florist',
    'jewelry_store',
    'beauty_salon',
    'hair_care',
    'spa',
    'gym',
    'hospital',
    'doctor',
    'dentist',
    'bank',
    'atm',
    'car_wash',
    'car_dealer',
    'car_repair',
    'parking',
    'lodging',
    'hotel',
    'motel',
    'bar',           // pure bars without dine-in
    'night_club',
    'movie_theater',
    'stadium',
    'amusement_park',
    'zoo',
    'museum',
    'school',
    'university',
    'library',
    'place_of_worship',
  };

  /// Returns true if the place is a genuine sit-down restaurant
  /// with table-booking capability (dineIn OR reservable).
  static bool isValidDineInRestaurant(Map<String, dynamic> place) {
    final types = (place['types'] as List<dynamic>? ?? []).cast<String>();

    // Must have at least one restaurant-type indicator
    final bool hasRestaurantType = types.any((t) =>
        t == 'restaurant' ||
        t == 'cafe' ||
        t.contains('restaurant') ||
        t.contains('food'));

    if (!hasRestaurantType) return false;

    // Must NOT be predominantly a non-restaurant business
    final bool hasExcludedType =
        types.any((t) => _excludedTypes.contains(t));
    if (hasExcludedType) return false;

    // Must support dine-in OR be marked reservable
    final bool dineIn = place['dineIn'] as bool? ?? false;
    final bool reservable = place['reservable'] as bool? ?? false;
    if (!dineIn && !reservable) return false;

    // Minimum quality bar — skip very low-rated or unrated places
    final double rating = (place['rating'] as num?)?.toDouble() ?? 0.0;
    if (rating > 0 && rating < 3.5) return false;

    return true;
  }

  /// Fetches a single page (up to 20 results).
  static Future<({List<Map<String, dynamic>> places, String? nextPageToken})>
      _fetchPage({
    required double latitude,
    required double longitude,
    double radiusMetres = _kSearchRadiusMetres,
    String? pageToken,
  }) async {
    final url = Uri.parse('$_baseUrl/places:searchNearby');

    final Map<String, dynamic> requestBody = pageToken != null
        ? {'pageToken': pageToken, 'maxResultCount': 20}
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
        'X-Goog-Api-Key': _kGooglePlacesApiKey,
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
      throw Exception('Failed to load restaurants: ${response.statusCode}');
    }
  }

  /// Fetches all pages up to [maxPages] and returns the raw place maps.
  static Future<List<Map<String, dynamic>>> searchAllNearby({
    required double latitude,
    required double longitude,
    double radiusMetres = _kSearchRadiusMetres,
    int maxPages = 3,
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
      pageToken = result.nextPageToken;
      if (pageToken == null) break;

      // Brief pause recommended by Google between paginated requests
      await Future.delayed(const Duration(milliseconds: 300));
    }

    return all;
  }

  /// Searches restaurants across Bangalore by text query (no radius limit).
  /// Used for the search bar so users can find any restaurant in the city.
  static Future<List<Map<String, dynamic>>> searchByText({
    required String query,
    required double userLat,
    required double userLon,
  }) async {
    final url = Uri.parse('$_baseUrl/places:searchText');

    final Map<String, dynamic> requestBody = {
      'textQuery': '$query restaurant Bangalore',
      'includedType': 'restaurant',
      'maxResultCount': 20,
      'locationBias': {
        'circle': {
          'center': {'latitude': userLat, 'longitude': userLon},
          // Wide bias for Bangalore (~25 km) — not a hard restriction
          'radius': 25000.0,
        },
      },
    };

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': _kGooglePlacesApiKey,
        'X-Goog-FieldMask': _fieldMask.join(','),
      },
      body: jsonEncode(requestBody),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['places'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
    } else {
      debugPrint(
          'Places Text Search ${response.statusCode} — body: ${response.body}');
      return [];
    }
  }

  /// Builds a photo URL for a place photo resource name.
  static String buildPhotoUrl(String photoName,
      {int maxHeightPx = 400, int maxWidthPx = 600}) {
    return '$_baseUrl/$photoName/media'
        '?maxHeightPx=$maxHeightPx'
        '&maxWidthPx=$maxWidthPx'
        '&key=$_kGooglePlacesApiKey';
  }
}

// ─────────────────────────────────────────────
// Helper — map Google place types → cuisine label
// ─────────────────────────────────────────────
String _cuisineFromTypes(List<String> types) {
  if (types.any((t) => t.contains('indian'))) return 'Indian';
  if (types.any((t) => t.contains('chinese'))) return 'Chinese';
  if (types.any((t) => t.contains('italian') || t.contains('pizza'))) return 'Italian';
  if (types.any((t) => t.contains('thai'))) return 'Thai';
  if (types.any((t) =>
      t.contains('french') ||
      t.contains('european') ||
      t.contains('american') ||
      t.contains('steak'))) return 'Continental';
  if (types.any((t) => t.contains('cafe') || t.contains('coffee'))) return 'Café';
  if (types.any((t) => t.contains('fast_food') || t.contains('burger'))) return 'Fast Food';
  return 'Restaurant';
}

// ─────────────────────────────────────────────
// Helper — map Google priceLevel → price-range string
// ─────────────────────────────────────────────
String _priceRangeFromLevel(String? level) {
  switch (level) {
    case 'PRICE_LEVEL_INEXPENSIVE':
      return '₹';
    case 'PRICE_LEVEL_MODERATE':
      return '₹₹';
    case 'PRICE_LEVEL_EXPENSIVE':
      return '₹₹₹';
    case 'PRICE_LEVEL_VERY_EXPENSIVE':
      return '₹₹₹₹';
    default:
      return '₹₹';
  }
}

// ─────────────────────────────────────────────
// Helper — compute distance (km) between two coordinates
// ─────────────────────────────────────────────
double _haversineKm(
    double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  final dLat = _deg2rad(lat2 - lat1);
  final dLon = _deg2rad(lon2 - lon1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_deg2rad(lat1)) *
          cos(_deg2rad(lat2)) *
          sin(dLon / 2) *
          sin(dLon / 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
}

double _deg2rad(double d) => d * (pi / 180);

// ─────────────────────────────────────────────
// Convert a raw Google Places map → Restaurant model
// ─────────────────────────────────────────────
Restaurant _placeToRestaurant(
    Map<String, dynamic> place, double userLat, double userLon) {
  final id = place['id'] as String? ?? UniqueKey().toString();
  final name =
      (place['displayName'] as Map?)?['text'] as String? ?? 'Restaurant';

  final types = (place['types'] as List<dynamic>? ?? []).cast<String>();
  final cuisine = _cuisineFromTypes(types);

  final rating = (place['rating'] as num?)?.toDouble() ?? 0.0;

  // Photo URL — fall back to a generic food photo if none available
  String imageUrl =
      'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=400';
  final photos = place['photos'] as List<dynamic>?;
  if (photos != null && photos.isNotEmpty) {
    final photoName = (photos.first as Map)['name'] as String?;
    if (photoName != null) {
      imageUrl = _GooglePlacesService.buildPhotoUrl(photoName);
    }
  }

  final loc = place['location'] as Map<String, dynamic>?;
  final lat = (loc?['latitude'] as num?)?.toDouble() ?? userLat;
  final lng = (loc?['longitude'] as num?)?.toDouble() ?? userLon;
  final distanceKm = _haversineKm(userLat, userLon, lat, lng);

  final priceRange = _priceRangeFromLevel(place['priceLevel'] as String?);

  // Determine open/closed status from currentOpeningHours when available,
  // otherwise fall back to regularOpeningHours.openNow
  bool isOpen = true;
  final currentHours = place['currentOpeningHours'] as Map?;
  final regularHours = place['regularOpeningHours'] as Map?;
  if (currentHours != null && currentHours.containsKey('openNow')) {
    isOpen = currentHours['openNow'] as bool? ?? true;
  } else if (regularHours != null && regularHours.containsKey('openNow')) {
    isOpen = regularHours['openNow'] as bool? ?? true;
  }

  return Restaurant(
    id: id,
    name: name,
    cuisine: cuisine,
    rating: rating,
    distance: distanceKm,
    imageUrl: imageUrl,
    latitude: lat,
    longitude: lng,
    priceRange: priceRange,
    isOpen: isOpen,
    reservable: place['reservable'] as bool? ?? place['dineIn'] as bool? ?? true,
  );
}

// ─────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────
class DinexScreen extends StatefulWidget {
  final String initialSearchQuery;
  const DinexScreen({super.key, this.initialSearchQuery = ''});

  @override
  State<DinexScreen> createState() => _DinexScreenState();
}

class _DinexScreenState extends State<DinexScreen> {
  bool _isLoadingLocation = false;
  bool _isSearching = false;           // true while text-search API is in flight
  Position? _currentPosition;
  String _selectedCuisine = 'All';
  List<Restaurant> _nearbyRestaurants = [];     // ≤5 km, shown by default
  List<Restaurant> _searchResults = [];          // Bangalore-wide, shown while searching
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _searchDebounce;

  // ── Banner ───────────────────────────────────────────────────────────
  final PageController _bannerCtrl = PageController(viewportFraction: 1.0);
  int _bannerIndex = 0;
  Timer? _bannerTimer;

  // Scroll controller + per-card keys for auto-scroll from dashboard
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _restaurantKeys = {};
  bool _bannerUserScrolling = false;
  final List<String> _bannerImages = [
    'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=800',
    'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=800',
    'https://images.unsplash.com/photo-1559339352-11d035aa65de?w=800',
  ];

  // ── Cuisine chips (unchanged) ────────────────────────────────────────
  final List<Map<String, String>> _cuisines = [
    {'name': 'All', 'emoji': '🍽️'},
    {'name': 'Indian', 'emoji': '🍛'},
    {'name': 'Chinese', 'emoji': '🥢'},
    {'name': 'Italian', 'emoji': '🍝'},
    {'name': 'Continental', 'emoji': '🥗'},
    {'name': 'Thai', 'emoji': '🍜'},
  ];

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
    _startBannerAutoPlay();
    if (widget.initialSearchQuery.isNotEmpty) {
      _searchController.text = widget.initialSearchQuery;
      _searchQuery = widget.initialSearchQuery;
      _isSearching = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
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

  // ── Location permission flow (unchanged) ─────────────────────────────
  Future<void> _requestLocationPermission() async {
    setState(() => _isLoadingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationServiceDialog();
        setState(() => _isLoadingLocation = false);
        return;
      }

      var status = await Permission.location.request();

      if (status.isGranted) {
        await _getCurrentLocation();
      } else if (status.isDenied) {
        _showPermissionDeniedDialog();
      } else if (status.isPermanentlyDenied) {
        _showPermissionPermanentlyDeniedDialog();
      }
    } catch (e) {
      debugPrint('Error requesting location: $e');
    }

    setState(() => _isLoadingLocation = false);
  }

  // ── Fetch real location then call Places API ─────────────────────────
  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _isLoadingLocation = true; // keep spinner while fetching places
      });

      // ── Fetch real restaurants from Google Places API ────────────────
      final places = await _GooglePlacesService.searchAllNearby(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      final restaurants = places
          // ✅ Keep only genuine dine-in restaurants (no shops, petrol bunks, etc.)
          .where(_GooglePlacesService.isValidDineInRestaurant)
          .map((p) =>
              _placeToRestaurant(p, position.latitude, position.longitude))
          // ✅ Hard enforce 5 km radius (API radius is a hint, not a guarantee)
          .where((r) => r.distance <= 5.0)
          .toList();

      // Sort by distance — same behaviour as the original
      restaurants.sort((a, b) => a.distance.compareTo(b.distance));

      if (mounted) {
        setState(() {
          _nearbyRestaurants = restaurants;
          _isLoadingLocation = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✅ Found ${_nearbyRestaurants.length} restaurants with table booking within 5 km'),
            backgroundColor: AppColors.dinexPrimary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error getting location or fetching restaurants: $e');
      if (mounted) {
        setState(() => _isLoadingLocation = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Could not get location. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── Cuisine + search filter ──────────────────────────────────────────
  // When user is searching → show Bangalore-wide _searchResults (API fetched).
  // When not searching   → show _nearbyRestaurants (≤5 km, fetched on load).
  List<Restaurant> get _filteredRestaurants {
    // While search is active, show search results (already Bangalore-wide)
    if (_searchQuery.isNotEmpty) {
      if (_selectedCuisine == 'All') return _searchResults;
      return _searchResults
          .where((r) => r.cuisine == _selectedCuisine)
          .toList();
    }

    // Default view: nearby ≤5 km restaurants filtered by cuisine chip
    if (_selectedCuisine == 'All') return _nearbyRestaurants;
    return _nearbyRestaurants
        .where((r) => r.cuisine == _selectedCuisine)
        .toList();
  }

  /// Called when the user types in the search bar.
  /// Debounces the API call and fetches Bangalore-wide results.
  void _onSearchChanged(String value) {
    final query = value.trim();
    setState(() => _searchQuery = query);

    _searchDebounce?.cancel();

    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 600), () async {
      if (!mounted) return;
      setState(() => _isSearching = true);

      try {
        final pos = _currentPosition;
        final places = await _GooglePlacesService.searchByText(
          query: query,
          userLat: pos?.latitude ?? 12.9716,   // Bangalore centre fallback
          userLon: pos?.longitude ?? 77.5946,
        );

        final results = places
            .where(_GooglePlacesService.isValidDineInRestaurant)
            .map((p) => _placeToRestaurant(
                  p,
                  pos?.latitude ?? 12.9716,
                  pos?.longitude ?? 77.5946,
                ))
            .toList();

        // Sort by distance so closest results appear first
        results.sort((a, b) => a.distance.compareTo(b.distance));

        if (mounted) {
          setState(() {
            _searchResults = results;
            _isSearching = false;
          });
        }
      } catch (e) {
        debugPrint('Text search error: $e');
        if (mounted) setState(() => _isSearching = false);
      }
    });
  }

  // ── Dialogs (unchanged) ──────────────────────────────────────────────
  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Services Disabled'),
        content: const Text(
            'Please enable location services to find restaurants near you.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Geolocator.openLocationSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission Required'),
        content: const Text(
            'We need your location to show nearby restaurants. Please grant location permission.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _requestLocationPermission();
            },
            child: const Text('Grant Permission'),
          ),
        ],
      ),
    );
  }

  void _showPermissionPermanentlyDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Permanently Denied'),
        content: const Text(
            'Location permission is permanently denied. Please enable it in app settings.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showBookingDialog(Restaurant restaurant) {
    int guests = 2;
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Book Table at ${restaurant.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${restaurant.cuisine} • ${restaurant.priceRange}',
                    style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(height: 16),
                const Text('Number of Guests',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () {
                        if (guests > 1) setDialogState(() => guests--);
                      },
                    ),
                    Text('$guests',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () {
                        if (guests < 20) setDialogState(() => guests++);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Date & Time',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: Text(
                      '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate:
                          DateTime.now().add(const Duration(days: 30)),
                    );
                    if (date != null) {
                      setDialogState(() => selectedDate = date);
                    }
                  },
                ),
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.access_time),
                  title: Text(selectedTime.format(context)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: selectedTime,
                    );
                    if (time != null) {
                      setDialogState(() => selectedTime = time);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _confirmBooking(restaurant, guests, selectedDate, selectedTime);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.dinexPrimary),
              child: const Text('Confirm Booking'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmBooking(
      Restaurant restaurant, int guests, DateTime date, TimeOfDay time) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('✅ Booking Confirmed!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Restaurant: ${restaurant.name}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Guests: $guests'),
            Text('Date: ${date.day}/${date.month}/${date.year}'),
            Text('Time: ${time.format(context)}'),
            const SizedBox(height: 16),
            const Text('You will receive a confirmation SMS shortly.'),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.dinexPrimary),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  // ── Build (unchanged UI) ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.white,
      drawer: const AppDrawer(),
      extendBodyBehindAppBar: true,
      body: Column(
        children: [
          // ── Full-bleed Hero Banner with floating header overlay ──
          SizedBox(
            height: topPadding + 220,
            child: Stack(
              children: [
                // Inline PageView — same pattern as Swadisht
                Positioned.fill(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification is ScrollStartNotification &&
                          notification.dragDetails != null) {
                        _onBannerScrollStart();
                      } else if (notification is ScrollEndNotification) {
                        _onBannerScrollEnd();
                      }
                      return false;
                    },
                    child: PageView.builder(
                      controller: _bannerCtrl,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _bannerImages.length,
                      onPageChanged: (i) => setState(() => _bannerIndex = i),
                    itemBuilder: (_, i) => Image.network(
                      _bannerImages[i],
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.dinexPrimary.withOpacity(0.3),
                        child: const Center(child: Icon(Icons.restaurant, size: 60, color: Colors.white)),
                      ),
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          color: AppColors.dinexPrimary.withOpacity(0.2),
                          child: const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                        );
                      },
                    ),
                  ),
                  ),
                ),
                // Dots
                Positioned(
                  bottom: 68,
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
                        color: _bannerIndex == i ? Colors.white : Colors.white.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    )),
                  ),
                ),
                // Dark gradient so text is readable — IgnorePointer so swipe passes through
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.55),
                            Colors.black.withOpacity(0.15),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.45, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
                // Floating title + location icon
                Positioned(
                  top: topPadding + 8,
                  left: 4,
                  right: 12,
                  child: Row(
                    children: [
                      Builder(
                        builder: (ctx) => IconButton(
                          icon: const Icon(Icons.menu, color: Colors.white, size: 26),
                          onPressed: () => Scaffold.of(ctx).openDrawer(),
                        ),
                      ),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Dinex', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
                            Text('Book your table 🍽️', style: TextStyle(fontSize: 11, color: Colors.white70)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.my_location, color: Colors.white, size: 22),
                        onPressed: _requestLocationPermission,
                      ),
                    ],
                  ),
                ),
                // Floating search bar at bottom of hero
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      style: const TextStyle(fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'Search restaurants across Bangalore...',
                        hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                        prefixIcon: Icon(Icons.search, color: Colors.grey.shade600, size: 22),
                        suffixIcon: _isSearching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.dinexPrimary)),
                              )
                            : _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: Icon(Icons.close, color: Colors.grey.shade600, size: 20),
                                    onPressed: () {
                                      _searchController.clear();
                                      _onSearchChanged('');
                                      FocusScope.of(context).unfocus();
                                    },
                                  )
                                : Icon(Icons.mic, color: Colors.grey.shade600, size: 22),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Scrollable Body ──────────────────────────────────────
          Expanded(
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [

                  // Location Status chip
                  if (_currentPosition != null)
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.dinexLight.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color:
                                  AppColors.dinexPrimary.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.location_on,
                                color: AppColors.dinexPrimary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Your Location',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  Text(
                                    'Lat: ${_currentPosition!.latitude.toStringAsFixed(4)}, '
                                    'Long: ${_currentPosition!.longitude.toStringAsFixed(4)}',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600),
                                  ),
                                  Text(
                                    _searchQuery.isNotEmpty
                                        ? 'Showing ${_filteredRestaurants.length} results across Bangalore'
                                        : 'Showing ${_nearbyRestaurants.length} restaurants with table booking within 5 km',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.dinexPrimary,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Cuisine filter chips
                  if (_nearbyRestaurants.isNotEmpty)
                    SliverToBoxAdapter(
                      child: CategoryChips(
                        categories: _cuisines,
                        selectedCategory: _selectedCuisine,
                        onCategorySelected: (cuisine) =>
                            setState(() => _selectedCuisine = cuisine),
                        selectedColor: AppColors.dinexPrimary,
                      ),
                    ),

                  // ── States: loading / no-location / searching / empty / list ──
                  if (_isLoadingLocation)
                    const SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                                color: AppColors.dinexPrimary),
                            SizedBox(height: 16),
                            Text('Finding your location...'),
                          ],
                        ),
                      ),
                    )
                  else if (_currentPosition == null)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.location_off,
                                size: 80, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            const Text('Location access required',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                'Allow location access to discover amazing restaurants near you',
                                textAlign: TextAlign.center,
                                style:
                                    TextStyle(color: Colors.grey.shade600),
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _requestLocationPermission,
                              icon: const Icon(Icons.location_on),
                              label: const Text('Enable Location'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.dinexPrimary,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 32, vertical: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (_isSearching)
                    const SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                                color: AppColors.dinexPrimary),
                            SizedBox(height: 16),
                            Text('Searching across Bangalore...'),
                          ],
                        ),
                      ),
                    )
                  else if (_filteredRestaurants.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.restaurant_menu,
                                size: 80, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text(
                                _searchQuery.isNotEmpty
                                    ? 'No restaurants with table booking\nfound for "$_searchQuery"'
                                    : 'No $_selectedCuisine restaurants\nwith table booking within 5 km',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 18)),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                                setState(() {
                                  _selectedCuisine = 'All';
                                });
                              },
                              child: const Text('Clear filters'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final restaurant = _filteredRestaurants[index];
                            _restaurantKeys[index] ??= GlobalKey();
                            return KeyedSubtree(
                              key: _restaurantKeys[index],
                              child: _RestaurantCard(
                                restaurant: restaurant,
                                onBook: () => _showBookingDialog(restaurant),
                              ),
                            );
                          },
                          childCount: _filteredRestaurants.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
    );
  }
}

// ─────────────────────────────────────────────
// Restaurant model (unchanged)
// ─────────────────────────────────────────────
class Restaurant {
  final String id;
  final String name;
  final String cuisine;
  final double rating;
  final double distance;
  final String imageUrl;
  final double latitude;
  final double longitude;
  final String priceRange;
  final bool isOpen;
  final bool reservable;

  Restaurant({
    required this.id,
    required this.name,
    required this.cuisine,
    required this.rating,
    required this.distance,
    required this.imageUrl,
    required this.latitude,
    required this.longitude,
    required this.priceRange,
    required this.isOpen,
    this.reservable = true,
  });
}

// ─────────────────────────────────────────────
// Restaurant card widget (unchanged)
// ─────────────────────────────────────────────
class _RestaurantCard extends StatelessWidget {
  final Restaurant restaurant;
  final VoidCallback onBook;

  const _RestaurantCard({required this.restaurant, required this.onBook});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Restaurant Image
          Stack(
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.network(
                  restaurant.imageUrl,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 160,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.restaurant, size: 60),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: restaurant.isOpen ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    restaurant.isOpen ? 'OPEN' : 'CLOSED',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),

          // Restaurant Info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        restaurant.name,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.black87),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star,
                              color: Colors.green, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            restaurant.rating.toStringAsFixed(1),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.restaurant_menu,
                        size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(restaurant.cuisine,
                        style: TextStyle(color: Colors.grey.shade700)),
                    const SizedBox(width: 12),
                    Icon(Icons.currency_rupee,
                        size: 16, color: Colors.grey.shade600),
                    Text(restaurant.priceRange,
                        style: TextStyle(color: Colors.grey.shade700)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.location_on,
                        size: 16, color: AppColors.dinexPrimary),
                    const SizedBox(width: 4),
                    Text(
                      '${restaurant.distance.toStringAsFixed(1)} km away',
                      style: const TextStyle(
                          color: AppColors.dinexPrimary,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: restaurant.isOpen ? onBook : null,
                    icon: const Icon(Icons.event_seat, size: 18),
                    label: Text(restaurant.isOpen
                        ? 'Book Table'
                        : 'Currently Closed'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.dinexPrimary,
                      disabledBackgroundColor: Colors.grey.shade300,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}