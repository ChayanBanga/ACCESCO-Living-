import 'dart:async';
import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class HeroBanner extends StatefulWidget {
  final List<String> bannerImages;
  final Color indicatorColor;
  final double height;

  const HeroBanner({
    super.key,
    required this.bannerImages,
    required this.indicatorColor,
    this.height = 180,
  });

  @override
  State<HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends State<HeroBanner> {
  final PageController _pageController = PageController(viewportFraction: 1.0);
  int _currentIndex = 0;
  Timer? _autoPlayTimer;
  bool _isUserScrolling = false;

  @override
  void initState() {
    super.initState();
    _startAutoPlay();
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_isUserScrolling && _pageController.hasClients) {
        final next = (_currentIndex + 1) % widget.bannerImages.length;
        _pageController.animateToPage(
          next,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _onUserScrollStart() {
    _isUserScrolling = true;
    _autoPlayTimer?.cancel();
  }

  void _onUserScrollEnd() {
    _isUserScrolling = false;
    // Resume auto-play after a short pause once the user lifts their finger
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _startAutoPlay();
    });
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          Positioned.fill(
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollStartNotification &&
                    notification.dragDetails != null) {
                  _onUserScrollStart();
                } else if (notification is ScrollEndNotification) {
                  _onUserScrollEnd();
                }
                return false;
              },
              child: PageView.builder(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                itemCount: widget.bannerImages.length,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                },
                itemBuilder: (context, index) {
                  return Image.network(
                    widget.bannerImages[index],
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              widget.indicatorColor.withOpacity(0.7),
                              widget.indicatorColor,
                            ],
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.image_outlined,
                            size: 60,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              widget.indicatorColor.withOpacity(0.3),
                              widget.indicatorColor.withOpacity(0.5),
                            ],
                          ),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
          Positioned(
            bottom: 68,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedSmoothIndicator(
                activeIndex: _currentIndex,
                count: widget.bannerImages.length,
                effect: ExpandingDotsEffect(
                  activeDotColor: Colors.white,
                  dotColor: Colors.white.withOpacity(0.4),
                  dotHeight: 7,
                  dotWidth: 7,
                  expansionFactor: 3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
