import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:url_launcher/url_launcher.dart';

class DeactivatedScreen extends StatefulWidget {
  const DeactivatedScreen({super.key});

  @override
  State<DeactivatedScreen> createState() => _DeactivatedScreenState();
}

class _DeactivatedScreenState extends State<DeactivatedScreen> {
  bool _refreshing = false;
  String _supportPhone = '';

  // ✅ interstore database
  FirebaseFirestore get db => FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'interstore',
  );

  @override
  void initState() {
    super.initState();
    _loadSupportPhone();
  }

  Future<void> _loadSupportPhone() async {
    try {
      // Try to get support phone from settings or config collection
      final doc = await db.collection('settings').doc('support').get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _supportPhone = data['phone'] ?? '';
        });
      }
    } catch (e) {
      // Fallback to default if settings not found
      setState(() {
        _supportPhone = '+254700000000'; // Default fallback
      });
    }
  }

  Future<void> _refreshStatus() async {
    setState(() => _refreshing = true);
    
    // Add a small delay to show loading indicator
    await Future.delayed(const Duration(seconds: 1));
    
    // Force rebuild by navigating to same route
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DeactivatedScreen()),
      );
    }
  }

  Future<void> _callSupport() async {
    final phoneNumber = _supportPhone.isNotEmpty ? _supportPhone : '+254700000000';
    final uri = Uri.parse('tel:$phoneNumber');
    
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch phone dialer')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.block,
                size: 80,
                color: Colors.red,
              ),
              const SizedBox(height: 20),
              const Text(
                "Account Deactivated",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Your account has been deactivated.\nPlease contact an administrator.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 40),
              
              // Refresh Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _refreshing ? null : _refreshStatus,
                  icon: _refreshing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(_refreshing ? 'Checking...' : 'Refresh Status'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF063052),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Contact Support Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _callSupport,
                  icon: const Icon(Icons.phone),
                  label: Text(_supportPhone.isNotEmpty 
                      ? 'Call Support: $_supportPhone' 
                      : 'Call Support'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF063052),
                    side: const BorderSide(color: Color(0xFF063052)),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              
              // Additional Info
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.blue,
                      size: 20,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Tap refresh to check if your account has been reactivated.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
