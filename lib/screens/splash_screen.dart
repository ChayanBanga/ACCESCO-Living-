import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _videoReady = false;
  bool _videoFailed = false;
  bool _navigated = false; // ✅ FIX 1: guard against double-navigation

  // Fallback animation controllers (used if video fails to load)
  late AnimationController _fallbackController;
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;

  @override
  void initState() {
    super.initState();

    // Hide status/nav bars for a true full-screen splash
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Fallback animation setup
    _fallbackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _logoScale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _fallbackController,
        curve: const Interval(0.0, 0.55, curve: Curves.elasticOut),
      ),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fallbackController,
        curve: const Interval(0.0, 0.35, curve: Curves.easeIn),
      ),
    );

    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fallbackController,
        curve: const Interval(0.45, 0.75, curve: Curves.easeIn),
      ),
    );

    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _fallbackController,
        curve: const Interval(0.45, 0.75, curve: Curves.easeOutCubic),
      ),
    );

    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      // ✅ FIX 2: use lowercase filename — Android asset paths are case-sensitive
      // Rename your file from IMG_8621.MP4 → splash_video.mp4 in your assets folder
      final controller =
          VideoPlayerController.asset('assets/videos/splash_video.mp4');

      // ✅ FIX 3: add a timeout so the app never hangs on slow/failing init
      await controller.initialize().timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('Video init timed out'),
      );

      if (!mounted) {
        controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _videoReady = true;
      });

      await controller.play();

      // Listen for video completion
      controller.addListener(_onVideoProgress);
    } catch (e) {
      debugPrint('SplashScreen: video failed — $e');
      // Video failed — run fallback animation
      if (mounted) {
        setState(() => _videoFailed = true);
        _runFallbackAnimation();
      }
    }
  }

  void _onVideoProgress() {
    if (_controller == null) return;
    final pos = _controller!.value.position;
    final dur = _controller!.value.duration;

    // Navigate when video finishes (with 200ms buffer)
    if (dur.inMilliseconds > 0 &&
        pos.inMilliseconds >= dur.inMilliseconds - 200) {
      _controller!.removeListener(_onVideoProgress);
      _navigateToApp();
    }
  }

  Future<void> _runFallbackAnimation() async {
    await _fallbackController.forward();
    // Hold for a moment then navigate
    await Future.delayed(const Duration(milliseconds: 600));
    _navigateToApp();
  }

  void _navigateToApp() {
    // ✅ FIX 4: guard against calling navigate twice (listener + timeout race)
    if (!mounted || _navigated) return;
    _navigated = true;

    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    // ✅ FIX 5: use pushReplacementNamed instead of pop()
    // pop() is fragile with the nested Navigator approach in main.dart
    Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  void dispose() {
    _controller?.removeListener(_onVideoProgress);
    _controller?.dispose();
    _fallbackController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _videoReady && _controller != null
          ? _buildVideoSplash()
          : _videoFailed
              ? _buildFallbackSplash()
              : _buildLoadingState(),
    );
  }

  // ── Video splash — full screen video ──────────────────
  Widget _buildVideoSplash() {
    return GestureDetector(
      onTap: _navigateToApp, // Allow tapping to skip
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _controller!.value.size.width,
            height: _controller!.value.size.height,
            child: VideoPlayer(_controller!),
          ),
        ),
      ),
    );
  }

  // ── Loading state — shown while video initialises ─────
  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        color: Color(0xFF6A1B9A),
        strokeWidth: 2,
      ),
    );
  }

  // ── Fallback splash — animated logo + brand name ──────
  Widget _buildFallbackSplash() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6A1B9A), Color(0xFF4A148C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Background decorative circles
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
              ),
            ),
          ),

          // Centre content
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo
                AnimatedBuilder(
                  animation: _fallbackController,
                  builder: (_, __) => FadeTransition(
                    opacity: _logoFade,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 30,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(18),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.asset(
                            'assets/images/accesco_logo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.shopping_bag_rounded,
                              size: 60,
                              color: Color(0xFF6A1B9A),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Brand name + tagline
                AnimatedBuilder(
                  animation: _fallbackController,
                  builder: (_, __) => FadeTransition(
                    opacity: _textFade,
                    child: SlideTransition(
                      position: _textSlide,
                      child: Column(
                        children: [
                          const Text(
                            'ACCESSO LIVING',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 2.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Smartly Simplified For Everyday India',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.75),
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0.4,
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

          // Skip hint at bottom
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: GestureDetector(
              onTap: _navigateToApp,
              child: AnimatedBuilder(
                animation: _fallbackController,
                builder: (_, __) => FadeTransition(
                  opacity: _textFade,
                  child: Center(
                    child: Text(
                      'Tap anywhere to continue',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 12,
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
}
