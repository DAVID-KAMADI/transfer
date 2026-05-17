import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/transfer.dart';

class ApiService {
  // 🌐 Your local API
  static const String baseUrl = 'http://4.168.192.209:1010/api';

  static Future<List<Transfer>> fetchTransferDetails(String no) async {
    final url = Uri.parse('$baseUrl/Transfer/Details?no=$no');


    try {
      final response = await http.get(url);


      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);

        // Check if response is actually a list
        if (decoded is List) {
          return decoded.map((e) => Transfer.fromJson(e)).toList();
        } else {
          throw Exception('Invalid data format');
        }
      } else {
        throw Exception(
          '❌ Failed to load transfers (Status: ${response.statusCode})',
        );
      }
    } catch (e) {
      throw Exception('Connection or parsing error');
    }
  }

  // 📋 Fetch users by role from 748 Air Services database
  static Future<List<Map<String, dynamic>>> fetchUsersByRole(
    String selectedRole,
  ) async {

    try {
      // Use Firebase to query users by role from 748 Air Services
      final db = FirebaseFirestore.instance;

      final snapshot = await db
          .collection('users')
          .where('Staff_Section', isEqualTo: selectedRole)
          .get();

      final List<Map<String, dynamic>> users = [];

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          users.add({
            'id': doc.id,
            'name': data['name'] ?? '',
            'email': data['email'] ?? '',
            'phone': data['Staff_Telephone'] ?? '',
            'Staff_Section': data['Staff_Section'] ?? '',
            'Staff_Level': data['Staff_Level'] ?? '',
            'Staff_NationalID': data['Staff_NationalID'] ?? '',
            'Staff_Nationality': data['Staff_Nationality'] ?? '',
            'Staff_Number': data['Staff_Number'] ?? '',
            'Staff_OtherNames': data['Staff_OtherNames'] ?? '',
            'Staff_SurName': data['Staff_SurName'] ?? '',
            'Staff_Telephone': data['Staff_Telephone'] ?? '',
            'alt_contact': data['alt_contact'] ?? '',
            'alt_contact_e164': data['alt_contact_e164'] ?? '',
            'appversion': data['appversion'] ?? '',
            'Staff_Designation': data['Staff_Designation'] ?? '',
            // ignore: equal_keys_in_map
            'Staff_Level': data['Staff_Level'] ?? '',
            'createdAt': data['createdAt'],
          });
        }
      }

      return users;
    } catch (e) {
      throw Exception('Failed to query users from 748 Air Services');
    }
  }

  // 💾 Save selected users to interstore database (existing method)
  static Future<void> saveUsersToInterstore(
    List<Map<String, dynamic>> selectedUsers,
  ) async {
    try {
      final db = FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'interstore',
      );


      for (final user in selectedUsers) {
        await db.collection('users').doc(user['email'] ?? '').set({
          'name': user['name'] ?? '',
          'email': user['email'] ?? '',
          'phone': user['phone'] ?? user['Staff_Telephone'] ?? '',
          'role': user['Staff_Section'] ?? 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });

      }

    } catch (e) {
      throw Exception('Failed to save users to interstore');
    }
  }
}
