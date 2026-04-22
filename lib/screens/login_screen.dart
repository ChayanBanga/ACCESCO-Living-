import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animate_do/animate_do.dart';
import 'package:geolocator/geolocator.dart';
import '../screens/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {

  // ── Step control ─────────────────────────────────────────────────
  // Steps:  0 = phone entry  |  1 = OTP entry
  int _step = 0;
  bool _isSignup = false;

  // ── Controllers ──────────────────────────────────────────────────
  final _phoneController   = TextEditingController();
  final _nameController    = TextEditingController();
  final _emailController   = TextEditingController();
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes =
      List.generate(6, (_) => FocusNode());

  // ── Form keys ─────────────────────────────────────────────────────
  final _phoneFormKey = GlobalKey<FormState>();
  final _otpFormKey   = GlobalKey<FormState>();

  // ── State ─────────────────────────────────────────────────────────
  bool _isLoading  = false;
  String _verificationId = '';
  int?   _resendToken;
  int    _resendTimer = 30;
  Timer? _timer;

  // ── Firebase ──────────────────────────────────────────────────────
  final FirebaseAuth      _auth      = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── Animations ────────────────────────────────────────────────────
  late AnimationController _animController;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  // ─────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _phoneController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    for (final c in _otpControllers) c.dispose();
    for (final f in _otpFocusNodes) f.dispose();
    _timer?.cancel();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════
  //  STEP 1 — Send OTP
  // ══════════════════════════════════════════════════════════════════
  Future<void> _sendOtp() async {
    if (!_phoneFormKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    final rawPhone = _phoneController.text.trim().replaceAll(' ', '');
    // Prepend +91 if user didn't include country code
    final phone = rawPhone.startsWith('+') ? rawPhone : '+91$rawPhone';

    await _auth.verifyPhoneNumber(
      phoneNumber: phone,
      forceResendingToken: _resendToken,
      timeout: const Duration(seconds: 60),

      // Auto-retrieval on Android (SMS auto-fill)
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _signInWithCredential(credential);
      },

      verificationFailed: (FirebaseAuthException e) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showError(_getFirebaseErrorMessage(e.code));
        }
      },

      codeSent: (String verificationId, int? resendToken) {
        if (mounted) {
          setState(() {
            _verificationId = verificationId;
            _resendToken    = resendToken;
            _isLoading      = false;
            _step           = 1;
          });
          _startResendTimer();
        }
      },

      codeAutoRetrievalTimeout: (String verificationId) {
        if (mounted) _verificationId = verificationId;
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════
  //  STEP 2 — Verify OTP
  // ══════════════════════════════════════════════════════════════════
  Future<void> _verifyOtp() async {
    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length < 6) {
      _showError('Please enter the complete 6-digit OTP');
      return;
    }

    if (_verificationId.isEmpty) {
      _showError('Session expired. Please request a new OTP.');
      _goBackToPhone();
      return;
    }

    if (_isLoading) return; // prevent double calls

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: otp,
      );
      await _signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError(_getFirebaseErrorMessage(e.code));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('⚠️ Something went wrong. Please try again.');
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════
  //  Sign-in with credential — shared by both auto & manual OTP
  // ══════════════════════════════════════════════════════════════════
  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    try {
      debugPrint('🔥 STEP 1: Signing in...');
      final userCredential = await _auth.signInWithCredential(credential);
      final uid = userCredential.user!.uid;
      debugPrint('🔥 STEP 2: UID = $uid');
      debugPrint('🔥 STEP 3: isSignup = $_isSignup, name = ${_nameController.text.trim()}');

      final doc = await _firestore.collection('users').doc(uid).get();
      final isNew = !doc.exists;
      debugPrint('🔥 STEP 4: doc exists = ${doc.exists}, isNew = $isNew');

      if (isNew || _isSignup) {
        final Map<String, dynamic> userData = {
          'phone': userCredential.user?.phoneNumber ?? '+91${_phoneController.text.trim().replaceAll(' ', '')}',
          'createdAt': FieldValue.serverTimestamp(),
          'vegMode': false,
          'healthyMode': false,
          'walletBalance': 0,
          'memberTier': 'Silver',
          'totalOrders': 0,
          'loyaltyPoints': 0,
        };
        if (_nameController.text.trim().isNotEmpty) {
          userData['name'] = _nameController.text.trim();
        }
        if (_emailController.text.trim().isNotEmpty) {
          userData['email'] = _emailController.text.trim();
        }
        debugPrint('🔥 STEP 5: Writing to Firestore... $userData');
        await _firestore.collection('users').doc(uid).set(userData, SetOptions(merge: true));
        debugPrint('🔥 STEP 6: Firestore write SUCCESS ✅');
        _showSuccess('🎉 Account created successfully! Welcome aboard!');
      } else {
        debugPrint('🔥 STEP 5: Existing user - skipping write');
        _showSuccess('👋 Welcome back! Let\'s start shopping!');
      }

      _timer?.cancel();
      _clearFields();
      if (mounted) setState(() => _isLoading = false);
      await _requestLocationPermission();
      // Navigate to home explicitly
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('🔥 FirebaseAuthException: ${e.code} - ${e.message}');
      if (mounted) {
        setState(() => _isLoading = false);
        _showError(_getFirebaseErrorMessage(e.code));
      }
    } catch (e, stack) {
      debugPrint('🔥 CATCH ERROR: $e');
      debugPrint('🔥 STACK: $stack');
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('⚠️ Error: ${e.toString()}');
      }
    }
  }

  // ── Resend timer ──────────────────────────────────────────────────
  void _startResendTimer() {
    setState(() => _resendTimer = 30);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_resendTimer == 0) {
        t.cancel();
      } else {
        setState(() => _resendTimer--);
      }
    });
  }

  // ── Go back to phone step ─────────────────────────────────────────
  void _goBackToPhone() {
    _timer?.cancel();
    for (final c in _otpControllers) c.clear();
    setState(() {
      _step       = 0;
      _isLoading  = false;
    });
  }

  // ── Location ──────────────────────────────────────────────────────
  Future<void> _requestLocationPermission() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied && mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: const Row(children: [
              Icon(Icons.location_on, color: Color(0xFFFC8019)),
              SizedBox(width: 8),
              Text('Enable Location',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            ]),
            content: const Text(
              'Accesso Living uses your location to show nearby '
              'restaurants, stores, and delivery estimates. Please '
              'enable location access for the best experience.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Maybe Later'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await Geolocator.openLocationSettings();
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7A164B)),
                child: const Text('Enable Now',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
    } catch (_) {}
  }

  // ── Helpers ───────────────────────────────────────────────────────
  void _clearFields() {
    _phoneController.clear();
    _nameController.clear();
    _emailController.clear();
    for (final c in _otpControllers) c.clear();
  }

  String _getFirebaseErrorMessage(String code) {
    switch (code) {
      case 'invalid-phone-number':
        return '📱 Invalid phone number. Use format: 9876543210';
      case 'invalid-verification-code':
        return '🔢 Wrong OTP. Please check and try again.';
      case 'session-expired':
        return '⏱️ OTP expired. Please request a new one.';
      case 'network-request-failed':
        return '📡 No internet connection. Check your network.';
      case 'too-many-requests':
        return '⏱️ Too many attempts. Please try again later.';
      case 'quota-exceeded':
        return '⚠️ SMS quota exceeded. Please try after some time.';
      default:
        return '⚠️ Authentication failed. Please try again.';
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14)),
          ),
        ]),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'DISMISS',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_outline,
              color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14)),
          ),
        ]),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF7A164B),
      body: Container(
        color: const Color(0xFF7A164B),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(24.0),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ── Logo ──────────────────────────────────────
                      FadeInDown(
                        duration: const Duration(milliseconds: 700),
                        child: Image.asset(
                          'assets/images/accesco_logo.png',
                          width: 160,
                          height: 160,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.shopping_bag,
                            size: 100,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Divider ───────────────────────────────────
                      FadeInDown(
                        delay: const Duration(milliseconds: 150),
                        child: Container(
                          width: 160,
                          height: 1.0,
                          color: Colors.white.withOpacity(0.35),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── Title ─────────────────────────────────────
                      FadeInDown(
                        delay: const Duration(milliseconds: 200),
                        child: Column(
                          children: [
                            const Text(
                              'ACCESCO LIVING',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 2.5,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'SMARTLY SIMPLIFIED FOR EVERYDAY INDIA',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withOpacity(0.75),
                                fontWeight: FontWeight.w400,
                                letterSpacing: 1.8,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 50),

                      // ── Card ──────────────────────────────────────
                      FadeInUp(
                        delay: const Duration(milliseconds: 400),
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 450),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 30,
                                offset: const Offset(0, 15),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 400),
                              transitionBuilder: (child, animation) =>
                                  FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0.05, 0),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              ),
                              child: _step == 0
                                  ? _buildPhoneStep()
                                  : _buildOtpStep(),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      // ── Footer ────────────────────────────────────
                      FadeInUp(
                        delay: const Duration(milliseconds: 600),
                        child: Column(
                          children: [
                            Text(
                              '© 2025 Accesco Living Pvt Ltd',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Your everyday super app',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  //  STEP 0 — Phone number + (signup fields)
  // ══════════════════════════════════════════════════════════════════
  Widget _buildPhoneStep() {
    return Form(
      key: _phoneFormKey,
      child: Column(
        key: const ValueKey('phone_step'),
        children: [
          // ── Toggle ──────────────────────────────────────────────
          _buildToggle(),

          const SizedBox(height: 30),

          // ── Name (signup only) ───────────────────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _isSignup
                ? Column(children: [
                    _buildTextField(
                      controller: _nameController,
                      label: 'Full Name',
                      icon: Icons.person_outline,
                      validator: (v) {
                        if (_isSignup &&
                            (v == null || v.trim().isEmpty)) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                  ])
                : const SizedBox.shrink(),
          ),

          // ── Phone ────────────────────────────────────────────────
          _buildPhoneField(),

          const SizedBox(height: 20),

          // ── Email (signup only, optional) ────────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _isSignup
                ? Column(children: [
                    _buildTextField(
                      controller: _emailController,
                      label: 'Email (Optional)',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v != null &&
                            v.trim().isNotEmpty &&
                            !v.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                  ])
                : const SizedBox.shrink(),
          ),

          if (!_isSignup) const SizedBox(height: 10),

          // ── Send OTP button ──────────────────────────────────────
          _buildPrimaryButton(
            label: 'Send OTP',
            icon: Icons.sms_outlined,
            onPressed: _sendOtp,
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  //  STEP 1 — OTP boxes
  // ══════════════════════════════════════════════════════════════════
  Widget _buildOtpStep() {
    final rawPhone = _phoneController.text.trim();
    final displayPhone =
        rawPhone.startsWith('+91') ? rawPhone : '+91 $rawPhone';

    return Form(
      key: _otpFormKey,
      child: Column(
        key: const ValueKey('otp_step'),
        children: [
          // ── Back button ──────────────────────────────────────────
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: _goBackToPhone,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back_ios_new_rounded,
                      size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text('Change number',
                      style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                          fontSize: 13)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Heading ──────────────────────────────────────────────
          const Text(
            'Enter OTP',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A2E)),
          ),
          const SizedBox(height: 8),
          Text(
            'We sent a 6-digit code to\n$displayPhone',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 14,
                height: 1.5),
          ),

          const SizedBox(height: 32),

          // ── 6 OTP boxes ──────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (i) => _buildOtpBox(i)),
          ),

          const SizedBox(height: 32),

          // ── Verify button ────────────────────────────────────────
          _buildPrimaryButton(
            label: 'Verify & Continue',
            icon: Icons.verified_outlined,
            onPressed: _verifyOtp,
          ),

          const SizedBox(height: 24),

          // ── Resend ───────────────────────────────────────────────
          _resendTimer > 0
              ? Text(
                  'Resend OTP in ${_resendTimer}s',
                  style: TextStyle(
                      color: Colors.grey.shade500, fontSize: 14),
                )
              : GestureDetector(
                  onTap: () {
                    _goBackToPhone();
                    Future.delayed(
                      const Duration(milliseconds: 100),
                      _sendOtp,
                    );
                  },
                  child: Text(
                    'Resend OTP',
                    style: TextStyle(
                      color: const Color(0xFF7A164B),
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      decoration: TextDecoration.underline,
                      decorationColor: const Color(0xFF7A164B),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  //  SUB-WIDGETS
  // ══════════════════════════════════════════════════════════════════

  // Login / Sign Up toggle (same style as original)
  Widget _buildToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          _toggleButton('Login',   false),
          _toggleButton('Sign Up', true),
        ],
      ),
    );
  }

  Widget _toggleButton(String label, bool isSignupTab) {
    final active = _isSignup == isSignupTab;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_isSignup != isSignupTab) {
            setState(() {
              _isSignup = isSignupTab;
              _step = 0;
              _verificationId = '';
              _nameController.clear();
              _emailController.clear();
              _phoneController.clear();
              for (final c in _otpControllers) c.clear();
            });
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF7A164B) : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: const Color(0xFF7A164B).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: active ? Colors.white : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }

  // Phone field with +91 prefix
  Widget _buildPhoneField() {
    return TextFormField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
      ],
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: 'Phone Number',
        labelStyle: TextStyle(color: Colors.grey.shade600),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 16, right: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🇮🇳 ',
                  style: TextStyle(fontSize: 18)),
              Text('+91',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700)),
              Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 1,
                  height: 22,
                  color: Colors.grey.shade300),
            ],
          ),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              const BorderSide(color: Color(0xFF7A164B), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.red.shade300),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              BorderSide(color: Colors.red.shade400, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 18),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) {
          return 'Please enter your phone number';
        }
        if (v.trim().length < 10) {
          return 'Enter a valid 10-digit number';
        }
        return null;
      },
    );
  }

  // Single OTP digit box
  Widget _buildOtpBox(int index) {
    return SizedBox(
      width: 44,
      height: 54,
      child: TextFormField(
        controller: _otpControllers[index],
        focusNode: _otpFocusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(
            fontSize: 20, fontWeight: FontWeight.w800),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: Color(0xFF7A164B), width: 2),
          ),
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: (v) {
          if (v.isNotEmpty && index < 5) {
            FocusScope.of(context)
                .requestFocus(_otpFocusNodes[index + 1]);
          }
          if (v.isEmpty && index > 0) {
            FocusScope.of(context)
                .requestFocus(_otpFocusNodes[index - 1]);
          }
          // Auto-submit when all 6 digits filled
          final otp =
              _otpControllers.map((c) => c.text).join();
          if (otp.length == 6) _verifyOtp();
        },
      ),
    );
  }

  // Generic text field (reused for name / email)
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style:
          const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade600),
        prefixIcon: Icon(icon, color: const Color(0xFF7A164B)),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              const BorderSide(color: Color(0xFF7A164B), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.red.shade300),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              BorderSide(color: Colors.red.shade400, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 18),
      ),
      validator: validator,
    );
  }

  // Primary action button
  Widget _buildPrimaryButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7A164B),
          foregroundColor: Colors.white,
          elevation: 8,
          shadowColor: const Color(0xFF7A164B).withOpacity(0.5),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(icon, size: 20),
                ],
              ),
      ),
    );
  }
}