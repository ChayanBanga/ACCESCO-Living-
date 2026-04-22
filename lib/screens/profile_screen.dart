import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/user_provider.dart';
import 'login_screen.dart';
import 'cart_screen.dart';
import 'payment_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.user;

    // Get display info safely — works for both phone & email auth
    final String phoneNumber = user?.phoneNumber ?? '';
    final String email = user?.email ?? '';

    // Avatar letter: use first letter of phone or email, fallback to 'U'
    String avatarLetter = 'U';
    if (phoneNumber.isNotEmpty) {
      // Use last 2 digits of phone as avatar hint, or just a phone icon
      avatarLetter = '📱';
    } else if (email.isNotEmpty) {
      avatarLetter = email.substring(0, 1).toUpperCase();
    }

    // Display name under avatar
    final String displayName = phoneNumber.isNotEmpty
        ? phoneNumber
        : email.isNotEmpty
            ? email
            : 'User';

    final String displayLabel = phoneNumber.isNotEmpty
        ? 'Phone Account'
        : 'Account Email';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFC107),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text(
                        'Profile',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.person,
                          color: Colors.black.withOpacity(0.7), size: 28),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.star,
                          size: 14, color: Colors.black.withOpacity(0.7)),
                      const SizedBox(width: 4),
                      Text(
                        'Manage your account',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black.withOpacity(0.7)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 24),

                    // Avatar
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFC107).withOpacity(0.2),
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: const Color(0xFFFFC107), width: 3),
                      ),
                      child: Center(
                        child: phoneNumber.isNotEmpty
                            ? const Icon(Icons.phone_android,
                                size: 44, color: Color(0xFFFFC107))
                            : Text(
                                avatarLetter,
                                style: const TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFFFC107),
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Display name from Firestore
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc(user?.uid)
                          .get(),
                      builder: (context, snapshot) {
                        // Default values
                        String nameToShow = 'User';
                        String subtitleToShow = phoneNumber.isNotEmpty
                            ? phoneNumber
                            : email;

                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Column(
                            children: [
                              Container(
                                width: 120,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: 160,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ],
                          );
                        }

                        if (snapshot.hasData && snapshot.data!.exists) {
                          final data = snapshot.data!.data()
                              as Map<String, dynamic>?;
                          if (data != null) {
                            // Name — show if exists
                            final firestoreName =
                                data['name']?.toString().trim() ?? '';
                            if (firestoreName.isNotEmpty) {
                              nameToShow = firestoreName;
                            }
                            // Subtitle — show phone from Firestore
                            final firestorePhone =
                                data['phone']?.toString().trim() ?? '';
                            if (firestorePhone.isNotEmpty) {
                              subtitleToShow = firestorePhone;
                            }
                          }
                        }

                        return Column(
                          children: [
                            Text(
                              nameToShow,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitleToShow,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 32),

                    // Menu Items
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          _MenuItem(
                            icon: Icons.shopping_bag_outlined,
                            title: 'My Orders',
                            subtitle: 'View order history',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const CartScreen()),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          _MenuItem(
                            icon: Icons.location_on_outlined,
                            title: 'Saved Addresses',
                            subtitle: 'Manage delivery addresses',
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Address feature coming soon'),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          _MenuItem(
                            icon: Icons.payment,
                            title: 'Payment Methods',
                            subtitle: 'Cards, UPI, Wallets',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const PaymentScreen(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          _MenuItem(
                            icon: Icons.notifications_outlined,
                            title: 'Notifications',
                            subtitle: 'Manage preferences',
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Notification settings coming soon'),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          _MenuItem(
                            icon: Icons.help_outline,
                            title: 'Help & Support',
                            subtitle: 'FAQs and contact us',
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Help & Support coming soon'),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          _MenuItem(
                            icon: Icons.info_outline,
                            title: 'About',
                            subtitle: 'Version 2.0.0',
                            onTap: () {
                              showAboutDialog(
                                context: context,
                                applicationName: 'Your App',
                                applicationVersion: '2.0.0',
                              );
                            },
                          ),
                          const SizedBox(height: 24),

                          // Logout Button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(16)),
                                    title: const Text('Logout',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w800)),
                                    content: const Text(
                                        'Are you sure you want to logout?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          userProvider.logout();
                                          Navigator.pushAndRemoveUntil(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) =>
                                                    const LoginScreen()),
                                            (route) => false,
                                          );
                                        },
                                        child: const Text('Logout',
                                            style: TextStyle(
                                                color: Colors.red)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.red,
                                elevation: 0,
                                side: const BorderSide(
                                    color: Colors.red, width: 1.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text(
                                'LOGOUT',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFFFC107).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFFFFC107), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}