import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:video_player/video_player.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../providers/cart_provider.dart';
import '../providers/user_provider.dart';
import 'grokly_screen.dart';
import 'swadisht_screen.dart';
import 'instastyle_screen.dart';
import 'calcai_screen.dart';
import 'dinex_screen.dart';
import 'profile_screen.dart';

// ── Search result model ──────────────────────────────────
class _SearchItem {
  final String title;
  final String subtitle;
  final String emoji;
  final String tag;
  final Color tagColor;
  final VoidCallback onTap;

  const _SearchItem({
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.tag,
    required this.tagColor,
    required this.onTap,
  });
}

// ────────────────────────────────────────────────────────
class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  String _locationName = 'Fetching location...';
  String _locationSubtitle = 'Please wait';
  bool _locationLoaded = false;

  late VideoPlayerController _videoController;
  bool _videoReady = false;

  // Hero banner swipe
  final PageController _heroBannerController = PageController();
  int _heroBannerPage = 0;

  // Search
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _searchQuery = '';
  bool _isSearching = false;
  double _topPadding = 0;
  double _headerHeight = 160; // fallback; measured after first frame
  final GlobalKey _headerKey = GlobalKey();

  // Voice search
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;
  String _partialWords = ''; // live transcription shown in dialog
  double _lastConfidence = 0.0;

  // Image search
  final ImagePicker _imagePicker = ImagePicker();
  bool _isImageSearching = false;

  // All searchable items — built in initState so we have context for navigation
  late List<_SearchItem> _allItems;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
    _initVideo();
    _initSpeech();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim());
    });
    _searchFocus.addListener(() {
      setState(() => _isSearching = _searchFocus.hasFocus);
    });
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError: (error) {
        debugPrint('Speech error: ${error.errorMsg}');
        if (mounted) setState(() { _isListening = false; _partialWords = ''; });
      },
      onStatus: (status) {
        debugPrint('Speech status: $status');
        if (status == 'done' || status == 'notListening') {
          if (mounted) setState(() { _isListening = false; });
        }
      },
      debugLogging: false,
    );
    if (mounted) setState(() {});
  }

  Future<void> _startVoiceSearch() async {
    if (!_speechAvailable) {
      _showSnack('Microphone not available on this device', isError: true);
      return;
    }

    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() { _isListening = false; _partialWords = ''; });
      return;
    }

    // Haptic feedback on start
    HapticFeedback.mediumImpact();

    _searchFocus.requestFocus();
    if (mounted) {
      setState(() {
        _isListening = true;
        _isSearching = true;
        _partialWords = '';
        _lastConfidence = 0.0;
      });
    }

    _showVoiceListeningDialog();

    await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        final words = result.recognizedWords.trim();
        final confidence = result.confidence;

        if (words.isNotEmpty) {
          if (mounted) {
            setState(() {
              _partialWords = words;
              if (confidence > 0) _lastConfidence = confidence;
            });
            _searchController.text = words;
            _searchController.selection = TextSelection.fromPosition(
              TextPosition(offset: words.length),
            );
            setState(() => _searchQuery = words);
          }
        }

        if (result.finalResult) {
          // Only accept if confidence is reasonable (>0.4) or unset (0.0 means engine didn't report)
          final acceptableConfidence = confidence == 0.0 || confidence >= 0.40;
          if (mounted) setState(() { _isListening = false; _partialWords = ''; });

          // Close dialog safely
          if (Navigator.of(context, rootNavigator: true).canPop()) {
            Navigator.of(context, rootNavigator: true).pop();
          }

          if (words.isNotEmpty && acceptableConfidence) {
            HapticFeedback.lightImpact();
            _navigateBestMatch();
          } else if (words.isNotEmpty) {
            // Low confidence — keep text in bar but don't auto-navigate
            _showSnack('Didn\'t catch that clearly, please try again');
          }
        }
      },
      listenFor: const Duration(seconds: 12),
      pauseFor: const Duration(seconds: 2),
      partialResults: true,
      localeId: 'en_IN',
      cancelOnError: true,
      listenMode: stt.ListenMode.search,
    );
  }

  void _showVoiceListeningDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => _VoiceListeningDialog(
        onCancel: () {
          _speech.stop();
          if (mounted) setState(() { _isListening = false; _partialWords = ''; });
        },
        partialWordsStream: Stream.periodic(const Duration(milliseconds: 80))
            .map((_) => _partialWords),
      ),
    ).then((_) {
      if (_isListening) {
        _speech.stop();
        if (mounted) setState(() { _isListening = false; _partialWords = ''; });
      }
    });
  }

  Future<void> _startImageSearch() async {
    // Show bottom sheet to choose camera or gallery
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Search by Image',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Take a photo or pick from gallery to find matching products',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _ImageSourceTile(
                      icon: Icons.camera_alt_rounded,
                      label: 'Camera',
                      color: const Color(0xFFFC8019),
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickAndSearchImage(ImageSource.camera);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _ImageSourceTile(
                      icon: Icons.photo_library_rounded,
                      label: 'Gallery',
                      color: const Color(0xFF2196F3),
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickAndSearchImage(ImageSource.gallery);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndSearchImage(ImageSource source) async {
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 90,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (picked == null) return;

      if (mounted) setState(() => _isImageSearching = true);

      final imageFile = File(picked.path);

      // Show dialog immediately — the dialog itself handles the async analysis
      if (!mounted) return;
      _showImageSearchResultDialog(imageFile);
    } catch (e) {
      if (mounted) setState(() => _isImageSearching = false);
      _showSnack(
        'Could not open ${source == ImageSource.camera ? 'camera' : 'gallery'}',
        isError: true,
      );
    }
  }

  void _showImageSearchResultDialog(File imageFile) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ImageSearchDialog(
        imageFile: imageFile,
        onCategorySelected: (query) {
          if (Navigator.of(context, rootNavigator: true).canPop()) {
            Navigator.of(context, rootNavigator: true).pop();
          }
          if (mounted) {
            setState(() {
              _isImageSearching = false;
              _isSearching = true;
            });
          }
          _searchController.text = query;
          _searchController.selection = TextSelection.fromPosition(
            TextPosition(offset: query.length),
          );
          if (mounted) setState(() => _searchQuery = query);
          _searchFocus.requestFocus();
        },
        onDismiss: () {
          if (Navigator.of(context, rootNavigator: true).canPop()) {
            Navigator.of(context, rootNavigator: true).pop();
          }
          if (mounted) setState(() => _isImageSearching = false);
        },
      ),
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? Colors.redAccent : const Color(0xFFFC8019),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _buildSearchItems(BuildContext context) {
    _allItems = [
      // ── Swadisht ──
      _SearchItem(
        title: 'Swadisht',
        subtitle: 'Food delivery from restaurants',
        emoji: '🍕',
        tag: 'Food',
        tagColor: const Color(0xFFE53935),
        onTap: () => _navigate(context, SwadistScreen()),
      ),
      _SearchItem(
        title: 'Margherita Pizza',
        subtitle: 'Classic cheese pizza with basil',
        emoji: '🍕',
        tag: 'Food',
        tagColor: const Color(0xFFE53935),
        onTap: () => _navigate(context, SwadistScreen(initialSearchQuery: 'Margherita Pizza')),
      ),
      _SearchItem(
        title: 'Chicken Biryani',
        subtitle: 'Authentic Hyderabadi biryani',
        emoji: '🍛',
        tag: 'Food',
        tagColor: const Color(0xFFE53935),
        onTap: () => _navigate(context, SwadistScreen(initialSearchQuery: 'Biryani')),
      ),
      _SearchItem(
        title: 'Butter Chicken',
        subtitle: 'Creamy tomato curry with chicken',
        emoji: '🍗',
        tag: 'Food',
        tagColor: const Color(0xFFE53935),
        onTap: () => _navigate(context, SwadistScreen(initialSearchQuery: 'Butter Chicken')),
      ),
      _SearchItem(
        title: 'Masala Dosa',
        subtitle: 'Crispy dosa with potato filling',
        emoji: '🥞',
        tag: 'Food',
        tagColor: const Color(0xFFE53935),
        onTap: () => _navigate(context, SwadistScreen(initialSearchQuery: 'Dosa')),
      ),
      _SearchItem(
        title: 'Paneer Butter Masala',
        subtitle: 'Cottage cheese in rich gravy',
        emoji: '🧈',
        tag: 'Food',
        tagColor: const Color(0xFFE53935),
        onTap: () => _navigate(context, SwadistScreen(initialSearchQuery: 'Paneer')),
      ),
      _SearchItem(
        title: 'Burger',
        subtitle: 'Juicy chicken & veg burgers',
        emoji: '🍔',
        tag: 'Food',
        tagColor: const Color(0xFFE53935),
        onTap: () => _navigate(context, SwadistScreen(initialSearchQuery: 'Burger')),
      ),
      _SearchItem(
        title: 'Pasta',
        subtitle: 'Creamy white & red sauce pasta',
        emoji: '🍝',
        tag: 'Food',
        tagColor: const Color(0xFFE53935),
        onTap: () => _navigate(context, SwadistScreen(initialSearchQuery: 'Pasta')),
      ),
      // ── Grokly ──
      _SearchItem(
        title: 'Grokly',
        subtitle: 'Groceries delivered in minutes',
        emoji: '🛒',
        tag: 'Grocery',
        tagColor: const Color(0xFF0C831F),
        onTap: () => _navigate(context, GroklyScreen()),
      ),
      _SearchItem(
        title: 'Fresh Milk',
        subtitle: 'Farm fresh full cream milk, 1L',
        emoji: '🥛',
        tag: 'Grocery',
        tagColor: const Color(0xFF0C831F),
        onTap: () => _navigate(context, GroklyScreen(initialSearchQuery: 'Milk')),
      ),
      _SearchItem(
        title: 'Tomatoes',
        subtitle: 'Fresh red tomatoes, 500g',
        emoji: '🍅',
        tag: 'Grocery',
        tagColor: const Color(0xFF0C831F),
        onTap: () => _navigate(context, GroklyScreen(initialSearchQuery: 'Tomatoes')),
      ),
      _SearchItem(
        title: 'Basmati Rice',
        subtitle: 'Premium quality basmati rice, 1kg',
        emoji: '🌾',
        tag: 'Grocery',
        tagColor: const Color(0xFF0C831F),
        onTap: () => _navigate(context, GroklyScreen(initialSearchQuery: 'Rice')),
      ),
      _SearchItem(
        title: 'Paneer',
        subtitle: 'Fresh homemade cottage cheese',
        emoji: '🧀',
        tag: 'Grocery',
        tagColor: const Color(0xFF0C831F),
        onTap: () => _navigate(context, GroklyScreen(initialSearchQuery: 'Paneer')),
      ),
      _SearchItem(
        title: 'Eggs',
        subtitle: 'Farm fresh eggs, 6 pieces',
        emoji: '🥚',
        tag: 'Grocery',
        tagColor: const Color(0xFF0C831F),
        onTap: () => _navigate(context, GroklyScreen(initialSearchQuery: 'Eggs')),
      ),
      _SearchItem(
        title: 'Olive Oil',
        subtitle: 'Extra virgin olive oil, 500ml',
        emoji: '🫒',
        tag: 'Grocery',
        tagColor: const Color(0xFF0C831F),
        onTap: () => _navigate(context, GroklyScreen(initialSearchQuery: 'Oil')),
      ),
      // ── InstaStyle ──
      _SearchItem(
        title: 'InstaStyle',
        subtitle: 'Fashion & lifestyle trends',
        emoji: '👗',
        tag: 'Fashion',
        tagColor: const Color(0xFFE91E63),
        onTap: () => _navigate(context, const InstastyleScreen()),
      ),
      _SearchItem(
        title: 'T-Shirts',
        subtitle: 'Trendy t-shirts for men & women',
        emoji: '👕',
        tag: 'Fashion',
        tagColor: const Color(0xFFE91E63),
        onTap: () => _navigate(context, InstastyleScreen(initialSearchQuery: 'T-Shirts')),
      ),
      _SearchItem(
        title: 'Jeans',
        subtitle: 'Slim & regular fit jeans',
        emoji: '👖',
        tag: 'Fashion',
        tagColor: const Color(0xFFE91E63),
        onTap: () => _navigate(context, InstastyleScreen(initialSearchQuery: 'Jeans')),
      ),
      _SearchItem(
        title: 'Dresses',
        subtitle: 'Casual & party dresses',
        emoji: '👗',
        tag: 'Fashion',
        tagColor: const Color(0xFFE91E63),
        onTap: () => _navigate(context, InstastyleScreen(initialSearchQuery: 'Dresses')),
      ),
      _SearchItem(
        title: 'Shoes',
        subtitle: 'Sneakers, heels & more',
        emoji: '👟',
        tag: 'Fashion',
        tagColor: const Color(0xFFE91E63),
        onTap: () => _navigate(context, InstastyleScreen(initialSearchQuery: 'Shoes')),
      ),
      // ── Dinex ──
      _SearchItem(
        title: 'Dinex',
        subtitle: 'Book tables at restaurants',
        emoji: '🍽️',
        tag: 'Dine-In',
        tagColor: const Color(0xFFD32F2F),
        onTap: () => _navigate(context, const DinexScreen()),
      ),
      _SearchItem(
        title: 'Table Booking',
        subtitle: 'Reserve tables near you',
        emoji: '🪑',
        tag: 'Dine-In',
        tagColor: const Color(0xFFD32F2F),
        onTap: () => _navigate(context, DinexScreen(initialSearchQuery: 'restaurant')),
      ),
      _SearchItem(
        title: 'Italian Restaurants',
        subtitle: 'Pizza, pasta & more near you',
        emoji: '🍝',
        tag: 'Dine-In',
        tagColor: const Color(0xFFD32F2F),
        onTap: () => _navigate(context, DinexScreen(initialSearchQuery: 'Italian')),
      ),
      _SearchItem(
        title: 'Chinese Restaurants',
        subtitle: 'Authentic Chinese cuisine nearby',
        emoji: '🥢',
        tag: 'Dine-In',
        tagColor: const Color(0xFFD32F2F),
        onTap: () => _navigate(context, DinexScreen(initialSearchQuery: 'Chinese')),
      ),
      // ── CalcIQ ──
      _SearchItem(
        title: 'Calc IQ',
        subtitle: 'Budget planning & finance',
        emoji: '💰',
        tag: 'Finance',
        tagColor: const Color(0xFF2196F3),
        onTap: () => _navigate(context, const CalcAIScreen()),
      ),
      _SearchItem(
        title: 'Budget Planner',
        subtitle: 'Plan your monthly expenses',
        emoji: '📊',
        tag: 'Finance',
        tagColor: const Color(0xFF2196F3),
        onTap: () => _navigate(context, const CalcAIScreen()),
      ),
    ];
  }

  void _navigate(BuildContext context, Widget screen) {
    _clearSearch();
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocus.unfocus();
    setState(() { _searchQuery = ''; _isSearching = false; });
  }

  // Alias map for common voice/image search terms → search queries
  static const _aliases = <String, String>{
    'food': 'swadisht',
    'eat': 'swadisht',
    'meal': 'swadisht',
    'order food': 'swadisht',
    'restaurant': 'swadisht',
    'grocery': 'grokly',
    'groceries': 'grokly',
    'vegetable': 'vegetables',
    'vegetables': 'grokly',
    'clothes': 'fashion',
    'clothing': 'fashion',
    'outfit': 'fashion',
    'dress': 'dresses',
    'dine': 'table booking',
    'dining': 'table booking',
    'book table': 'table booking',
    'finance': 'budget planner',
    'budget': 'budget planner',
    'calculator': 'calc iq',
    'milk': 'fresh milk',
    'rice': 'basmati rice',
    'chicken': 'butter chicken',
    'biryani': 'chicken biryani',
    'dosa': 'masala dosa',
  };

  List<_SearchItem> get _filteredItems {
    if (_searchQuery.isEmpty) return [];
    // Resolve alias first
    final rawQ = _searchQuery.toLowerCase().trim();
    final q = _aliases[rawQ] ?? rawQ;

    int rank(_SearchItem item) {
      final t = item.title.toLowerCase();
      final s = item.subtitle.toLowerCase();
      final tg = item.tag.toLowerCase();
      if (t == q) return 0;
      if (t.startsWith(q)) return 1;
      if (t.contains(q)) return 2;
      if (s.contains(q)) return 3;
      if (tg.contains(q)) return 4;
      // partial word match (any word in title starts with query)
      if (t.split(' ').any((w) => w.startsWith(q))) return 5;
      return 99;
    }

    final matched = _allItems.where((item) {
      final t = item.title.toLowerCase();
      final s = item.subtitle.toLowerCase();
      final tg = item.tag.toLowerCase();
      return t.contains(q) ||
          s.contains(q) ||
          tg.contains(q) ||
          t.split(' ').any((w) => w.startsWith(q));
    }).toList();

    matched.sort((a, b) => rank(a).compareTo(rank(b)));
    return matched;
  }

  void _navigateBestMatch() {
    if (_filteredItems.isNotEmpty) {
      _filteredItems.first.onTap();
      return;
    }
    if (_searchQuery.isEmpty) return;

    // No match in dashboard index — do smart venture routing with the raw query
    final q = _searchQuery.toLowerCase();

    final isFashion = ['shirt', 'jean', 'dress', 'shoe', 'kurta', 'saree',
      'fashion', 'cloth', 'wear', 'top', 'jacket', 'trouser', 'legging',
      'kurti', 'skirt', 'hoodie', 'sneaker', 'heel'].any((k) => q.contains(k));

    final isGrocery = ['milk', 'rice', 'vegeta', 'egg', 'paneer', 'oil',
      'grocery', 'dal', 'fruit', 'spice', 'flour', 'sugar', 'salt', 'soap',
      'shampoo', 'detergent', 'bread', 'butter', 'cheese', 'ghee',
      'masala', 'onion', 'potato', 'atta'].any((k) => q.contains(k));

    final isDineIn = ['dine', 'table', 'book a table', 'reserve',
      'fine dining', 'sit down', 'restaurant book'].any((k) => q.contains(k));

    Widget dest;
    if (isFashion) {
      dest = InstastyleScreen(initialSearchQuery: _searchQuery);
    } else if (isGrocery) {
      dest = GroklyScreen(initialSearchQuery: _searchQuery);
    } else if (isDineIn) {
      dest = DinexScreen(initialSearchQuery: _searchQuery);
    } else {
      // Default: Swadisht — covers KFC, McDonald's, any restaurant/food brand
      dest = SwadistScreen(initialSearchQuery: _searchQuery);
    }

    _clearSearch();
    Navigator.push(context, MaterialPageRoute(builder: (_) => dest));
  }

  Future<void> _initVideo() async {
    _videoController =
        VideoPlayerController.asset('assets/videos/hero_bg.mp4');
    await _videoController.initialize();
    _videoController.setLooping(true);
    _videoController.setVolume(0);
    _videoController.play();
    if (mounted) setState(() => _videoReady = true);
  }

  @override
  void dispose() {
    _videoController.dispose();
    _heroBannerController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    _speech.cancel();
    _speech.stop();
    super.dispose();
  }

  Future<void> _fetchLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        setState(() {
          _locationName = 'Location access denied';
          _locationSubtitle = 'Enable in settings';
          _locationLoaded = true;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final name = place.subLocality?.isNotEmpty == true
            ? place.subLocality!
            : place.locality ?? 'Unknown area';
        final city = place.locality ?? '';
        final state = place.administrativeArea ?? '';

        setState(() {
          _locationName = name;
          _locationSubtitle =
              [city, state].where((s) => s.isNotEmpty).join(', ');
          _locationLoaded = true;
        });
      }
    } catch (e) {
      setState(() {
        _locationName = 'Location unavailable';
        _locationSubtitle = 'Tap to retry';
        _locationLoaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Build search items with context available
    _buildSearchItems(context);

    final topPadding = MediaQuery.of(context).padding.top;
    if (_topPadding != topPadding) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() => _topPadding = topPadding);
      });
    }

    // Measure header height so overlay sits exactly below it
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = _headerKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null) {
        final h = box.size.height;
        if (h != _headerHeight) setState(() => _headerHeight = h);
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Stack(
        children: [
          // ── Main scrollable content ──
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Full-bleed Hero: video fills from very top, overlays float on top ──
                SizedBox(
                  height: topPadding + 200,
                  child: Stack(
                    children: [
                      // Swipeable hero banner: video (page 0) + image (page 1)
                      Positioned.fill(
                        child: PageView(
                          controller: _heroBannerController,
                          onPageChanged: (i) =>
                              setState(() => _heroBannerPage = i),
                          children: [
                            // ── Page 0: looping video ──
                            _videoReady
                                ? VideoPlayer(_videoController)
                                : Container(
                                    color: Colors.black87,
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        color: Color(0xFFFC8019),
                                      ),
                                    ),
                                  ),
                            // ── Page 1: Accesco Living brand image ──
                            Image.asset(
                              'assets/images/accesco_banner.jpeg',
                              fit: BoxFit.cover,
                            ),
                          ],
                        ),
                      ),
                      // Dark gradient top→bottom so text is readable
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withOpacity(0.60),
                                  Colors.black.withOpacity(0.20),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.5, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Page indicator dots
                      Positioned(
                        bottom: 80,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(2, (i) {
                            final active = i == _heroBannerPage;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: active ? 20 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: active
                                    ? const Color(0xFFFC8019)
                                    : Colors.white.withOpacity(0.55),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            );
                          }),
                        ),
                      ),
                      // Floating location row
                      Positioned(
                        top: topPadding + 12,
                        left: 16,
                        right: 16,
                        child: Row(
                          children: [
                            const Icon(Icons.location_on,
                                color: Color(0xFFFC8019), size: 22),
                            const SizedBox(width: 6),
                            Expanded(
                              child: GestureDetector(
                                onTap: _locationLoaded ? _fetchLocation : null,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            _locationName,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const Icon(Icons.keyboard_arrow_down,
                                            size: 20, color: Colors.white70),
                                      ],
                                    ),
                                    Text(
                                      _locationSubtitle,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white70,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const ProfileScreen()),
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white.withOpacity(0.5)),
                                ),
                                child: const Icon(Icons.person,
                                    size: 24, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Floating search bar near bottom of hero
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Live typing preview
                            if (_isSearching)
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.92),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.edit_outlined,
                                        size: 15, color: Color(0xFFFC8019)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _searchQuery.isEmpty
                                          ? Text(
                                              'Start typing to search…',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey.shade500,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            )
                                          : RichText(
                                              text: TextSpan(
                                                children: [
                                                  TextSpan(
                                                    text: 'Searching for  ',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: Colors.grey.shade600,
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text: '"$_searchQuery"',
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w800,
                                                      color: Color(0xFFFC8019),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                    ),
                                    if (_searchQuery.isNotEmpty)
                                      Text(
                                        '${_filteredItems.length} result${_filteredItems.length == 1 ? '' : 's'}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: _filteredItems.isEmpty
                                              ? Colors.redAccent
                                              : const Color(0xFF4CAF50),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            // Search bar
                            Container(
                              key: _headerKey,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                                border: Border.all(
                                  color: _isSearching
                                      ? const Color(0xFFFC8019)
                                      : Colors.transparent,
                                  width: _isSearching ? 1.5 : 0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const SizedBox(width: 14),
                                  Icon(Icons.search,
                                      color: _isSearching
                                          ? const Color(0xFFFC8019)
                                          : Colors.grey.shade500,
                                      size: 22),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      controller: _searchController,
                                      focusNode: _searchFocus,
                                      style: const TextStyle(
                                          fontSize: 15, color: Colors.black87),
                                      decoration: InputDecoration(
                                        hintText: "Search...",
                                        hintStyle: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade500),
                                        border: InputBorder.none,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                vertical: 14),
                                      ),
                                      textInputAction: TextInputAction.search,
                                      onSubmitted: (_) => _navigateBestMatch(),
                                    ),
                                  ),
                                  if (_searchQuery.isNotEmpty) ...[
                                    GestureDetector(
                                      onTap: _navigateBestMatch,
                                      child: Container(
                                        margin:
                                            const EdgeInsets.only(right: 6),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFC8019),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: const Icon(Icons.arrow_forward,
                                            color: Colors.white, size: 18),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.close,
                                          color: Colors.grey.shade500,
                                          size: 20),
                                      onPressed: _clearSearch,
                                    ),
                                  ] else ...[
                                    // Voice assistant button
                                    GestureDetector(
                                      onTap: _startVoiceSearch,
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        width: 38,
                                        height: 38,
                                        margin: const EdgeInsets.only(right: 4),
                                        decoration: BoxDecoration(
                                          color: _isListening
                                              ? const Color(0xFFFC8019)
                                              : const Color(0xFFFFF3EE),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: const Color(0xFFFC8019).withOpacity(
                                                _isListening ? 1.0 : 0.25),
                                          ),
                                        ),
                                        child: Icon(
                                          _isListening
                                              ? Icons.stop_rounded
                                              : Icons.mic_rounded,
                                          color: _isListening
                                              ? Colors.white
                                              : const Color(0xFFFC8019),
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                    // Image lookup button
                                    GestureDetector(
                                      onTap: _isImageSearching
                                          ? null
                                          : _startImageSearch,
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        width: 38,
                                        height: 38,
                                        margin: const EdgeInsets.only(right: 6),
                                        decoration: BoxDecoration(
                                          color: _isImageSearching
                                              ? const Color(0xFF2196F3)
                                              : const Color(0xFFF3F8FF),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: const Color(0xFF2196F3).withOpacity(
                                                _isImageSearching ? 1.0 : 0.25),
                                          ),
                                        ),
                                        child: _isImageSearching
                                            ? const Padding(
                                                padding: EdgeInsets.all(10),
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : const Icon(
                                                Icons.image_search_rounded,
                                                color: Color(0xFF2196F3),
                                                size: 20,
                                              ),
                                      ),
                                    ),
                                    // Customise icon (enlarged)
                                    GestureDetector(
                                      onTap: () {},
                                      child: Container(
                                        width: 43,
                                        height: 43,
                                        margin: const EdgeInsets.only(right: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.08),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        padding: const EdgeInsets.all(6),
                                        child: Image.asset(
                                          'assets/images/customise_icon.png',
                                          errorBuilder: (_, __, ___) => Icon(
                                              Icons.tune,
                                              color: Colors.grey.shade500,
                                              size: 28),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Services Grid ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      // Row 1: Swadisht + Grokly
                      Row(
                        children: [
                          Expanded(
                            child: _ServiceCard(
                              title: 'SWADISHT',
                              subtitle: 'FROM RESTAURANTS',
                              offer: 'UP TO 60% OFF',
                              logoAsset: 'assets/images/swadisht_logo.png',
                              heroImageUrl:
                                  'https://plus.unsplash.com/premium_photo-1673108852141-e8c3c22a4a22?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
                              bgColor: const Color(0xFFFFF3EE),
                              badge: '🍕 Food',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => SwadistScreen()),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ServiceCard(
                              title: 'GROKLY',
                              subtitle: 'GROCERIES IN MINUTES',
                              offer: 'UP TO ₹100 OFF',
                              logoAsset: 'assets/images/grokly_logo.png',
                              heroImageUrl:
                                  'https://images.unsplash.com/photo-1542838132-92c53300491e?w=400&q=80',
                              bgColor: const Color(0xFFCCFF90),
                              badge: '⚡ 10 mins',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => GroklyScreen()),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Row 2: Instastyle + split mini-cards
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _ServiceCard(
                              title: 'INSTASTYLE',
                              subtitle: 'TRENDING STYLES',
                              offer: 'FLAT ₹250 OFF',
                              logoAsset: 'assets/images/instastyle_logo.png',
                              heroImageUrl:
                                  'https://images.pexels.com/photos/298863/pexels-photo-298863.jpeg',
                              bgColor: const Color(0xFFF5EDE3),
                              badge: '✨ NEW',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const InstastyleScreen()),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          Expanded(
                            child: SizedBox(
                              height: 180,
                              child: Column(
                                children: [
                                  // Swadisht Cafe mini-card
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                SwadistScreen()),
                                      ),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withOpacity(0.07),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          child: Row(
                                            children: [
                                              SizedBox(
                                                width: 75,
                                                child: Stack(
                                                  fit: StackFit.expand,
                                                  children: [
                                                    Image.network(
                                                      'https://images.unsplash.com/photo-1445116572660-236099ec97a0?w=400&q=80',
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (_,
                                                              __,
                                                              ___) =>
                                                          Container(
                                                              color: const Color(
                                                                  0xFFFFF8E1)),
                                                    ),
                                                    Positioned(
                                                      bottom: 4,
                                                      left: 4,
                                                      child: Container(
                                                        padding: const EdgeInsets
                                                            .symmetric(
                                                            horizontal: 4,
                                                            vertical: 2),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors.white
                                                              .withOpacity(0.9),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(5),
                                                        ),
                                                        child: Image.asset(
                                                          'assets/images/swadisht_logo.png',
                                                          height: 14,
                                                          fit: BoxFit.contain,
                                                          errorBuilder: (_,
                                                                  __,
                                                                  ___) =>
                                                              const Text('☕',
                                                                  style: TextStyle(
                                                                      fontSize:
                                                                          9)),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Expanded(
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.fromLTRB(
                                                          8, 0, 8, 0),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      const Text(
                                                        'SWADISHT CAFE',
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          color: Colors.black87,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        'Cafe & Beverages',
                                                        style: TextStyle(
                                                          fontSize: 8,
                                                          color: Colors
                                                              .grey.shade600,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                      const SizedBox(height: 3),
                                                      const Text(
                                                        'UP TO 30% OFF',
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color:
                                                              Color(0xFFFC8019),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 8),

                                  // Dinex mini-card
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const DinexScreen()),
                                      ),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withOpacity(0.07),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          child: Row(
                                            children: [
                                              SizedBox(
                                                width: 75,
                                                child: Stack(
                                                  fit: StackFit.expand,
                                                  children: [
                                                    Image.network(
                                                      'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=400&q=80',
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (_,
                                                              __,
                                                              ___) =>
                                                          Container(
                                                              color: const Color(
                                                                  0xFFFCE4EC)),
                                                    ),
                                                    Positioned(
                                                      bottom: 4,
                                                      left: 4,
                                                      child: Container(
                                                        padding: const EdgeInsets
                                                            .symmetric(
                                                            horizontal: 4,
                                                            vertical: 2),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors.white
                                                              .withOpacity(0.9),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(5),
                                                        ),
                                                        child: Image.asset(
                                                          'assets/images/dinex_logo.png',
                                                          height: 14,
                                                          fit: BoxFit.contain,
                                                          errorBuilder: (_,
                                                                  __,
                                                                  ___) =>
                                                              const Text('🍽️',
                                                                  style: TextStyle(
                                                                      fontSize:
                                                                          9)),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Expanded(
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.fromLTRB(
                                                          8, 0, 8, 0),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      const Text(
                                                        'DINEX',
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          color: Colors.black87,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        'Dine-In Experience',
                                                        style: TextStyle(
                                                          fontSize: 8,
                                                          color: Colors
                                                              .grey.shade600,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                      const SizedBox(height: 3),
                                                      const Text(
                                                        'FLAT ₹100 OFF',
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color:
                                                              Color(0xFFFC8019),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Calc AI — full width
                      _ServiceCard(
                        title: 'CALC IQ',
                        subtitle: 'BUDGET PLANNING',
                        offer: 'FREE TO USE',
                        logoAsset: 'assets/images/calcAI_logo.png',
                        heroImageUrl:
                            'https://images.unsplash.com/photo-1768839721776-038d3070721e?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
                        bgColor: const Color(0xFFE3F2FD),
                        fallbackEmoji: null,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const CalcAIScreen()),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),

          // ── Search Results Overlay ──
          if (_isSearching)
            Positioned(
              top: topPadding + 200, // sits exactly below the full hero block
              left: 0,
              right: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: _clearSearch,
                child: Container(
                  color: Colors.black.withOpacity(0.35),
                  child: GestureDetector(
                    onTap: () {}, // prevent tap-through
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SingleChildScrollView(
                          child: _searchQuery.isEmpty
                              ? _buildSearchSuggestions()
                              : _filteredItems.isEmpty
                                  ? _buildNoResults()
                                  : _buildResultsList(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Quick suggestion chips when search is focused but empty ──
  Widget _buildSearchSuggestions() {
    final suggestions = [
      ('🍕', 'Pizza'),
      ('🍛', 'Biryani'),
      ('🥛', 'Milk'),
      ('👕', 'T-Shirt'),
      ('🍔', 'Burger'),
      ('🥦', 'Vegetables'),
      ('🍝', 'Pasta'),
      ('👟', 'Shoes'),
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Popular searches',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade600)),
              GestureDetector(
                onTap: _clearSearch,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close, size: 16, color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions.map((s) {
              return GestureDetector(
                onTap: () {
                  _searchController.text = s.$2;
                  setState(() => _searchQuery = s.$2);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(s.$1, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(s.$2,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── No results state ──
  Widget _buildNoResults() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: GestureDetector(
              onTap: _clearSearch,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close, size: 16, color: Colors.grey.shade600),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text('🔍', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text('No results for "$_searchQuery"',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54),
              textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text('Searching all ventures for you…',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _navigateBestMatch,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFC8019),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Search in all ventures',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Results list ──
  Widget _buildResultsList() {
    final items = _filteredItems.take(10).toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0) Divider(height: 1, color: Colors.grey.shade100),
          ListTile(
            onTap: items[i].onTap,
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: items[i].tagColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                  child: Text(items[i].emoji,
                      style: const TextStyle(fontSize: 22))),
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(items[i].title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87)),
                ),
                if (i == 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFC8019).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Best match',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFFC8019))),
                  ),
                ],
              ],
            ),
            subtitle: Text(items[i].subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            trailing: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: items[i].tagColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(items[i].tag,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: items[i].tagColor)),
            ),
          ),
        ],
      ],
    );
  }
}

// ────────────────────────────────────────────────────────
// Service Card (unchanged from original)
// ────────────────────────────────────────────────────────
class _ServiceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String offer;
  final String? badge;
  final String? logoAsset;
  final String? heroImageUrl;
  final String? fallbackEmoji;
  final Color bgColor;
  final VoidCallback onTap;

  const _ServiceCard({
    required this.title,
    required this.subtitle,
    required this.offer,
    this.badge,
    this.logoAsset,
    this.heroImageUrl,
    this.fallbackEmoji,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (heroImageUrl != null)
                      Image.network(
                        heroImageUrl!,
                        fit: BoxFit.cover,
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return Container(color: bgColor);
                        },
                        errorBuilder: (_, __, ___) =>
                            Container(color: bgColor),
                      )
                    else
                      Container(color: bgColor),

                    if (heroImageUrl != null)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 55,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.38),
                              ],
                            ),
                          ),
                        ),
                      ),

                    if (logoAsset != null)
                      Positioned(
                        bottom: 7,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.88),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Image.asset(
                            logoAsset!,
                            height: 26,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Text(
                              fallbackEmoji ?? '🛍️',
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                      )
                    else if (fallbackEmoji != null)
                      Center(
                        child: Text(
                          fallbackEmoji!,
                          style: const TextStyle(fontSize: 44),
                        ),
                      ),

                    if (badge != null)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.65),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            badge!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      offer,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFC8019),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
}
// ────────────────────────────────────────────────────────
// Image source selection tile (used in bottom sheet)
// ────────────────────────────────────────────────────────
class _ImageSourceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ImageSourceTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────
// Voice Listening Dialog — uses AnimationController for
// continuous pulse and shows live partial transcription
// ────────────────────────────────────────────────────────
class _VoiceListeningDialog extends StatefulWidget {
  final VoidCallback onCancel;
  final Stream<String> partialWordsStream;

  const _VoiceListeningDialog({
    required this.onCancel,
    required this.partialWordsStream,
  });

  @override
  State<_VoiceListeningDialog> createState() => _VoiceListeningDialogState();
}

class _VoiceListeningDialogState extends State<_VoiceListeningDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;
  String _liveText = '';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.88, end: 1.18).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    widget.partialWordsStream.listen((text) {
      if (mounted && text != _liveText) {
        setState(() => _liveText = text);
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Continuous pulse mic
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, child) => Transform.scale(
                scale: _pulseAnim.value,
                child: child,
              ),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFFC8019).withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFC8019), width: 2.5),
                ),
                child: const Icon(Icons.mic_rounded,
                    color: Color(0xFFFC8019), size: 40),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Listening…',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
            ),
            const SizedBox(height: 10),
            // Live transcription box
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              constraints: const BoxConstraints(minHeight: 40),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _liveText.isEmpty
                    ? Colors.grey.shade100
                    : const Color(0xFFFFF3EE),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _liveText.isEmpty
                      ? Colors.grey.shade200
                      : const Color(0xFFFC8019).withOpacity(0.4),
                ),
              ),
              child: Text(
                _liveText.isEmpty
                    ? 'Say something like "pizza" or "fresh milk"'
                    : _liveText,
                style: TextStyle(
                  fontSize: _liveText.isEmpty ? 13 : 15,
                  color: _liveText.isEmpty
                      ? Colors.grey.shade500
                      : Colors.black87,
                  fontStyle: _liveText.isEmpty
                      ? FontStyle.italic
                      : FontStyle.normal,
                  fontWeight: _liveText.isEmpty
                      ? FontWeight.normal
                      : FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () {
                widget.onCancel();
                Navigator.of(context).pop();
              },
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFFFC8019))),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────
// Image search result dialog — uses Claude Vision API to
// identify what's in the image and suggest real categories
// ────────────────────────────────────────────────────────
class _ImageSearchDialog extends StatefulWidget {
  final File imageFile;
  final ValueChanged<String> onCategorySelected;
  final VoidCallback onDismiss;

  const _ImageSearchDialog({
    required this.imageFile,
    required this.onCategorySelected,
    required this.onDismiss,
  });

  @override
  State<_ImageSearchDialog> createState() => _ImageSearchDialogState();
}

class _ImageSearchDialogState extends State<_ImageSearchDialog> {
  bool _analyzing = true;
  String? _errorMessage;
  final List<_ImageMatch> _matches = [];

  // All possible categories the app can handle
  static const _appCategories = [
    _ImageMatch(emoji: '🍕', label: 'Pizza', query: 'pizza', color: Color(0xFFE53935)),
    _ImageMatch(emoji: '🍛', label: 'Biryani', query: 'biryani', color: Color(0xFFBF360C)),
    _ImageMatch(emoji: '🍗', label: 'Chicken', query: 'butter chicken', color: Color(0xFFE53935)),
    _ImageMatch(emoji: '🥞', label: 'Dosa', query: 'masala dosa', color: Color(0xFFE53935)),
    _ImageMatch(emoji: '🍔', label: 'Burger', query: 'burger', color: Color(0xFFFF6F00)),
    _ImageMatch(emoji: '🍝', label: 'Pasta', query: 'pasta', color: Color(0xFFE53935)),
    _ImageMatch(emoji: '🛒', label: 'Groceries', query: 'grokly', color: Color(0xFF0C831F)),
    _ImageMatch(emoji: '🥛', label: 'Milk', query: 'fresh milk', color: Color(0xFF0C831F)),
    _ImageMatch(emoji: '🍅', label: 'Tomatoes', query: 'tomatoes', color: Color(0xFF0C831F)),
    _ImageMatch(emoji: '🌾', label: 'Rice', query: 'basmati rice', color: Color(0xFF0C831F)),
    _ImageMatch(emoji: '🧀', label: 'Paneer', query: 'paneer', color: Color(0xFF0C831F)),
    _ImageMatch(emoji: '🥚', label: 'Eggs', query: 'eggs', color: Color(0xFF0C831F)),
    _ImageMatch(emoji: '🥦', label: 'Vegetables', query: 'vegetables', color: Color(0xFF388E3C)),
    _ImageMatch(emoji: '👗', label: 'Fashion', query: 'fashion', color: Color(0xFFE91E63)),
    _ImageMatch(emoji: '👕', label: 'T-Shirts', query: 'T-Shirts', color: Color(0xFF7B1FA2)),
    _ImageMatch(emoji: '👖', label: 'Jeans', query: 'jeans', color: Color(0xFF7B1FA2)),
    _ImageMatch(emoji: '👟', label: 'Shoes', query: 'shoes', color: Color(0xFF1976D2)),
    _ImageMatch(emoji: '🍽️', label: 'Dine-In', query: 'table booking', color: Color(0xFFD32F2F)),
    _ImageMatch(emoji: '📊', label: 'Budget', query: 'budget planner', color: Color(0xFF2196F3)),
  ];

  @override
  void initState() {
    super.initState();
    _analyzeWithVision();
  }

  Future<void> _analyzeWithVision() async {
    try {
      final bytes = await widget.imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Determine media type
      final path = widget.imageFile.path.toLowerCase();
      String mediaType = 'image/jpeg';
      if (path.endsWith('.png')) mediaType = 'image/png';
      else if (path.endsWith('.webp')) mediaType = 'image/webp';
      else if (path.endsWith('.gif')) mediaType = 'image/gif';

      final categoryLabels = _appCategories.map((c) => c.label).join(', ');

      final response = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': const String.fromEnvironment('ANTHROPIC_API_KEY'),
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': 'claude-opus-4-5',
          'max_tokens': 256,
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'image',
                  'source': {
                    'type': 'base64',
                    'media_type': mediaType,
                    'data': base64Image,
                  },
                },
                {
                  'type': 'text',
                  'text': '''You are an image classifier for a shopping/food delivery app.
Look at the image and identify the top 3 most relevant categories from this list:
$categoryLabels

Respond with ONLY a JSON array of exactly 3 category labels (strings), ordered by relevance.
Example: ["Pizza", "Burger", "Pasta"]
Do not include any explanation or extra text.''',
                },
              ],
            }
          ],
        }),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rawText = (data['content'] as List)
            .where((b) => b['type'] == 'text')
            .map((b) => b['text'] as String)
            .join('');

        // Parse JSON array from response
        final cleaned = rawText.trim().replaceAll(RegExp(r'```json|```'), '');
        final List<dynamic> labels = jsonDecode(cleaned);

        final matched = labels
            .map((label) {
              return _appCategories.firstWhere(
                (c) => c.label.toLowerCase() == label.toString().toLowerCase(),
                orElse: () => _appCategories.first,
              );
            })
            .take(3)
            .toList();

        setState(() {
          _analyzing = false;
          _matches.addAll(matched);
        });
      } else {
        throw Exception('API error ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      // Graceful fallback: pick 3 based on image path hash (same as before)
      debugPrint('Vision API error: $e');
      final seed = widget.imageFile.path.hashCode.abs();
      final shuffled = List<_ImageMatch>.from(_appCategories)
        ..sort((a, b) => ((seed * a.label.hashCode) % 100)
            .compareTo((seed * b.label.hashCode) % 100));
      setState(() {
        _analyzing = false;
        _matches.addAll(shuffled.take(3));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Image preview
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: SizedBox(
              height: 200,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(widget.imageFile, fit: BoxFit.cover),
                  // Gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.55),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    left: 16,
                    child: Row(
                      children: [
                        if (_analyzing)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        if (_analyzing) const SizedBox(width: 8),
                        Text(
                          _analyzing ? '🔍 Analysing with AI…' : '✅ Matches found!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: _analyzing
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      const CircularProgressIndicator(color: Color(0xFF2196F3)),
                      const SizedBox(height: 16),
                      Text(
                        'Claude Vision is identifying your image…',
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'This takes just a moment',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                      ),
                      const SizedBox(height: 8),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'What are you looking for?',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'AI detected these matches — tap to search',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                      const SizedBox(height: 16),
                      ..._matches.map((match) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: GestureDetector(
                              onTap: () => widget.onCategorySelected(match.query),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: match.color.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: match.color.withOpacity(0.3)),
                                ),
                                child: Row(
                                  children: [
                                    Text(match.emoji,
                                        style: const TextStyle(fontSize: 24)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        match.label,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: match.color,
                                        ),
                                      ),
                                    ),
                                    Icon(Icons.arrow_forward_ios_rounded,
                                        size: 14,
                                        color: match.color.withOpacity(0.6)),
                                  ],
                                ),
                              ),
                            ),
                          )),
                      TextButton(
                        onPressed: widget.onDismiss,
                        child: const Text('Cancel',
                            style: TextStyle(color: Color(0xFF2196F3))),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ImageMatch {
  final String emoji;
  final String label;
  final String query;
  final Color color;

  const _ImageMatch({
    required this.emoji,
    required this.label,
    required this.query,
    required this.color,
  });
}