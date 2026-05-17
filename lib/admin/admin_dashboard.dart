import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'users_page.dart';
import '../auth/login_page.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // 🔒 Not logged in
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Not logged in')),
      );
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(),
      builder: (context, snapshot) {
        // ⏳ Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // ❌ Error
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('Error loading user data')),
          );
        }

        // ❌ No data
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(
            body: Center(child: Text('User not found')),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final role = data['role'];

        // 🔒 BLOCK non-admin users
        if (role != 'admin') {
          return const Scaffold(
            body: Center(
              child: Text(
                'Access Denied\nAdmin Only',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
            ),
          );
        }

        // ✅ Admin UI
        return _buildAdminUI(context, data);
      },
    );
  }

  Widget _buildAdminUI(BuildContext context, Map<String, dynamic> data) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        centerTitle: true,
      ),

      drawer: Drawer(
        child: Column(
          children: [
            // 👤 Real User Data
            UserAccountsDrawerHeader(
              accountName: Text(data['name'] ?? '-'),
              accountEmail: Text(data['email'] ?? '-'),
              currentAccountPicture: const CircleAvatar(
                child: Icon(Icons.admin_panel_settings),
              ),
              otherAccountsPictures: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    data['station'] ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            // 👥 Users Page
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Users'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const UsersPage(),
                  ),
                );
              },
            ),

            // 📊 Reports
            ListTile(
              leading: const Icon(Icons.analytics),
              title: const Text('Reports'),
              onTap: () {},
            ),

            // 🔄 Transfers
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('Transfers'),
              onTap: () {},
            ),

            const Divider(),

            // 🔴 Logout
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Logout',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () async {
                await FirebaseAuth.instance.signOut();

                Navigator.pushAndRemoveUntil(
                  // ignore: use_build_context_synchronously
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LoginPage(),
                  ),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),

      body: const Center(
        child: Text(
          'Welcome Admin',
          style: TextStyle(fontSize: 22),
        ),
      ),
    );
  }
}