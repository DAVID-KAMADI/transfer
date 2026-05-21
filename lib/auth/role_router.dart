import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../driver_home_page.dart';
import '../home.dart';
import 'deactivated_screen.dart';

class RoleRouter extends StatefulWidget {
  const RoleRouter({super.key});

  @override
  State<RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<RoleRouter> {
  String? _cachedRole;
  String? _cachedStatus;
  bool _isLoaded = false;

  // ✅ interstore database
  FirebaseFirestore get db => FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'interstore',
  );

  static const String _roleKey = 'user_role';
  static const String _statusKey = 'user_status';
  static const String _emailKey = 'user_email';

  @override
  void initState() {
    super.initState();
    _loadCachedRole();
  }

  Future<void> _loadCachedRole() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;

    if (user != null && user.email != null) {
      final cachedEmail = prefs.getString(_emailKey);

      // Only use cached role if it's for the same user
      if (cachedEmail == user.email) {
        setState(() {
          _cachedRole = prefs.getString(_roleKey);
          _cachedStatus = prefs.getString(_statusKey) ?? 'active';
          _isLoaded = true;
        });
      } else {
        setState(() {
          _isLoaded = true;
        });
      }
    } else {
      setState(() {
        _isLoaded = true;
      });
    }
  }

  Future<void> _cacheRole(String role, String status, String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey, role);
    await prefs.setString(_statusKey, status);
    await prefs.setString(_emailKey, email);
  }

  Widget _buildPageForRole(String role, String status) {
    // Deactivated user
    if (status == 'deactivated') {
      return const DeactivatedScreen();
    }

    // Pending approval
    if (role == 'pending') {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text("Account pending approval..."),
            ],
          ),
        ),
      );
    }

    // 🚚 Driver
    if (role == 'driver') {
      return const DriverHomePage();
    }

    // 👤 Default (admin / user)
    return const Home();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // ❌ Not logged in
    if (user == null) {
      return const Scaffold(body: Center(child: Text("Not logged in")));
    }

    // ✅ SAFETY: ensure email exists
    final email = user.email;
    if (email == null) {
      return const Scaffold(body: Center(child: Text("User email not found")));
    }

    // Show cached role immediately while loading fresh data
    if (_isLoaded && _cachedRole != null) {
      // Return a widget that shows the cached page and listens for updates
      return StreamBuilder<DocumentSnapshot>(
        stream: db.collection('users').doc(email).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            final role = (data['role'] ?? 'pending').toString().toLowerCase();
            final status = (data['status'] ?? 'active')
                .toString()
                .toLowerCase();

            // Update cache if role changed
            if (role != _cachedRole || status != _cachedStatus) {
              _cacheRole(role, status, email);
              setState(() {
                _cachedRole = role;
                _cachedStatus = status;
              });
            }

            return _buildPageForRole(role, status);
          }

          // Show cached page while waiting for fresh data
          return _buildPageForRole(_cachedRole!, _cachedStatus ?? 'active');
        },
      );
    }

    // 🔥 REAL-TIME LISTENER (interstore) - initial load
    return StreamBuilder<DocumentSnapshot>(
      stream: db.collection('users').doc(email).snapshots(),
      builder: (context, snapshot) {
        // 🔄 Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // ❌ No document
        if (!snapshot.hasData ||
            !snapshot.data!.exists ||
            snapshot.data!.data() == null) {
          return const Scaffold(
            body: Center(child: Text("User not found in database")),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final role = (data['role'] ?? 'pending').toString().toLowerCase();
        final status = (data['status'] ?? 'active').toString().toLowerCase();

        // Cache the role for persistence
        _cacheRole(role, status, email);

        return _buildPageForRole(role, status);
      },
    );
  }
}
