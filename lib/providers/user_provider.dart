import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProvider with ChangeNotifier {
  User? _user;

  User? get user => _user;
  bool get isLoggedIn => _user != null;

  UserProvider() {
    // Only listen if Firebase is initialized
    if (Firebase.apps.isNotEmpty) {
      FirebaseAuth.instance.authStateChanges().listen((firebaseUser) {
        _user = firebaseUser;
        notifyListeners();
      });
    }
  }

  void logout() {
    if (Firebase.apps.isNotEmpty) {
      FirebaseAuth.instance.signOut();
    }
    _user = null;
    notifyListeners();
  }
}
