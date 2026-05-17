import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../driver_home_page.dart';
import '../home.dart';
import 'deactivated_screen.dart';

class RoleRouter extends StatelessWidget {
  const RoleRouter({super.key});

  // ✅ interstore database
  FirebaseFirestore get db => FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'interstore',
  );

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

    // 🔥 REAL-TIME LISTENER (interstore)
    return StreamBuilder<DocumentSnapshot>(
      // ✅ CHANGE: use UID OR email depending on your DB design
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
      },
    );
  }
}
