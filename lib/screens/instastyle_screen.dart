import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../models/products_data.dart';
import '../utils/app_colors.dart';
import '../widgets/app_drawer.dart';
import 'cart_screen.dart';

// ─────────────────────────────────────────────
//  ACCESCO Brand Tokens  — Adidas-inspired edge
// ─────────────────────────────────────────────
class _A {
  static const Color black     = Color(0xFF0A0A0A);
  static const Color white     = Color(0xFFFAFAFA);
  static const Color surface   = Color(0xFFF2F0ED);
  static const Color gold      = Color(0xFFC9A96E);
  static const Color goldDark  = Color(0xFF9C7A44);
  static const Color goldLight = Color(0xFFE8D9BE);
  static const Color mid       = Color(0xFF5A5A5A);
  static const Color like      = Color(0xFF2D8653);
  static const Color dislike   = Color(0xFFBF2D2D);
  static const Color green     = Color(0xFF2D8653);
  static const String _sport   = 'DM Sans'; // unused directly now

  static TextStyle sportLabel({
    double size = 11,
    double spacing = 3,
    Color color = const Color(0xFF5A5A5A),
    FontWeight weight = FontWeight.w400,
  }) => GoogleFonts.dmSans(
    fontSize: size,
    letterSpacing: spacing,
    fontWeight: weight,
    color: color,
  );

  static TextStyle headline({
    double size = 28,
    Color color = const Color(0xFF0A0A0A),
    FontWeight weight = FontWeight.w900,
  }) => GoogleFonts.dmSans(
    fontSize: size,
    fontWeight: weight,
    letterSpacing: -0.5,
    color: color,
  );
}

// ─────────────────────────────────────────────
//  InstaStyle Floating Logo Badge
// ─────────────────────────────────────────────
class _InstastyleBadge extends StatelessWidget {
  const _InstastyleBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _A.black.withOpacity(0.72),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _A.gold.withOpacity(0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/instastyle_logo.png',
            width: 18,
            height: 18,
            errorBuilder: (_, __, ___) => const Icon(Icons.checkroom, color: _A.gold, size: 16),
          ),
          const SizedBox(width: 6),
          Text('INSTASTYLE', style: _A.sportLabel(size: 9, spacing: 2, color: _A.gold, weight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Three-stripe Accent (Adidas visual language)
// ─────────────────────────────────────────────
class _ThreeStripes extends StatelessWidget {
  final Color color;
  final double height;
  const _ThreeStripes({this.color = const Color(0xFFC9A96E), this.height = 3});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) => Padding(
        padding: EdgeInsets.only(bottom: i < 2 ? height * 0.6 : 0),
        child: Container(height: height, width: (3 - i) * 14.0, color: color),
      )),
    );
  }
}

// ─────────────────────────────────────────────
//  Feature Badge Chip
// ─────────────────────────────────────────────
class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;
  const _FeatureChip({required this.icon, required this.label, required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _A.white,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: accent.withOpacity(0.35), width: 1.2),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: accent),
            const SizedBox(width: 5),
            Text(label.toUpperCase(), style: _A.sportLabel(size: 9, spacing: 1.5, color: _A.black, weight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Delivery Timer Banner
// ─────────────────────────────────────────────
class _DeliveryTimerBanner extends StatefulWidget {
  const _DeliveryTimerBanner();
  @override
  State<_DeliveryTimerBanner> createState() => _DeliveryTimerBannerState();
}

class _DeliveryTimerBannerState extends State<_DeliveryTimerBanner> {
  int _minutes = 17;
  int _seconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_seconds > 0) {
          _seconds--;
        } else if (_minutes > 0) {
          _minutes--;
          _seconds = 59;
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _A.black,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: _A.gold.withOpacity(0.4), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: _A.gold, borderRadius: BorderRadius.circular(2)),
            child: const Icon(Icons.bolt, color: _A.black, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('INSTANT DELIVERY', style: _A.sportLabel(size: 9, spacing: 2, color: _A.gold, weight: FontWeight.w800)),
                const SizedBox(height: 1),
                Text('Arrives in your area', style: _A.sportLabel(size: 10, spacing: 0.5, color: Colors.white54)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            constraints: const BoxConstraints(minWidth: 72),
            decoration: BoxDecoration(
              border: Border.all(color: _A.gold, width: 1.5),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Text(
              '${_minutes.toString().padLeft(2, '0')}:${_seconds.toString().padLeft(2, '0')}',
              style: GoogleFonts.dmSans(fontSize: 18,
                fontWeight: FontWeight.w900,
                color: _A.gold,
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Feature Highlight Row (horizontal scroll)
// ─────────────────────────────────────────────
class _FeatureHighlightRow extends StatelessWidget {
  final VoidCallback onThrift;
  final VoidCallback onReverseLoop;
  final VoidCallback onCurated;
  final VoidCallback onAIStyle;
  final VoidCallback onTryBefore;

  const _FeatureHighlightRow({
    required this.onThrift,
    required this.onReverseLoop,
    required this.onCurated,
    required this.onAIStyle,
    required this.onTryBefore,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _FeatureChip(icon: Icons.recycling, label: 'Thrift', accent: _A.green, onTap: onThrift),
          const SizedBox(width: 8),
          _FeatureChip(icon: Icons.loop, label: 'Fashion Loop', accent: _A.goldDark, onTap: onReverseLoop),
          const SizedBox(width: 8),
          _FeatureChip(icon: Icons.style, label: 'Curated', accent: _A.black, onTap: onCurated),
          const SizedBox(width: 8),
          _FeatureChip(icon: Icons.auto_awesome, label: 'AI Styled', accent: Color(0xFF6B4FBB), onTap: onAIStyle),
          const SizedBox(width: 8),
          _FeatureChip(icon: Icons.local_shipping_outlined, label: 'Try Before Buy', accent: _A.dislike, onTap: onTryBefore),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Curated Collections Section
// ─────────────────────────────────────────────
class _CuratedCollectionsSection extends StatelessWidget {
  const _CuratedCollectionsSection();

  static const _collections = [
    {'label': 'OFFICE EDIT', 'sub': 'Power Dressing', 'color': '0xFF1A1A1A', 'img': 'https://images.unsplash.com/photo-1490481651871-ab68de25d43d?w=400'},
    {'label': 'WEEKEND VIBES', 'sub': 'Casual Luxe', 'color': '0xFF3D2B1F', 'img': 'https://images.unsplash.com/photo-1483985988355-763728e1935b?w=400'},
    {'label': 'PARTY SEASON', 'sub': 'Evening Edit', 'color': '0xFF1F1A3D', 'img': 'https://images.unsplash.com/photo-1445205170230-053b83016050?w=400'},
    {'label': 'RESORT WEAR', 'sub': 'Breezy & Bold', 'color': '0xFF0D3B2E', 'img': 'https://images.unsplash.com/photo-1469334031218-e382a71b716b?w=400'},
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const _ThreeStripes(color: _A.gold, height: 2.5),
              const SizedBox(width: 10),
              Text('CURATED COLLECTIONS', style: _A.sportLabel(size: 10, spacing: 2.5, weight: FontWeight.w700)),
            ],
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _collections.length,
            itemBuilder: (_, i) {
              final col = _collections[i];
              return Container(
                width: 150,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: _A.goldLight, width: 1),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: Image.network(col['img']!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: Color(int.parse(col['color']!))),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter, end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withOpacity(0.75)],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 8, left: 8, right: 8,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(col['label']!, maxLines: 1, overflow: TextOverflow.ellipsis, style: _A.sportLabel(size: 9, spacing: 1.5, color: _A.gold, weight: FontWeight.w800)),
                          Text(col['sub']!, maxLines: 1, overflow: TextOverflow.ellipsis, style: _A.sportLabel(size: 8, spacing: 0.5, color: Colors.white70)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  Wishlist State (global notifier for simplicity)
// ─────────────────────────────────────────────
class WishlistNotifier extends ChangeNotifier {
  final Set<int> _ids = {};
  bool isWishlisted(int id) => _ids.contains(id);
  void toggle(int id) {
    if (_ids.contains(id)) _ids.remove(id); else _ids.add(id);
    notifyListeners();
  }
  int get count => _ids.length;
}

// ─────────────────────────────────────────────
//  Bottom Sheet Helpers
// ─────────────────────────────────────────────
// ─────────────────────────────────────────────
//  Customisation / Filter Sheet
// ─────────────────────────────────────────────
void _showCustomisationSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _CustomisationSheetContent(),
  );
}

class _CustomisationSheetContent extends StatefulWidget {
  @override
  State<_CustomisationSheetContent> createState() => _CustomisationSheetContentState();
}

class _CustomisationSheetContentState extends State<_CustomisationSheetContent> {
  String _size = 'M';
  String _fit = 'Regular';
  String _occasion = 'Casual';
  Color _color = const Color(0xFF0A0A0A);
  RangeValues _priceRange = const RangeValues(500, 5000);

  static const _sizes    = ['XS', 'S', 'M', 'L', 'XL', 'XXL'];
  static const _fits     = ['Slim', 'Regular', 'Relaxed', 'Oversized'];
  static const _occasions = ['Casual', 'Formal', 'Sport', 'Party'];
  static const _colors   = [
    Color(0xFF0A0A0A), Color(0xFFFAFAFA), Color(0xFFC9A96E),
    Color(0xFF2D5F8A), Color(0xFF8A2D2D), Color(0xFF2D8653),
  ];

  @override
  Widget build(BuildContext context) {
    return _AdidasSheet(
      title: 'Customise',
      subtitle: 'FILTER YOUR STYLE',
      icon: Icons.tune,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Size
          Text('SIZE', style: _A.sportLabel(size: 8, spacing: 2, weight: FontWeight.w800)),
          const SizedBox(height: 10),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _sizes.map((s) {
                final sel = s == _size;
                return GestureDetector(
                  onTap: () => setState(() => _size = s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 8),
                    width: 44, height: 38,
                    decoration: BoxDecoration(
                      color: sel ? _A.black : Colors.transparent,
                      border: Border.all(color: sel ? _A.black : _A.goldLight, width: 1.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    alignment: Alignment.center,
                    child: Text(s, style: _A.sportLabel(size: 10, spacing: 0.5, color: sel ? Colors.white : _A.mid, weight: FontWeight.w800)),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 18),

          // Fit
          Text('FIT', style: _A.sportLabel(size: 8, spacing: 2, weight: FontWeight.w800)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _fits.map((f) {
              final sel = f == _fit;
              return GestureDetector(
                onTap: () => setState(() => _fit = f),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: sel ? _A.gold : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(color: sel ? _A.gold : _A.goldLight, width: 1.2),
                  ),
                  child: Text(f, style: _A.sportLabel(size: 10, spacing: 0.5, color: sel ? _A.black : _A.mid, weight: FontWeight.w700)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),

          // Occasion
          Text('OCCASION', style: _A.sportLabel(size: 8, spacing: 2, weight: FontWeight.w800)),
          const SizedBox(height: 10),
          Row(
            children: List.generate(_occasions.length, (i) {
              final o = _occasions[i];
              final sel = o == _occasion;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _occasion = o),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: EdgeInsets.only(right: i < _occasions.length - 1 ? 6 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: sel ? _A.black : Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(color: sel ? _A.black : _A.goldLight, width: 1.2),
                    ),
                    alignment: Alignment.center,
                    child: Text(o, style: _A.sportLabel(size: 9, spacing: 0.5, color: sel ? Colors.white : _A.mid, weight: FontWeight.w800)),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 18),

          // Colour
          Text('COLOUR', style: _A.sportLabel(size: 8, spacing: 2, weight: FontWeight.w800)),
          const SizedBox(height: 10),
          Row(
            children: _colors.map((c) {
              final sel = c.value == _color.value;
              return GestureDetector(
                onTap: () => setState(() => _color = c),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: 10),
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: sel ? _A.gold : (c == const Color(0xFFFAFAFA) ? _A.goldLight : Colors.transparent),
                      width: sel ? 3 : 1,
                    ),
                    boxShadow: sel ? [BoxShadow(color: _A.gold.withOpacity(0.5), blurRadius: 8)] : [],
                  ),
                  child: sel ? Icon(Icons.check, size: 16, color: c == const Color(0xFFFAFAFA) ? _A.gold : Colors.white) : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),

          // Price range
          Text('PRICE RANGE  ₹${_priceRange.start.toInt()} – ₹${_priceRange.end.toInt()}',
            style: _A.sportLabel(size: 8, spacing: 2, weight: FontWeight.w800)),
          RangeSlider(
            values: _priceRange,
            min: 200, max: 10000, divisions: 50,
            activeColor: _A.gold,
            inactiveColor: _A.goldLight,
            onChanged: (v) => setState(() => _priceRange = v),
          ),
          const SizedBox(height: 8),

          // Apply
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Filters: $_size · $_fit · $_occasion · ₹${_priceRange.start.toInt()}–₹${_priceRange.end.toInt()}'),
                duration: const Duration(seconds: 2),
                backgroundColor: _A.black,
              ));
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              color: _A.black,
              alignment: Alignment.center,
              child: Text('APPLY FILTERS', style: _A.sportLabel(size: 11, spacing: 2.5, color: Colors.white, weight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}

void _showThriftSheet(BuildContext context) {
  final thriftItems = [
    {'name': 'Vintage Denim Jacket', 'size': 'M', 'price': '₹850', 'condition': 'Like New', 'img': 'https://images.unsplash.com/photo-1434389677669-e08b4cac3105?w=300'},
    {'name': 'Silk Wrap Dress', 'size': 'S', 'price': '₹620', 'condition': 'Good', 'img': 'https://images.unsplash.com/photo-1509631179647-0177331693ae?w=300'},
    {'name': 'Wool Blazer', 'size': 'L', 'price': '₹1,100', 'condition': 'Excellent', 'img': 'https://images.unsplash.com/photo-1434389677669-e08b4cac3105?w=300'},
  ];

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _AdidasSheet(
      title: 'Thrift Marketplace',
      subtitle: 'PRE-LOVED FASHION',
      icon: Icons.recycling,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _AdidasButton(label: 'BROWSE', filled: true, onTap: () {})),
              const SizedBox(width: 10),
              Expanded(child: _AdidasButton(label: 'SELL YOURS', filled: false, onTap: () {})),
            ],
          ),
          const SizedBox(height: 16),
          ...thriftItems.map((item) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _A.white,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: _A.goldLight, width: 1),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: Image.network(item['img']!, width: 56, height: 64, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(width: 56, height: 64, color: _A.goldLight, child: const Icon(Icons.checkroom, color: _A.gold)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['name']!, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w800, color: _A.black)),
                      const SizedBox(height: 2),
                      Row(children: [
                        Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), color: _A.goldLight,
                          child: Text(item['condition']!, style: _A.sportLabel(size: 8, spacing: 0.5, color: _A.goldDark, weight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 6),
                        Text('Size ${item['size']!}', style: _A.sportLabel(size: 9, spacing: 0.5, color: _A.mid)),
                      ]),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(item['price']!, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w900, color: _A.black)),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () {},
                      child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), color: _A.black,
                        child: Text('BUY', style: _A.sportLabel(size: 9, spacing: 1.5, color: Colors.white, weight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    ),
  );
}

void _showReverseFashionSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _AdidasSheet(
      title: 'Reverse Fashion Loop',
      subtitle: 'SUSTAINABLE STYLE',
      icon: Icons.loop,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _A.green.withOpacity(0.08),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: _A.green.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.eco, color: _A.green, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('YOUR IMPACT', style: _A.sportLabel(size: 9, spacing: 2, color: _A.green, weight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text('3 items recycled · 2.4kg CO₂ saved', style: _A.sportLabel(size: 10, spacing: 0.3, color: _A.black)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _LoopOptionTile(icon: Icons.local_shipping, label: 'Schedule Pickup', sub: 'We collect from your door', onTap: () => Navigator.pop(context)),
          const SizedBox(height: 8),
          _LoopOptionTile(icon: Icons.store, label: 'Drop at Store', sub: 'Nearest drop point: 1.2km', onTap: () => Navigator.pop(context)),
          const SizedBox(height: 8),
          _LoopOptionTile(icon: Icons.currency_rupee, label: 'Earn Credits', sub: 'Get ₹200 per item returned', onTap: () => Navigator.pop(context)),
        ],
      ),
    ),
  );
}

void _showAIStyleSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _AdidasSheet(
      title: 'AI Style Advisor',
      subtitle: 'PERSONALISED FOR YOU',
      icon: Icons.auto_awesome,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('YOUR STYLE PROFILE', style: _A.sportLabel(size: 9, spacing: 2, weight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: ['Minimalist', 'Street', 'Luxe Casual', 'Neutral Tones', 'Oversized']
              .map((tag) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: _A.black,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(tag.toUpperCase(), style: _A.sportLabel(size: 9, spacing: 1.5, color: _A.gold, weight: FontWeight.w700)),
              )).toList(),
          ),
          const SizedBox(height: 16),
          Text('TODAY\'S AI PICKS', style: _A.sportLabel(size: 9, spacing: 2, weight: FontWeight.w700)),
          const SizedBox(height: 10),
          SizedBox(
            height: 110,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=200',
                'https://images.unsplash.com/photo-1469334031218-e382a71b716b?w=200',
                'https://images.unsplash.com/photo-1434389677669-e08b4cac3105?w=200',
              ].map((url) => Container(
                width: 80,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: _A.goldLight, width: 1.5),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(1),
                  child: Image.network(url, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: _A.goldLight, child: const Center(child: Text('👗', style: TextStyle(fontSize: 28)))),
                  ),
                ),
              )).toList(),
            ),
          ),
          const SizedBox(height: 16),
          _AdidasButton(label: 'REFRESH MY LOOKS', filled: true, onTap: () => Navigator.pop(context)),
        ],
      ),
    ),
  );
}

void _showTryBeforeBuySheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _AdidasSheet(
      title: 'Try Before You Buy',
      subtitle: '48-HR HOME TRIAL',
      icon: Icons.local_shipping_outlined,
      child: Column(
        children: [
          Row(
            children: [
              _TryBeforeStep(step: '1', label: 'Order', sub: 'Select up to 5 items'),
              _TryBeforeStep(step: '2', label: 'Try', sub: 'Keep for 48 hours'),
              _TryBeforeStep(step: '3', label: 'Keep or Return', sub: 'Pay only for what you love'),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _A.black,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: _A.gold, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('Free returns · No questions asked · Zero pressure', style: _A.sportLabel(size: 10, spacing: 0.3, color: Colors.white70))),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _AdidasButton(label: 'START MY TRIAL', filled: true, onTap: () => Navigator.pop(context)),
        ],
      ),
    ),
  );
}

void _showWishlistSheet(BuildContext context, WishlistNotifier wishlist) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _AdidasSheet(
      title: 'Wishlist',
      subtitle: 'SAVED STYLES',
      icon: Icons.favorite_border,
      child: wishlist.count == 0
        ? Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  const _ThreeStripes(color: _A.goldLight, height: 5),
                  const SizedBox(height: 16),
                  Text('NO SAVED ITEMS', style: _A.sportLabel(size: 14, spacing: 3, color: _A.black, weight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text('Tap ♡ on any product to save it', style: _A.sportLabel(size: 11, color: _A.mid)),
                ],
              ),
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${wishlist.count} ITEMS SAVED', style: _A.sportLabel(size: 10, spacing: 2, color: _A.gold, weight: FontWeight.w700)),
              const SizedBox(height: 12),
              _AdidasButton(label: 'MOVE ALL TO BAG', filled: true, onTap: () => Navigator.pop(context)),
            ],
          ),
    ),
  );
}

void _showProfileSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _AdidasSheet(
      title: 'My Profile',
      subtitle: 'ACCESCO MEMBER',
      icon: Icons.person_outline,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 56, height: 56,
                decoration: const BoxDecoration(color: _A.black, shape: BoxShape.circle),
                child: const Icon(Icons.person, color: _A.gold, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Riya Sharma', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w900, color: _A.black)),
                    Text('riya@email.com', style: _A.sportLabel(size: 10, spacing: 0.3, color: _A.mid)),
                    const SizedBox(height: 4),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), color: _A.gold,
                      child: Text('GOLD MEMBER', style: _A.sportLabel(size: 8, spacing: 1.5, color: _A.black, weight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _ProfileTile(icon: Icons.location_on_outlined, label: 'Saved Addresses', sub: '3 addresses saved'),
          _ProfileTile(icon: Icons.history, label: 'Order History', sub: '12 orders'),
          _ProfileTile(icon: Icons.style, label: 'Style Preferences', sub: 'Minimalist · Casual Luxe'),
          _ProfileTile(icon: Icons.notifications_outlined, label: 'Notifications', sub: 'All alerts on'),
          const SizedBox(height: 8),
          _AdidasButton(label: 'EDIT PROFILE', filled: true, onTap: () => Navigator.pop(context)),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────
//  Shared Sheet Wrapper
// ─────────────────────────────────────────────
class _AdidasSheet extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  const _AdidasSheet({required this.title, required this.subtitle, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 80),
      decoration: const BoxDecoration(
        color: _A.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 1.0,
        minChildSize: 0.5,
        maxChildSize: 1.0,
        expand: false,
        builder: (_, ctrl) => Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 36, height: 3,
              decoration: BoxDecoration(color: _A.goldLight, borderRadius: BorderRadius.circular(2)),
            ),
            // Sheet header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE0DAD2), width: 1))),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Icon(icon, size: 18, color: _A.gold),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(subtitle, style: _A.sportLabel(size: 9, spacing: 2, color: _A.gold, weight: FontWeight.w700)),
                      Text(title, style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w900, color: _A.black)),
                    ],
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: _A.black, borderRadius: BorderRadius.circular(2)),
                      child: const Icon(Icons.close, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.all(20),
                children: [child],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Adidas Button
// ─────────────────────────────────────────────
class _AdidasButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;
  const _AdidasButton({required this.label, required this.filled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: filled ? _A.black : Colors.transparent,
          border: Border.all(color: filled ? _A.black : _A.goldLight, width: 1.5),
          borderRadius: BorderRadius.circular(2),
        ),
        alignment: Alignment.center,
        child: Text(label, style: _A.sportLabel(size: 11, spacing: 2, color: filled ? Colors.white : _A.black, weight: FontWeight.w800)),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Loop Option Tile
// ─────────────────────────────────────────────
class _LoopOptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final VoidCallback onTap;
  const _LoopOptionTile({required this.icon, required this.label, required this.sub, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _A.white,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: _A.goldLight, width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, color: _A.green, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w800, color: _A.black)),
                  Text(sub, style: _A.sportLabel(size: 9, spacing: 0.3, color: _A.mid)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 12, color: _A.mid),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Try Before Step
// ─────────────────────────────────────────────
class _TryBeforeStep extends StatelessWidget {
  final String step;
  final String label;
  final String sub;
  const _TryBeforeStep({required this.step, required this.label, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 36, height: 36,
            decoration: const BoxDecoration(color: _A.black, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(step, style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w900, color: _A.gold)),
          ),
          const SizedBox(height: 6),
          Text(label.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: _A.sportLabel(size: 9, spacing: 1.5, weight: FontWeight.w800, color: _A.black)),
          const SizedBox(height: 2),
          Text(sub, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: _A.sportLabel(size: 8, spacing: 0.3, color: _A.mid)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Profile Tile
// ─────────────────────────────────────────────
class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  const _ProfileTile({required this.icon, required this.label, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _A.white,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: _A.goldLight, width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _A.gold),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w800, color: _A.black)),
                Text(sub, style: _A.sportLabel(size: 9, spacing: 0.3, color: _A.mid)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 12, color: _A.mid),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Main Screen
// ─────────────────────────────────────────────
class InstastyleScreen extends StatefulWidget {
  final String initialSearchQuery;
  const InstastyleScreen({super.key, this.initialSearchQuery = ''});

  @override
  State<InstastyleScreen> createState() => _InstastyleScreenState();
}

class _InstastyleScreenState extends State<InstastyleScreen>
    with SingleTickerProviderStateMixin {
  String _selectedCategory = 'All';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _productKeys = {};
  final WishlistNotifier _wishlist = WishlistNotifier();

  // Banner — single static hero image
  // (no PageController, timer, or autoplay needed)

  // Tabs — now 3: BROWSE, SWIPESTYLE, DISCOVER
  late TabController _tabCtrl;

  final List<Map<String, String>> _categories = [
    {'name': 'All',      'icon': '✦'},
    {'name': 'T-Shirts', 'icon': 'T'},
    {'name': 'Jeans',    'icon': 'J'},
    {'name': 'Dresses',  'icon': 'D'},
    {'name': 'Shoes',    'icon': 'S'},
  ];

  List<dynamic> get _filteredProducts {
    final products = ProductsData.fashionProducts;
    List<dynamic> result = products;
    if (_selectedCategory != 'All') {
      result = result.where((p) {
        if (_selectedCategory == 'T-Shirts') return p.id >= 91 && p.id <= 100;
        if (_selectedCategory == 'Jeans')    return p.id >= 101 && p.id <= 105;
        if (_selectedCategory == 'Dresses')  return p.id >= 106 && p.id <= 110;
        if (_selectedCategory == 'Shoes')    return p.id >= 111 && p.id <= 115;
        return false;
      }).toList();
    }
    if (_searchQuery.isNotEmpty) {
      result = result.where((p) =>
        p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        p.description.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }
    return result;
  }

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
    if (widget.initialSearchQuery.isNotEmpty) {
      _searchController.text = widget.initialSearchQuery;
      _searchQuery = widget.initialSearchQuery;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 400), () {
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

  @override
  void dispose() {
    _searchController.dispose();
    _tabCtrl.dispose();
    _scrollController.dispose();
    _wishlist.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final topPadding = MediaQuery.of(context).padding.top;
    final screenHeight = MediaQuery.of(context).size.height;
    const double tabBarH = 46.0;

    return ChangeNotifierProvider.value(
      value: _wishlist,
      child: Scaffold(
        backgroundColor: _A.surface,
        drawer: const AppDrawer(),
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            // ── HERO BANNER — scrolls away as user scrolls down ──
            SliverAppBar(
              expandedHeight: topPadding + 300,
              collapsedHeight: topPadding + 56,
              pinned: false,
              floating: false,
              snap: false,
              automaticallyImplyLeading: false,
              backgroundColor: _A.black,
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: Stack(
                  children: [
                    // Full-bleed hero image
                    Positioned.fill(
                      child: Container(
                        color: _A.black,
                        child: Image.asset(
                          'assets/images/instastyle_banner.PNG',
                          fit: BoxFit.fitWidth,
                          alignment: Alignment.center,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.checkroom, size: 64, color: _A.gold),
                          ),
                        ),
                      ),
                    ),
                    // Dark vignette
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0x55000000), Color(0x11000000), Color(0xCC000000)],
                              stops: [0.0, 0.45, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // ── Top navigation bar ──
                    Positioned(
                      top: topPadding + 4,
                      left: 4, right: 12,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Builder(
                            builder: (ctx) => IconButton(
                              icon: const Icon(Icons.menu, color: Colors.white, size: 26),
                              onPressed: () => Scaffold.of(ctx).openDrawer(),
                            ),
                          ),
                          const Spacer(),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('ACCESCO', style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 7)),
                              const SizedBox(height: 4),
                              const _ThreeStripes(color: _A.gold, height: 2),
                            ],
                          ),
                          const Spacer(),
                          Consumer<WishlistNotifier>(
                            builder: (_, wl, __) => Stack(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.favorite_border, color: Colors.white, size: 24),
                                  onPressed: () => _showWishlistSheet(context, _wishlist),
                                ),
                                if (wl.count > 0)
                                  Positioned(
                                    right: 8, top: 8,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(color: _A.dislike, shape: BoxShape.circle),
                                      child: Text('${wl.count}', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.person_outline, color: Colors.white, size: 24),
                            onPressed: () => _showProfileSheet(context),
                          ),
                          Stack(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 26),
                                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen())),
                              ),
                              if (cart.itemCount > 0)
                                Positioned(
                                  right: 8, top: 8,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(color: _A.gold, shape: BoxShape.circle),
                                    child: Text('${cart.itemCount}', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // ── Bottom: Explore Now + badge + search bar ──
                    Positioned(
                      bottom: 8, left: 16, right: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  // Go to Browse tab, then scroll down into the product grid
                                  _tabCtrl.animateTo(0);
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    if (_scrollController.hasClients) {
                                      _scrollController.animateTo(
                                        _scrollController.position.maxScrollExtent,
                                        duration: const Duration(milliseconds: 600),
                                        curve: Curves.easeOut,
                                      );
                                    }
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                                  decoration: BoxDecoration(
                                    color: _A.gold,
                                    borderRadius: BorderRadius.circular(2),
                                    boxShadow: [BoxShadow(color: _A.gold.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
                                  ),
                                  child: Text('EXPLORE NOW', style: _A.sportLabel(size: 11, spacing: 2.5, color: _A.black, weight: FontWeight.w900)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const _InstastyleBadge(),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(3),
                                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.22), blurRadius: 16, offset: const Offset(0, 4))],
                                  ),
                                  child: TextField(
                                    controller: _searchController,
                                    onChanged: (v) => setState(() => _searchQuery = v.trim()),
                                    style: const TextStyle(fontSize: 14, color: _A.black),
                                    decoration: InputDecoration(
                                      hintText: 'Search styles, outfits, brands...',
                                      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                                      prefixIcon: const Icon(Icons.search, color: _A.gold, size: 20),
                                      suffixIcon: _searchQuery.isNotEmpty
                                        ? IconButton(
                                            icon: Icon(Icons.close, color: Colors.grey.shade500, size: 18),
                                            onPressed: () {
                                              _searchController.clear();
                                              setState(() => _searchQuery = '');
                                              FocusScope.of(context).unfocus();
                                            },
                                          )
                                        : Icon(Icons.mic_none, color: Colors.grey.shade400, size: 20),
                                      border: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => _showCustomisationSheet(context),
                                child: Container(
                                  width: 48, height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(3),
                                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.22), blurRadius: 16, offset: const Offset(0, 4))],
                                  ),
                                  child: Center(
                                    child: Image.asset(
                                      'assets/images/customise_icon.png',
                                      width: 24, height: 24,
                                      errorBuilder: (_, __, ___) => const Icon(Icons.tune, color: _A.gold, size: 24),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // ── TAB BAR — sticks at top once hero scrolls away ──
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarDelegate(
                tabBar: TabBar(
                  controller: _tabCtrl,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white38,
                  indicatorColor: _A.gold,
                  indicatorWeight: 3,
                  isScrollable: false,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                  labelStyle: _A.sportLabel(size: 11, spacing: 2, color: Colors.white, weight: FontWeight.w800),
                  unselectedLabelStyle: _A.sportLabel(size: 11, spacing: 2),
                  tabs: const [
                    Tab(text: 'BROWSE'),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.swap_horiz, size: 14),
                          SizedBox(width: 4),
                          Text('SWIPE', style: TextStyle(fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome, size: 13),
                          SizedBox(width: 4),
                          Text('DISCOVER', style: TextStyle(fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ],
                ),
                height: tabBarH,
              ),
            ),
          ],
          body: SizedBox(
            height: screenHeight - topPadding - tabBarH,
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _BrowseTab(
                  categories: _categories,
                  selectedCategory: _selectedCategory,
                  filteredProducts: _filteredProducts,
                  searchQuery: _searchQuery,
                  cart: cart,
                  wishlist: _wishlist,
                  productKeys: _productKeys,
                  scrollController: _scrollController,
                  onCategoryTap: (cat) => setState(() => _selectedCategory = cat),
                  onThrift: () => _showThriftSheet(context),
                  onReverseLoop: () => _showReverseFashionSheet(context),
                  onCurated: () {},
                  onAIStyle: () => _showAIStyleSheet(context),
                  onTryBefore: () => _showTryBeforeBuySheet(context),
                ),
                _SwipeStyleTab(cart: cart),
                _DiscoverTab(
                  wishlist: _wishlist,
                  onThrift: () => _showThriftSheet(context),
                  onReverseLoop: () => _showReverseFashionSheet(context),
                  onAIStyle: () => _showAIStyleSheet(context),
                  onTryBefore: () => _showTryBeforeBuySheet(context),
                  onProfile: () => _showProfileSheet(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Persistent tab bar delegate
// ─────────────────────────────────────────────
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final double height;
  const _TabBarDelegate({required this.tabBar, required this.height});

  @override double get minExtent => height;
  @override double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: _A.black, child: tabBar);
  }

  @override
  bool shouldRebuild(_TabBarDelegate old) => tabBar != old.tabBar || height != old.height;
}

// ─────────────────────────────────────────────
//  Browse Tab
// ─────────────────────────────────────────────
class _BrowseTab extends StatelessWidget {
  final List<Map<String, String>> categories;
  final String selectedCategory;
  final List<dynamic> filteredProducts;
  final String searchQuery;
  final CartProvider cart;
  final WishlistNotifier wishlist;
  final Map<int, GlobalKey>? productKeys;
  final ValueChanged<String> onCategoryTap;
  final VoidCallback onThrift;
  final VoidCallback onReverseLoop;
  final VoidCallback onCurated;
  final VoidCallback onAIStyle;
  final VoidCallback onTryBefore;
  final ScrollController? scrollController;

  const _BrowseTab({
    required this.categories,
    required this.selectedCategory,
    required this.filteredProducts,
    required this.searchQuery,
    required this.cart,
    required this.wishlist,
    required this.onCategoryTap,
    required this.onThrift,
    required this.onReverseLoop,
    required this.onCurated,
    required this.onAIStyle,
    required this.onTryBefore,
    this.productKeys,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Delivery timer
        const SliverToBoxAdapter(child: _DeliveryTimerBanner()),

        // Feature chips
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _FeatureHighlightRow(
              onThrift: onThrift,
              onReverseLoop: onReverseLoop,
              onCurated: onCurated,
              onAIStyle: onAIStyle,
              onTryBefore: onTryBefore,
            ),
          ),
        ),

        // Curated collections
        const SliverToBoxAdapter(child: _CuratedCollectionsSection()),

        // Category chips
        SliverToBoxAdapter(
          child: SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              children: categories.map((cat) {
                final sel = cat['name'] == selectedCategory;
                return GestureDetector(
                  onTap: () => onCategoryTap(cat['name']!),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? _A.black : Colors.white,
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(color: sel ? _A.black : _A.goldLight, width: 1.5),
                    ),
                    child: Text(
                      cat['name']!.toUpperCase(),
                      style: _A.sportLabel(size: 11, spacing: 1.5, color: sel ? Colors.white : _A.mid, weight: sel ? FontWeight.w800 : FontWeight.w500),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // Count bar
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                const _ThreeStripes(color: _A.gold, height: 2.5),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    searchQuery.isNotEmpty
                      ? 'RESULTS FOR "$searchQuery"'
                      : selectedCategory == 'All' ? 'ALL PIECES' : selectedCategory.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _A.sportLabel(size: 10, spacing: 2.5, weight: FontWeight.w700),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(color: _A.black, borderRadius: BorderRadius.circular(2)),
                  child: Text('${filteredProducts.length}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _A.gold)),
                ),
              ],
            ),
          ),
        ),

        // Grid or empty
        if (filteredProducts.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const _ThreeStripes(color: _A.goldLight, height: 5),
                  const SizedBox(height: 20),
                  Text('NOTHING FOUND', style: _A.sportLabel(size: 16, spacing: 3, color: _A.black, weight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text('Try a different search', style: _A.sportLabel(size: 13, color: _A.mid)),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.58,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final product = filteredProducts[index];
                  final isInCart = cart.isInCart(product.id);
                  productKeys?[index] ??= GlobalKey();
                  final card = _FashionProductCard(
                    product: product,
                    isInCart: isInCart,
                    cart: cart,
                    wishlist: wishlist,
                  );
                  return productKeys != null
                    ? KeyedSubtree(key: productKeys![index], child: card)
                    : card;
                },
                childCount: filteredProducts.length,
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  Discover Tab — feature hub
// ─────────────────────────────────────────────
class _DiscoverTab extends StatelessWidget {
  final WishlistNotifier wishlist;
  final VoidCallback onThrift;
  final VoidCallback onReverseLoop;
  final VoidCallback onAIStyle;
  final VoidCallback onTryBefore;
  final VoidCallback onProfile;

  const _DiscoverTab({
    required this.wishlist,
    required this.onThrift,
    required this.onReverseLoop,
    required this.onAIStyle,
    required this.onTryBefore,
    required this.onProfile,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 20),
      physics: const BouncingScrollPhysics(),
      children: [
        // Section heading
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('YOUR UNIVERSE', style: _A.sportLabel(size: 9, spacing: 2.5, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('InstaStyle Features', style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w900, color: _A.black)),
              ]),
              const Spacer(),
              const _ThreeStripes(color: _A.gold, height: 4),
            ],
          ),
        ),

        // Feature grid — 2-col
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.4,
            children: [
              _DiscoverCard(icon: Icons.bolt, label: 'Instant\nDelivery', sub: '15–20 min', accent: _A.gold, onTap: () {}),
              _DiscoverCard(icon: Icons.local_shipping_outlined, label: 'Try Before\nYou Buy', sub: '48hr home trial', accent: _A.dislike, onTap: onTryBefore),
              _DiscoverCard(icon: Icons.recycling, label: 'Thrift\nMarketplace', sub: 'Pre-loved fashion', accent: _A.green, onTap: onThrift),
              _DiscoverCard(icon: Icons.loop, label: 'Fashion\nLoop', sub: 'Return & recycle', accent: _A.goldDark, onTap: onReverseLoop),
              _DiscoverCard(icon: Icons.auto_awesome, label: 'AI Style\nAdvisor', sub: 'Personalised looks', accent: Color(0xFF4F7BBB), onTap: onAIStyle),
              _DiscoverCard(icon: Icons.swap_horiz, label: 'SwipeStyle™', sub: 'Tinder for fashion', accent: _A.black, onTap: () {}),
              _DiscoverCard(icon: Icons.tune, label: 'Style\nCustomise', sub: 'Size, fit & colour', accent: _A.gold, onTap: () => _showCustomisationSheet(context)),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Account quick links
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  const _ThreeStripes(color: _A.gold, height: 2.5),
                  const SizedBox(width: 10),
                  Text('MY ACCOUNT', style: _A.sportLabel(size: 10, spacing: 2.5, weight: FontWeight.w700)),
                ]),
              ),
              _AccountTile(icon: Icons.person_outline, label: 'Profile & Preferences', sub: 'Style, addresses, details', onTap: onProfile),
              const SizedBox(height: 8),
              Consumer<WishlistNotifier>(
                builder: (_, wl, __) => _AccountTile(
                  icon: Icons.favorite_border,
                  label: 'Wishlist',
                  sub: '${wl.count} saved items',
                  onTap: () => _showWishlistSheet(context, wl),
                ),
              ),
              const SizedBox(height: 8),
              _AccountTile(icon: Icons.receipt_long_outlined, label: 'Order History', sub: 'Track, return, reorder', onTap: () {}),
              const SizedBox(height: 8),
              _AccountTile(icon: Icons.shopping_cart_checkout, label: 'Cart & Checkout', sub: 'Fast, seamless checkout', onTap: () {}),
            ],
          ),
        ),

        const SizedBox(height: 32),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  Discover Feature Card
// ─────────────────────────────────────────────
class _DiscoverCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final Color accent;
  final VoidCallback onTap;

  const _DiscoverCard({required this.icon, required this.label, required this.sub, required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _A.white,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: accent.withOpacity(0.25), width: 1.2),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: accent.withOpacity(0.12), borderRadius: BorderRadius.circular(2)),
              child: Icon(icon, color: accent, size: 18),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w900, color: _A.black, height: 1.2)),
                const SizedBox(height: 2),
                Text(sub.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: _A.sportLabel(size: 8, spacing: 0.5, color: accent)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Account Tile
// ─────────────────────────────────────────────
class _AccountTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final VoidCallback onTap;

  const _AccountTile({required this.icon, required this.label, required this.sub, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _A.white,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: _A.goldLight, width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: _A.gold),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w800, color: _A.black)),
                  Text(sub, style: _A.sportLabel(size: 9, spacing: 0.3, color: _A.mid)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 12, color: _A.mid),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Product Card — with Wishlist
// ─────────────────────────────────────────────
class _FashionProductCard extends StatelessWidget {
  final dynamic product;
  final bool isInCart;
  final CartProvider cart;
  final WishlistNotifier wishlist;

  const _FashionProductCard({
    required this.product,
    required this.isInCart,
    required this.cart,
    required this.wishlist,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: wishlist,
      builder: (context, _) {
        final isWishlisted = wishlist.isWishlisted(product.id);
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFFE8E3DC), width: 1),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image with actions overlay
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                    child: Container(
                      height: 130,
                      width: double.infinity,
                      color: const Color(0xFFF2EFE9),
                      child: product.imageUrl != null
                        ? Image.network(
                            product.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(child: Text(product.emoji ?? '👗', style: const TextStyle(fontSize: 44))),
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const Center(child: CircularProgressIndicator(color: _A.gold, strokeWidth: 1.5));
                            },
                          )
                        : Center(child: Text(product.emoji ?? '👗', style: const TextStyle(fontSize: 44))),
                    ),
                  ),
                  // Gold corner stripe
                  Positioned(top: 0, left: 0, child: Container(width: 4, height: 30, color: _A.gold)),
                  // Wishlist button
                  Positioned(
                    top: 6, right: 6,
                    child: GestureDetector(
                      onTap: () {
                        wishlist.toggle(product.id);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(wishlist.isWishlisted(product.id) ? '♥ Added to Wishlist' : '♡ Removed from Wishlist'),
                          duration: const Duration(seconds: 1),
                          backgroundColor: _A.black,
                        ));
                      },
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
                        ),
                        child: Icon(
                          isWishlisted ? Icons.favorite : Icons.favorite_border,
                          size: 14,
                          color: isWishlisted ? _A.dislike : _A.mid,
                        ),
                      ),
                    ),
                  ),

                ],
              ),

              // Product info
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _A.black, height: 1.25, letterSpacing: 0.1),
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(product.description, style: _A.sportLabel(size: 10, color: _A.mid), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('₹${product.price.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: _A.black)),
                          if (!isInCart)
                            GestureDetector(
                              onTap: () {
                                cart.addItem(product);
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text('${product.name} added to bag'),
                                  duration: const Duration(seconds: 1),
                                  backgroundColor: _A.black,
                                ));
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                color: _A.black,
                                child: Text('ADD', style: _A.sportLabel(size: 10, spacing: 1.5, color: Colors.white, weight: FontWeight.w800)),
                              ),
                            )
                          else
                            Container(
                              decoration: BoxDecoration(border: Border.all(color: _A.gold, width: 1.5)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  InkWell(
                                    onTap: () => cart.decreaseQuantity(product.id),
                                    child: const Padding(padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4), child: Icon(Icons.remove, size: 14, color: _A.gold)),
                                  ),
                                  Text('${cart.getQuantity(product.id)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: _A.goldDark)),
                                  InkWell(
                                    onTap: () => cart.addItem(product),
                                    child: const Padding(padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4), child: Icon(Icons.add, size: 14, color: _A.gold)),
                                  ),
                                ],
                              ),
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
      },
    );
  }
}

// ─────────────────────────────────────────────
//  Outfit card model
// ─────────────────────────────────────────────
class _OutfitCard {
  final String imageUrl;
  final String name;
  final String style;
  final String price;
  final String tag;

  const _OutfitCard({
    required this.imageUrl,
    required this.name,
    required this.style,
    required this.price,
    required this.tag,
  });
}

// ─────────────────────────────────────────────
//  SwipeStyle Tab
// ─────────────────────────────────────────────
class _SwipeStyleTab extends StatefulWidget {
  final CartProvider cart;
  const _SwipeStyleTab({required this.cart});

  @override
  State<_SwipeStyleTab> createState() => _SwipeStyleTabState();
}

class _SwipeStyleTabState extends State<_SwipeStyleTab>
    with TickerProviderStateMixin {
  final List<_OutfitCard> _deck = [
    _OutfitCard(imageUrl: 'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=600', name: 'Linen Co-ord Set', style: 'Minimal Chic', price: '₹3,499', tag: 'TRENDING'),
    _OutfitCard(imageUrl: 'https://images.unsplash.com/photo-1469334031218-e382a71b716b?w=600', name: 'Boho Maxi Dress', style: 'Bohemian', price: '₹2,899', tag: 'NEW'),
    _OutfitCard(imageUrl: 'https://images.unsplash.com/photo-1434389677669-e08b4cac3105?w=600', name: 'Structured Blazer', style: 'Power Dressing', price: '₹5,199', tag: 'BESTSELLER'),
    _OutfitCard(imageUrl: 'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=600', name: 'Oversized Knit', style: 'Cosy Edit', price: '₹1,999', tag: 'COSY PICK'),
    _OutfitCard(imageUrl: 'https://images.unsplash.com/photo-1496747611176-843222e1e57c?w=600', name: 'Denim Jacket', style: 'Street Classic', price: '₹2,599', tag: 'CLASSIC'),
    _OutfitCard(imageUrl: 'https://images.unsplash.com/photo-1509631179647-0177331693ae?w=600', name: 'Silk Slip Dress', style: 'Evening Edit', price: '₹4,299', tag: 'LUXE'),
  ];

  int _currentIndex = 0;
  final List<_OutfitCard> _liked = [];
  final List<_OutfitCard> _skipped = [];

  Offset _dragOffset = Offset.zero;
  double _angle = 0;
  bool _isDragging = false;
  late AnimationController _snapCtrl;
  late Animation<Offset> _snapAnim;
  late AnimationController _feedbackCtrl;
  bool _showLike    = false;
  bool _showDislike = false;

  @override
  void initState() {
    super.initState();
    _snapCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _feedbackCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
  }

  @override
  void dispose() {
    _snapCtrl.dispose();
    _feedbackCtrl.dispose();
    super.dispose();
  }

  bool get _deckDone => _currentIndex >= _deck.length;

  void _onDragUpdate(DragUpdateDetails d) {
    setState(() {
      _isDragging = true;
      _dragOffset += d.delta;
      _angle = _dragOffset.dx * 0.0015 * math.pi;
    });
  }

  void _onDragEnd(DragEndDetails d) {
    const threshold = 100.0;
    if (_dragOffset.dx > threshold) _swipeRight();
    else if (_dragOffset.dx < -threshold) _swipeLeft();
    else _snapBack();
  }

  void _snapBack() {
    final begin = _dragOffset;
    _snapAnim = Tween<Offset>(begin: begin, end: Offset.zero)
        .animate(CurvedAnimation(parent: _snapCtrl, curve: Curves.elasticOut));
    _snapCtrl.forward(from: 0).then((_) {
      setState(() { _dragOffset = Offset.zero; _angle = 0; _isDragging = false; });
    });
    _snapAnim.addListener(() {
      setState(() { _dragOffset = _snapAnim.value; _angle = _dragOffset.dx * 0.0015 * math.pi; });
    });
  }

  void _swipeRight({bool fromButton = false}) async {
    if (_deckDone) return;
    setState(() { _showLike = true; _isDragging = true; });
    final begin = fromButton ? Offset.zero : _dragOffset;
    _snapAnim = Tween<Offset>(begin: begin, end: Offset(MediaQuery.of(context).size.width * 1.5, 0))
        .animate(CurvedAnimation(parent: _snapCtrl, curve: Curves.easeInCubic));
    _snapAnim.addListener(() {
      setState(() { _dragOffset = _snapAnim.value; _angle = _dragOffset.dx * 0.0015 * math.pi; });
    });
    await _snapCtrl.forward(from: 0);
    setState(() {
      _liked.add(_deck[_currentIndex]);
      _currentIndex++;
      _dragOffset = Offset.zero; _angle = 0; _isDragging = false; _showLike = false;
    });
    _showFeedbackSnack(liked: true);
  }

  void _swipeLeft({bool fromButton = false}) async {
    if (_deckDone) return;
    setState(() { _showDislike = true; _isDragging = true; });
    final begin = fromButton ? Offset.zero : _dragOffset;
    _snapAnim = Tween<Offset>(begin: begin, end: Offset(-MediaQuery.of(context).size.width * 1.5, 0))
        .animate(CurvedAnimation(parent: _snapCtrl, curve: Curves.easeInCubic));
    _snapAnim.addListener(() {
      setState(() { _dragOffset = _snapAnim.value; _angle = _dragOffset.dx * 0.0015 * math.pi; });
    });
    await _snapCtrl.forward(from: 0);
    setState(() {
      _skipped.add(_deck[_currentIndex]);
      _currentIndex++;
      _dragOffset = Offset.zero; _angle = 0; _isDragging = false; _showDislike = false;
    });
  }

  void _showFeedbackSnack({required bool liked}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(liked ? '✦ Saved to your style picks!' : '✗ Not your vibe — next!'),
      duration: const Duration(milliseconds: 900),
      backgroundColor: liked ? _A.black : Colors.grey.shade700,
    ));
  }

  void _resetDeck() {
    setState(() {
      _currentIndex = 0; _liked.clear(); _skipped.clear();
      _dragOffset = Offset.zero; _angle = 0; _isDragging = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return SizedBox.expand(
      child: ColoredBox(
        color: _A.surface,
        child: Column(
          children: [
            // SwipeStyle header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE0DAD2), width: 1))),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('OUTFIT BUILDER', style: _A.sportLabel(size: 10, spacing: 3)),
                    const SizedBox(height: 2),
                    Text('SwipeStyle™', style: GoogleFonts.dmSans(fontSize: 24, fontWeight: FontWeight.w900, color: _A.black)),
                  ],
                ),
                const Spacer(),
                const _ThreeStripes(color: _A.gold, height: 4),
                const SizedBox(width: 10),
                if (!_deckDone)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    color: _A.black,
                    child: Text('${_deck.length - _currentIndex} LEFT',
                      style: _A.sportLabel(size: 10, spacing: 1.5, color: _A.gold, weight: FontWeight.w800)),
                  ),
              ],
            ),
          ),

          // Gesture hint
          if (!_deckDone)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.arrow_back, size: 12, color: _A.dislike),
                  const SizedBox(width: 4),
                  Text('SKIP', style: _A.sportLabel(size: 10, spacing: 1.5, color: _A.dislike)),
                  const SizedBox(width: 24),
                  Text('SWIPE TO STYLE', style: _A.sportLabel(size: 10, spacing: 1.5, color: _A.mid)),
                  const SizedBox(width: 24),
                  Text('SAVE', style: _A.sportLabel(size: 10, spacing: 1.5, color: _A.like)),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward, size: 12, color: _A.like),
                ],
              ),
            ),

          // Card stack
          Expanded(
            child: _deckDone
              ? _buildDoneState()
              : Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_currentIndex + 1 < _deck.length)
                      Positioned(
                        top: 20,
                        child: Transform.scale(
                          scale: 0.93,
                          child: _buildCard(_deck[_currentIndex + 1], size, isTop: false),
                        ),
                      ),

                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragUpdate: _onDragUpdate,
                      onHorizontalDragEnd: _onDragEnd,
                      child: Transform.translate(
                        offset: _dragOffset,
                        child: Transform.rotate(
                          angle: _angle,
                          child: Stack(
                            children: [
                              _buildCard(_deck[_currentIndex], size, isTop: true),
                              if (_dragOffset.dx > 20 || _showLike)
                                Positioned(
                                  top: 28, left: 20,
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 120),
                                    opacity: (_dragOffset.dx / 100).clamp(0.0, 1.0),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                      decoration: BoxDecoration(border: Border.all(color: _A.like, width: 3)),
                                      child: Text('SAVE', style: _A.sportLabel(size: 24, spacing: 3, color: _A.like, weight: FontWeight.w900)),
                                    ),
                                  ),
                                ),
                              if (_dragOffset.dx < -20 || _showDislike)
                                Positioned(
                                  top: 28, right: 20,
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 120),
                                    opacity: (-_dragOffset.dx / 100).clamp(0.0, 1.0),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                      decoration: BoxDecoration(border: Border.all(color: _A.dislike, width: 3)),
                                      child: Text('NOPE', style: _A.sportLabel(size: 24, spacing: 3, color: _A.dislike, weight: FontWeight.w900)),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
          ),

          // Action buttons
          if (!_deckDone)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ActionButton(icon: Icons.close, color: _A.dislike, onTap: () => _swipeLeft(fromButton: true)),
                    const SizedBox(width: 12),

                    _ActionButton(icon: Icons.favorite, color: _A.like, onTap: () => _swipeRight(fromButton: true), large: true),
                    const SizedBox(width: 12),
                    _ActionButton(icon: Icons.favorite_border, color: _A.gold, onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Added to Wishlist'), duration: Duration(seconds: 1), backgroundColor: _A.black,
                      ));
                    }),
                    const SizedBox(width: 12),
                    _ActionButton(icon: Icons.shopping_bag_outlined, color: _A.gold, onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Browse products to add to bag'), duration: Duration(seconds: 1), backgroundColor: _A.black,
                      ));
                    }),
                  ],
                ),
              ),
            ),
        ],
      ),
      ),
    );
  }

  Widget _buildCard(_OutfitCard card, Size size, {required bool isTop}) {
    final w = size.width * 0.82;
    final h = size.height * 0.44;

    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        boxShadow: isTop
          ? [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 30, offset: const Offset(0, 10))]
          : [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.network(
                card.imageUrl, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: _A.black, child: const Center(child: Text('👗', style: TextStyle(fontSize: 80)))),
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return Container(color: _A.black, child: const Center(child: CircularProgressIndicator(color: _A.gold, strokeWidth: 1.5)));
                },
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0x44000000), Color(0xEE000000)],
                    stops: [0.45, 0.65, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(top: 0, bottom: 0, left: 0, child: Container(width: 5, color: _A.gold)),
            Positioned(
              top: 16, right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                color: _A.gold,
                child: Text(card.tag, style: _A.sportLabel(size: 9, spacing: 1.5, color: _A.black, weight: FontWeight.w800)),
              ),
            ),

            Positioned(
              bottom: 18, left: 18, right: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(card.style.toUpperCase(), style: _A.sportLabel(size: 9, spacing: 2.5, color: _A.gold, weight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(card.name, style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(card.price, style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white,)),
                      Row(children: [
                        const Icon(Icons.swipe_left, color: Colors.white54, size: 15),
                        const SizedBox(width: 5),
                        Text('swipe', style: _A.sportLabel(size: 10, spacing: 1, color: Colors.white54)),
                        const SizedBox(width: 5),
                        const Icon(Icons.swipe_right, color: Colors.white54, size: 15),
                      ]),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoneState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _ThreeStripes(color: _A.gold, height: 6),
            const SizedBox(height: 24),
            Text('YOUR STYLE\nREPORT', textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(fontSize: 28, fontWeight: FontWeight.w900, color: _A.black, height: 1.1, letterSpacing: -0.5)),
            const SizedBox(height: 10),
            Text(
              'You saved ${_liked.length} look${_liked.length == 1 ? '' : 's'} and skipped ${_skipped.length}.',
              textAlign: TextAlign.center,
              style: _A.sportLabel(size: 13, color: _A.mid),
            ),
            if (_liked.isNotEmpty) ...[
              const SizedBox(height: 20),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  shrinkWrap: true,
                  itemCount: _liked.length,
                  itemBuilder: (_, i) => Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 68, height: 80,
                    decoration: BoxDecoration(border: Border.all(color: _A.gold, width: 2)),
                    child: Image.network(_liked[i].imageUrl, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(child: Text('👗', style: TextStyle(fontSize: 28)))),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 28),
            GestureDetector(
              onTap: _resetDeck,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
                color: _A.black,
                child: Text('EXPLORE MORE STYLES', style: _A.sportLabel(size: 12, spacing: 2.5, color: Colors.white, weight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Circular action button
// ─────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool large;

  const _ActionButton({required this.icon, required this.color, required this.onTap, this.large = false});

  @override
  Widget build(BuildContext context) {
    final size = large ? 60.0 : 46.0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          color: large ? color : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: large ? color : color.withOpacity(0.4), width: 2),
          boxShadow: [BoxShadow(color: color.withOpacity(0.25), blurRadius: large ? 16 : 8, offset: const Offset(0, 4))],
        ),
        child: Icon(icon, color: large ? Colors.white : color, size: large ? 26 : 20),
      ),
    );
  }
}