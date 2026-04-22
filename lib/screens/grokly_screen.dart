import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../models/products_data.dart';
import '../utils/app_colors.dart';
import '../widgets/app_drawer.dart';
import 'cart_screen.dart';
import 'profile_screen.dart';

// ═══════════════════════════════════════════════════════════════════
//  COLOUR CONSTANTS  (Zepto peach palette)
// ═══════════════════════════════════════════════════════════════════
const _kBg         = Colors.white;           // clean white page background
const _kHeaderBg   = Colors.white;           // white for top area
const _kFeesCard   = Color(0xFFE8F5E9);      // soft green fees bar (matches _kGreen accent)
const _kGreen      = Color(0xFF0C831F); // Grokly green

// ═══════════════════════════════════════════════════════════════════
//  GROKLY SCREEN
// ═══════════════════════════════════════════════════════════════════
class GroklyScreen extends StatefulWidget {
  final String initialSearchQuery;
  const GroklyScreen({super.key, this.initialSearchQuery = ''});
  @override
  State<GroklyScreen> createState() => _GroklyScreenState();
}

class _GroklyScreenState extends State<GroklyScreen>
    with SingleTickerProviderStateMixin {
  String _selectedTab      = 'Grokly';
  String _selectedCategory = 'All';
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  late TabController _categoryTabCtrl;

  final PageController _bannerCtrl = PageController();
  int _bannerIndex = 0;
  Timer? _bannerTimer;
  bool _bannerUserScrolling = false;

  // Scroll controller + per-item keys for auto-scroll from dashboard
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _productKeys = {};

  // ── Category tabs  (image + label, like Zepto's All / Fresh …)
  final List<Map<String, String>> _cats = [
    {
      'label': 'All',
      'img': 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=120&q=80',
    },
    {
      'label': 'Vegetables',
      'img': 'https://images.unsplash.com/photo-1597362925123-77861d3fbac7?w=120&q=80',
    },
    {
      'label': 'Fruits',
      'img': 'https://images.unsplash.com/photo-1610832958506-aa56368176cf?w=120&q=80',
    },
    {
      'label': 'Dairy',
      'img': 'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=120&q=80',
    },
    {
      'label': 'Pulses',
      'img': 'https://images.unsplash.com/photo-1515543904379-3d757afe72e4?w=120&q=80',
    },
    {
      'label': 'Snacks',
      'img': 'https://images.unsplash.com/photo-1621939514649-280e2ee25f60?w=120&q=80',
    },
    {
      'label': 'Beverages',
      'img': 'https://images.unsplash.com/photo-1544145945-f90425340c7e?w=120&q=80',
    },
    {
      'label': 'Oils',
      'img': 'https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?w=120&q=80',
    },
  ];

  // ── Deal cards  (horizontal scroll row, like Zepto's product cards)
  final List<_DealCard> _deals = [
    _DealCard(
      title: 'Fresh\nVegetables', pct: '21% OFF',
      img: 'https://images.unsplash.com/photo-1574316071802-0d684efa7bf5?q=80&w=735&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
      bg: Color(0xFFE8F5E9),
    ),
    _DealCard(
      title: 'Seasonal\nFruits', pct: '39% OFF',
      img: 'https://plus.unsplash.com/premium_photo-1667829652027-747a608f99ba?q=80&w=1074&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
      bg: Color(0xFFFFF3E0),
    ),
    _DealCard(
      title: 'Daily\nDairy', pct: '64% OFF',
      img: 'https://plus.unsplash.com/premium_photo-1694481100261-ab16523c4093?q=80&w=688&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
      bg: Color(0xFFE3F2FD),
    ),
    _DealCard(
      title: 'Summer\nSnacks', pct: '30% OFF',
      img: 'https://images.unsplash.com/photo-1633933037611-f26e54366832?w=600&auto=format&fit=crop&q=60&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8Nnx8cG9wc2ljbGVzfGVufDB8fDB8fHww',
      bg: Color(0xFFFCE4EC),
    ),
    _DealCard(
      title: 'Cold\nDrinks', pct: '25% OFF',
      img: 'https://images.unsplash.com/photo-1769720754590-168f18fb538d?w=600&auto=format&fit=crop&q=60&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8Nnx8Y29sZCUyMGRyaW5rcyUyMHBhY2thZ2VkfGVufDB8fDB8fHww',
      bg: Color(0xFFEDE7F6),
    ),
  ];

  List<dynamic> get _filtered {
    List<dynamic> r = ProductsData.groceryProducts;
    if (_selectedCategory != 'All') {
      r = r.where((p) {
        if (_selectedCategory == 'Vegetables') return p.id >= 14 && p.id <= 23;
        if (_selectedCategory == 'Fruits')      return p.id >= 24 && p.id <= 31;
        if (_selectedCategory == 'Dairy')       return p.id >= 6  && p.id <= 13;
        if (_selectedCategory == 'Pulses')      return p.id >= 32 && p.id <= 37;
        if (_selectedCategory == 'Snacks')      return p.id >= 52 && p.id <= 61;
        if (_selectedCategory == 'Beverages')   return p.id >= 62 && p.id <= 71;
        if (_selectedCategory == 'Oils')        return p.id >= 42 && p.id <= 51;
        return false;
      }).toList();
    }
    if (_searchQuery.isNotEmpty) {
      r = r.where((p) =>
        p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        p.description.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }
    return r;
  }

  @override
  void initState() {
    super.initState();
    _categoryTabCtrl = TabController(length: _cats.length, vsync: this);
    _startBannerAutoPlay();
    if (widget.initialSearchQuery.isNotEmpty) {
      _searchCtrl.text = widget.initialSearchQuery;
      _searchQuery = widget.initialSearchQuery;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted || _productKeys.isEmpty) return;
          final ctx = _productKeys.values.first.currentContext;
          if (ctx != null) {
            Scrollable.ensureVisible(ctx,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
                alignment: 0.1);
          }
        });
      });
    }
  }

  void _startBannerAutoPlay() {
    _bannerTimer?.cancel();
    _bannerTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || _bannerUserScrolling) return;
      final next = (_bannerIndex + 1) % 3;
      _bannerCtrl.animateToPage(next,
          duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
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
    _searchCtrl.dispose();
    _bannerCtrl.dispose();
    _categoryTabCtrl.dispose();
    _bannerTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);

    return Scaffold(
      backgroundColor: _kBg,
      drawer: const AppDrawer(),
      body: _selectedTab == 'LocalMeds'
          ? SafeArea(
              child: Column(children: [
                _buildTopBar(cart),
                const Expanded(child: _LocalMedsScreen()),
              ]),
            )
          : (_selectedTab == 'OffZone' || _selectedTab == 'Fresh')
              ? SafeArea(
                  child: Column(children: [
                    _buildTopBar(cart),
                    Expanded(child: _ComingSoonTab(tab: _selectedTab)),
                  ]),
                )
              : _buildGroklyFull(cart),
      bottomNavigationBar: cart.itemCount > 0
          ? SafeArea(
              child: GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const CartScreen())),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: _kGreen,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(
                        color: _kGreen.withOpacity(0.4),
                        blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6)),
                      child: Text('${cart.itemCount} item${cart.itemCount > 1 ? 's' : ''}',
                          style: const TextStyle(color: Colors.white, fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ),
                    const Spacer(),
                    const Text('View Cart',
                        style: TextStyle(color: Colors.white, fontSize: 15,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(width: 6),
                    Text('• ₹${cart.subtotal.toStringAsFixed(0)}',
                        style: const TextStyle(color: Colors.white, fontSize: 14)),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
                  ]),
                ),
              ),
            )
          : null,
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  FULL GROKLY PAGE  (peach bg, all sections)
  // ══════════════════════════════════════════════════════════════
  Widget _buildGroklyFull(CartProvider cart) {
    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [

        // ── TOP BAR (delivery + tabs + search) ──────────────────
        // ── FULL-BLEED HERO BANNER with floating top bar overlay ─
        SliverToBoxAdapter(child: _buildHeroBannerWithHeader(cart)),

        // ── TAB PILLS ROW — on the peach background below banner ─
        if (_searchQuery.isEmpty)
          SliverToBoxAdapter(child: _buildTabPillsRow()),

        // ── ₹0 FEES BAR ─────────────────────────────────────────
        if (_searchQuery.isEmpty)
          SliverToBoxAdapter(child: _buildFeesBar()),

        // ── CATEGORY ICON-TAB ROW  (All / Vegetables / Fruits …) ─
        if (_searchQuery.isEmpty)
          SliverToBoxAdapter(child: _buildCategoryRow()),

        // ── DEALS  "Offers ∧"  horizontal cards ─────────────────
        if (_searchQuery.isEmpty && _selectedCategory == 'All')
          SliverToBoxAdapter(child: _buildDealsRow()),

        // ── PRODUCTS HEADER ──────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(children: [
              Text(
                _searchQuery.isNotEmpty
                    ? 'Results for "$_searchQuery"'
                    : _selectedCategory == 'All'
                        ? 'All Groceries'
                        : _selectedCategory,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                    color: Colors.black87),
              ),
              const SizedBox(width: 6),
              Text('(${_filtered.length})',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            ]),
          ),
        ),

        // ── PRODUCT GRID ─────────────────────────────────────────
        if (_filtered.isEmpty)
          SliverFillRemaining(
            child: Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🛒', style: TextStyle(fontSize: 60)),
                const SizedBox(height: 12),
                const Text('No products found',
                    style: TextStyle(fontSize: 16, color: Colors.black54,
                        fontWeight: FontWeight.bold)),
              ],
            )),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.68,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              delegate: SliverChildBuilderDelegate(
                (ctx, i) {
                  final p = _filtered[i];
                  _productKeys[i] ??= GlobalKey();
                  return KeyedSubtree(
                    key: _productKeys[i],
                    child: _ProductCard(product: p, isInCart: cart.isInCart(p.id), cart: cart),
                  );
                },
                childCount: _filtered.length,
              ),
            ),
          ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  FULL-BLEED HERO BANNER with floating top bar overlay
  // ══════════════════════════════════════════════════════════════
  Widget _buildHeroBannerWithHeader(CartProvider cart) {
    final topPadding = MediaQuery.of(context).padding.top;

    // Simplified: banner only has top controls + search at bottom + dots
    const double searchH   = 52.0;
    const double dotsH     = 22.0;
    const double bottomPad = 14.0;
    const double bannerH   = 220.0; // original height restored
    final double totalH    = topPadding + bannerH;

    const double searchBottom = bottomPad;
    const double dotsBottom   = searchBottom + searchH + 8;

    return SizedBox(
      height: totalH,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // ── Full-bleed PageView ─────────────────────────────────
          Positioned.fill(
            top: -55,    // 👈 adjust this — more negative = further up
            left: 0, right: 0, bottom: 0,
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n is ScrollStartNotification && n.dragDetails != null) {
                  _onBannerScrollStart();
                } else if (n is ScrollEndNotification) {
                  _onBannerScrollEnd();
                }
                return false;
              },
              child: PageView(
                controller: _bannerCtrl,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (i) => setState(() => _bannerIndex = i),
                children: [
                  // Banner 0: NEW uploaded Grokly hero banner
                  // Shifted down 55 px so the banner text clears the
                  // floating "6 minutes" top-bar overlay. Box size unchanged.
                  ClipRect(
                    child: Transform.translate(
                      offset: const Offset(0, 55),
                      child: Image.asset(
                        'assets/images/grokly_hero_banner.png',
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFF2E7D32),
                          child: const Center(
                            child: Text('🛒', style: TextStyle(fontSize: 80)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Banner 1: asset image (original)
                  Image.asset(
                    'assets/images/grokly_banner.png',
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFF81C784),
                      child: const Center(
                        child: Text('🛒', style: TextStyle(fontSize: 80)),
                      ),
                    ),
                  ),
                  // Banner 2: fresh vegetables (original)
                  Container(
                    color: const Color(0xFFC8E6C9),
                    child: Stack(children: [
                      const Positioned(
                        right: 10, bottom: 0,
                        child: Text('🥬', style: TextStyle(fontSize: 130)),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 70, 0, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                  color: _kGreen,
                                  borderRadius: BorderRadius.circular(6)),
                              child: const Text('FRESH TODAY',
                                  style: TextStyle(color: Colors.white, fontSize: 10,
                                      fontWeight: FontWeight.w800)),
                            ),
                            const SizedBox(height: 10),
                            const Text('Farm Fresh\nVegetables',
                                style: TextStyle(color: Color(0xFF1B5E20), fontSize: 26,
                                    fontWeight: FontWeight.w900, height: 1.1)),
                            const SizedBox(height: 4),
                            const Text('Up to 40% OFF',
                                style: TextStyle(color: Color(0xFF2E7D32), fontSize: 13)),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ],
              ),
            ),
          ),

          // ── Gradient top scrim for legibility ──────────────────
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.55),
                      Colors.transparent,
                      Colors.black.withOpacity(0.30),
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // ── TOP: hamburger | ⚡ delivery | wallet | profile ─────
          Positioned(
            top: topPadding + 2,
            left: 4, right: 12,
            height: 56,
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white, size: 26),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
              GestureDetector(
                onTap: () {},
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Row(children: [
                      Icon(Icons.bolt, color: Color(0xFF76FF03), size: 18),
                      SizedBox(width: 2),
                      Text('6 minutes',
                          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900,
                              color: Colors.white)),
                    ]),
                    Text('Delivery to your door  ↓',
                        style: TextStyle(fontSize: 10, color: Colors.white70)),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.35), width: 1),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.wallet_outlined, size: 14, color: Colors.white),
                  SizedBox(width: 4),
                  Text('₹0', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                      color: Colors.white)),
                ]),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen())),
                child: Stack(children: [
                  Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.4), width: 1)),
                    child: const Icon(Icons.person_outline, size: 20, color: Colors.white),
                  ),
                  if (cart.itemCount > 0)
                    Positioned(right: 0, top: 0,
                      child: Container(
                        width: 13, height: 13,
                        decoration: const BoxDecoration(color: _kGreen, shape: BoxShape.circle),
                        child: Center(child: Text('${cart.itemCount}',
                            style: const TextStyle(color: Colors.white, fontSize: 8,
                                fontWeight: FontWeight.bold))),
                      ),
                    ),
                ]),
              ),
            ]),
          ),

          // ── PAGE DOTS ───────────────────────────────────────────
          Positioned(
            bottom: dotsBottom,
            left: 0, right: 0, height: dotsH,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _bannerIndex ? 20 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: i == _bannerIndex ? Colors.white : Colors.white.withOpacity(0.50),
                  borderRadius: BorderRadius.circular(4),
                ),
              )),
            ),
          ),

          // ── SEARCH BAR (bottom of banner) ───────────────────────
          Positioned(
            bottom: searchBottom,
            left: 12, right: 12, height: searchH,
            child: Row(children: [
              Expanded(
                child: Container(
                  height: searchH,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.20),
                        blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _searchQuery = v.trim()),
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search for "Tomatoes"',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      prefixIcon: Icon(Icons.search, color: Colors.grey.shade400, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.close, color: Colors.grey.shade400, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _searchQuery = '');
                              })
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: searchH,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.20),
                      blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('Fresh\nDeals', textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                          color: _kGreen, height: 1.2)),
                  const SizedBox(height: 2),
                  const Text('🥦🥕', style: TextStyle(fontSize: 13)),
                ]),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  TAB ROW  — active tab painted open-bottom so it truly melts
  //  into the page background. Inactive = white floating cards.
  // ══════════════════════════════════════════════════════════════
  Widget _buildTabPillsRow() {
    // The row sits on _kBg. A 1px divider line runs across the bottom.
    // The active tab CustomPainter draws a rounded-top-only shape that
    // covers the divider line — making the tab appear to dissolve into bg.
    return SizedBox(
      height: 56,
      child: Stack(
        children: [
          // Divider line at the very bottom
          Positioned(
            bottom: 0, left: 0, right: 0, height: 1,
            child: Container(color: const Color(0xFFE0E0E0).withOpacity(0.8)),
          ),
          // Scrollable tab row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

              _buildZeptoTab(
                tabKey: 'Grokly',
                child: Text('grokly',
                    style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic, letterSpacing: -0.5,
                      color: _selectedTab == 'Grokly' ? _kGreen : Colors.black54,
                    )),
              ),
              const SizedBox(width: 6),

              _buildZeptoTab(
                tabKey: 'LocalMeds',
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Image.asset('assets/images/localmeds_logo.png',
                      height: 16, width: 16, fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(Icons.local_pharmacy,
                          size: 14,
                          color: _selectedTab == 'LocalMeds'
                              ? const Color(0xFF26A69A) : Colors.black54)),
                  const SizedBox(width: 5),
                  Text('LocalMeds',
                      style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w800,
                        color: _selectedTab == 'LocalMeds'
                            ? const Color(0xFF26A69A) : Colors.black54,
                      )),
                ]),
              ),
              const SizedBox(width: 6),

              _buildZeptoTab(
                tabKey: 'OffZone',
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('50%',
                      style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w900, height: 1.1,
                        color: _selectedTab == 'OffZone'
                            ? const Color(0xFF4527A0) : Colors.black54,
                      )),
                  Text('OFF ZONE',
                      style: TextStyle(
                        fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: 0.4,
                        color: _selectedTab == 'OffZone'
                            ? const Color(0xFF4527A0) : Colors.black45,
                      )),
                ]),
              ),
              const SizedBox(width: 6),

              _buildZeptoTab(
                tabKey: 'Fresh',
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Text('🌿', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 3),
                  Text('Fresh',
                      style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w900,
                        color: _selectedTab == 'Fresh'
                            ? const Color(0xFF1B4D3E) : Colors.black54,
                      )),
                ]),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  // Active tab: CustomPaint open-bottom shape that covers the divider.
  // Inactive tab: white floating card with full radius.
  Widget _buildZeptoTab({required String tabKey, required Widget child}) {
    final bool sel = _selectedTab == tabKey;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = tabKey),
      child: sel
          ? CustomPaint(
              painter: _ActiveTabPainter(bgColor: _kBg),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
                child: Center(child: child),
              ),
            )
          : AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(bottom: 5),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.07),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(child: child),
            ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  TOP BAR — for LocalMeds / OffZone / Fresh tabs
  // ══════════════════════════════════════════════════════════════
  Widget _buildTopBar(CartProvider cart) {
    return Container(
      color: _kHeaderBg,
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 0),
      child: SafeArea(
        bottom: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [

          // Row 1: ☰ | ⚡ delivery | ₹0 wallet | profile
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 12, 0),
            child: Row(children: [
              Builder(builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu, color: Colors.black87, size: 26),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              )),
              GestureDetector(
                onTap: () {},
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                  Row(children: [
                    Icon(Icons.bolt, color: _kGreen, size: 22),
                    SizedBox(width: 2),
                    Text('6 minutes',
                        style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900,
                            color: Colors.black87)),
                  ]),
                  Text('Delivery to your door  ↓',
                      style: TextStyle(fontSize: 11, color: Colors.black54)),
                ]),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06),
                      blurRadius: 4, offset: const Offset(0, 1))],
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.wallet_outlined, size: 15, color: Colors.purple),
                  SizedBox(width: 4),
                  Text('₹0', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                ]),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen())),
                child: Stack(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.person_outline, size: 22, color: Colors.black54),
                  ),
                  if (cart.itemCount > 0)
                    Positioned(right: 0, top: 0,
                      child: Container(
                        width: 14, height: 14,
                        decoration: const BoxDecoration(color: _kGreen, shape: BoxShape.circle),
                        child: Center(child: Text('${cart.itemCount}',
                            style: const TextStyle(color: Colors.white, fontSize: 8,
                                fontWeight: FontWeight.bold))),
                      )),
                ]),
              ),
            ]),
          ),

          const SizedBox(height: 8),

          // Tab pills — same shared widget, on peach background
          _buildTabPillsRow(),

          const SizedBox(height: 8),

          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06),
                    blurRadius: 4, offset: const Offset(0, 1))],
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _searchQuery = v.trim()),
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search for products...',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                  prefixIcon: Icon(Icons.search, color: Colors.grey.shade400, size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  //  ₹0 FEES BAR  — tan/gold, exactly like Zepto
  // ══════════════════════════════════════════════════════════════
  Widget _buildFeesBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _kFeesCard,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('₹0', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900,
                    color: Color(0xFF1B5E20), height: 1)),
                Text('FEES', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900,
                    color: Color(0xFF1B5E20), height: 1)),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: const [
                  _FeeChip('₹0 Handling Fee'),
                  _FeeChip('₹0 Delivery Fee*'),
                  _FeeChip('₹0 Rain & Surge Fee'),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const SizedBox(
              width: 68,
              child: Text('* T&C Apply.\nMin. order value',
                  style: TextStyle(fontSize: 8, color: Color(0xFF4CAF50), height: 1.3)),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  CATEGORY ROW  — icon above label, underline on selected
  //  (exact copy of Zepto's All / Holi Party / Fresh / Fashion …)
  // ══════════════════════════════════════════════════════════════
  Widget _buildCategoryRow() {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: _cats.asMap().entries.map((e) {
            final cat   = e.value;
            final sel   = _selectedCategory == cat['label'];
            return GestureDetector(
              onTap: () => setState(() => _selectedCategory = cat['label']!),
              child: Container(
                width: 70,
                margin: const EdgeInsets.only(right: 2),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: sel ? Colors.black87 : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                padding: const EdgeInsets.only(bottom: 8, top: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        cat['img']!,
                        width: 48, height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.image_not_supported_outlined,
                              size: 22, color: Colors.grey),
                        ),
                        loadingBuilder: (_, child, progress) => progress == null
                            ? child
                            : Container(
                                width: 48, height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Center(
                                  child: SizedBox(width: 18, height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: _kGreen)),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(cat['label']!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                          color: sel ? Colors.black87 : Colors.black54,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  DEALS ROW  — horizontal scroll cards exactly like Zepto
  //  (purple bg, % badge top-left, product image, ADD button)
  // ══════════════════════════════════════════════════════════════
  Widget _buildDealsRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        // "Offers ^" header like Zepto
        GestureDetector(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Text('Offers',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                      color: Color(0xFFE53935))),
              SizedBox(width: 6),
              Icon(Icons.keyboard_arrow_up_rounded, color: Color(0xFFE53935), size: 20),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _deals.length,
            itemBuilder: (_, i) => _DealCardWidget(deal: _deals[i]),
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  DEAL CARD WIDGET  — purple bg, % badge, emoji, ADD
// ════════════════════════════════════════════════════════════════════
class _DealCardWidget extends StatelessWidget {
  final _DealCard deal;
  const _DealCardWidget({required this.deal});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 155,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: deal.bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(children: [
        // % badge  (pink pill, top-left — just like Zepto)
        Positioned(
          top: 10, left: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE91E8C),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(deal.pct,
                style: const TextStyle(color: Colors.white, fontSize: 11,
                    fontWeight: FontWeight.w900)),
          ),
        ),
        // Product image — fills upper portion of card
        Positioned(
          top: 0, left: 0, right: 0,
          bottom: 78,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Image.network(
              deal.img,
              fit: BoxFit.cover,
              width: double.infinity,
              errorBuilder: (_, __, ___) => Container(
                color: deal.bg,
                child: const Center(
                  child: Icon(Icons.image_not_supported_outlined,
                      size: 36, color: Colors.grey),
                ),
              ),
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : Container(
                      color: deal.bg,
                      child: const Center(
                        child: SizedBox(width: 24, height: 24,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: _kGreen)),
                      ),
                    ),
            ),
          ),
        ),
        // Gradient scrim at bottom for text legibility
        Positioned(
          left: 0, right: 0, bottom: 0,
          height: 90,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  deal.bg.withOpacity(0.0),
                  deal.bg.withOpacity(0.95),
                ],
              ),
            ),
          ),
        ),
        // Title + ADD button at bottom
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(deal.title,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                        color: Colors.black87),
                    maxLines: 2),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _kGreen, width: 1.5),
                    ),
                    child: const Text('ADD',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900,
                            color: _kGreen)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  COMING SOON TAB  — placeholder for 50% OFF Zone, Fresh
// ════════════════════════════════════════════════════════════════════
class _ComingSoonTab extends StatelessWidget {
  final String tab;
  const _ComingSoonTab({required this.tab});

  @override
  Widget build(BuildContext context) {
    final Map<String, Map<String, dynamic>> info = {
      'OffZone': {
        'emoji': '🏷️', 'title': '50% OFF Zone',
        'sub': 'Massive discounts across all categories — launching soon on Grokly!',
        'color': const Color(0xFFE53935),
      },
      'Fresh': {
        'emoji': '🌿', 'title': 'Fresh',
        'sub': 'Farm-to-door fresh produce, dairy & organic goods. Coming soon!',
        'color': const Color(0xFF0C831F),
      },
    };
    final d = info[tab]!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(d['emoji'] as String, style: const TextStyle(fontSize: 80)),
          const SizedBox(height: 20),
          Text(d['title'] as String,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900,
                  color: d['color'] as Color)),
          const SizedBox(height: 12),
          Text(d['sub'] as String,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.black54, height: 1.5)),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: d['color'] as Color,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text('Notify Me',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
          ),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  LOCAL MEDS — COMING SOON
// ════════════════════════════════════════════════════════════════════
class _LocalMedsScreen extends StatelessWidget {
  const _LocalMedsScreen();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(children: [
        // Hero
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [Color(0xFF00897B), Color(0xFF26C6DA)],
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(children: [
                Positioned(right: 16, top: 0, bottom: 0,
                  child: Center(
                    child: Image.asset('assets/images/localmeds_logo.png',
                        height: 110, width: 110, fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.local_pharmacy, size: 80, color: Colors.white54)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 140, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(6)),
                        child: const Text('COMING SOON',
                            style: TextStyle(color: Colors.white, fontSize: 10,
                                fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(height: 10),
                      const Text('LocalMeds',
                          style: TextStyle(color: Colors.white, fontSize: 28,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      const Text('Medicines at\nyour doorstep',
                          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 40),
        Container(
          width: 110, height: 110,
          padding: const EdgeInsets.all(22),
          decoration: const BoxDecoration(color: Color(0xFFE0F2F1), shape: BoxShape.circle),
          child: Image.asset('assets/images/localmeds_logo.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.local_pharmacy, size: 55, color: Color(0xFF26A69A))),
        ),
        const SizedBox(height: 18),
        const Text('LocalMeds is coming soon!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black87)),
        const SizedBox(height: 8),
        Text('Order medicines from local\npharmacies near you',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.5)),
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(children: [
            _FeatureTile(Icons.timer,        'Fast Delivery',      '30-min medicine delivery'),
            const SizedBox(height: 10),
            _FeatureTile(Icons.verified_user,'Genuine Products',   'Certified pharmacy partners'),
            const SizedBox(height: 10),
            _FeatureTile(Icons.upload_file,  'Upload Prescription','Easy prescription upload'),
          ]),
        ),
        const SizedBox(height: 28),
        ElevatedButton(
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("You'll be notified when LocalMeds launches! 🏥"),
                backgroundColor: Color(0xFF26A69A),
                duration: Duration(seconds: 2))),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF26A69A),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: const Text('Notify Me When Live',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 40),
      ]),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  const _FeatureTile(this.icon, this.title, this.subtitle);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0F2F1), width: 1.5),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(color: Color(0xFFE0F2F1), shape: BoxShape.circle),
          child: Icon(icon, color: const Color(0xFF26A69A), size: 20),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
        ]),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  PRODUCT CARD
// ════════════════════════════════════════════════════════════════════
class _ProductCard extends StatelessWidget {
  final dynamic product;
  final bool isInCart;
  final CartProvider cart;
  const _ProductCard({required this.product, required this.isInCart, required this.cart});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: Container(
              height: 110, width: double.infinity,
              color: Colors.grey.shade50,
              child: product.imageUrl != null
                  ? Image.network(product.imageUrl!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                          child: Text(product.emoji ?? '🛒',
                              style: const TextStyle(fontSize: 44))))
                  : Center(child: Text(product.emoji ?? '🛒',
                        style: const TextStyle(fontSize: 44))),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                          color: Colors.black87),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(product.description,
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('₹${product.price.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900,
                              color: _kGreen)),
                      if (!isInCart)
                        GestureDetector(
                          onTap: () {
                            cart.addItem(product);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('${product.name} added'),
                                duration: const Duration(seconds: 1),
                                backgroundColor: _kGreen));
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              border: Border.all(color: _kGreen, width: 1.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('ADD',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                                    color: _kGreen)),
                          ),
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                              color: _kGreen, borderRadius: BorderRadius.circular(8)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            InkWell(
                              onTap: () => cart.decreaseQuantity(product.id),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                child: Icon(Icons.remove, size: 14, color: Colors.white),
                              ),
                            ),
                            Text('${cart.getQuantity(product.id)}',
                                style: const TextStyle(fontWeight: FontWeight.w800,
                                    fontSize: 12, color: Colors.white)),
                            InkWell(
                              onTap: () => cart.addItem(product),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                child: Icon(Icons.add, size: 14, color: Colors.white),
                              ),
                            ),
                          ]),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  FEE CHIP
// ════════════════════════════════════════════════════════════════════
class _FeeChip extends StatelessWidget {
  final String label;
  const _FeeChip(this.label);
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.check_circle, size: 12, color: Color(0xFF2E7D32)),
      const SizedBox(width: 3),
      Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
          color: Color(0xFF2E7D32))),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════════
//  DATA MODELS
// ════════════════════════════════════════════════════════════════════
class _DealCard {
  final String title, pct, img;
  final Color bg;
  const _DealCard({required this.title, required this.pct,
      required this.img, required this.bg});
}

// ════════════════════════════════════════════════════════════════════
//  ACTIVE TAB PAINTER
//  Draws an open-bottom rounded rectangle — top-left + top-right
//  corners are rounded, bottom two corners are square and the bottom
//  edge is NOT drawn, so the shape bleeds seamlessly into the bg.
//  A thin border is drawn on top + left + right only.
// ════════════════════════════════════════════════════════════════════
class _ActiveTabPainter extends CustomPainter {
  final Color bgColor;
  const _ActiveTabPainter({required this.bgColor});

  @override
  void paint(Canvas canvas, Size size) {
    const double r = 16.0; // corner radius
    const double bw = 1.0; // border width

    // ── Fill: open-bottom shape ─────────────────────────────────
    final fillPaint = Paint()..color = bgColor..style = PaintingStyle.fill;
    final fillPath = Path()
      ..moveTo(0, size.height)          // bottom-left (open)
      ..lineTo(0, r)                    // left edge up
      ..quadraticBezierTo(0, 0, r, 0)  // top-left arc
      ..lineTo(size.width - r, 0)       // top edge
      ..quadraticBezierTo(size.width, 0, size.width, r) // top-right arc
      ..lineTo(size.width, size.height) // right edge down (open)
      // no close — bottom deliberately left open
      ;
    canvas.drawPath(fillPath, fillPaint);

    // ── Border: top + left + right only ────────────────────────
    final borderPaint = Paint()
      ..color = const Color(0xFFDDDDDD)
      ..style = PaintingStyle.stroke
      ..strokeWidth = bw;
    final borderPath = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..lineTo(size.width - r, 0)
      ..quadraticBezierTo(size.width, 0, size.width, r)
      ..lineTo(size.width, size.height);
    canvas.drawPath(borderPath, borderPaint);
  }

  @override
  bool shouldRepaint(_ActiveTabPainter old) => old.bgColor != bgColor;
}