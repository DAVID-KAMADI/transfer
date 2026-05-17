// ignore_for_file: avoid_print

import 'package:cloud_functions/cloud_functions.dart';

class EmailService {
  static Future<void> sendAssignmentEmail({
    required String email,
    required String driverName,
    required String transferNo,
    required String fromStore,
    required String toStore, required String toEmail,
  }) async {
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('sendAssignmentEmail');

      await callable.call({
        'toEmail': email,
        'driverName': driverName,
        'transferNo': transferNo,
        'fromStore': fromStore,
        'toStore': toStore,
      });
    } catch (e) {
      print("Email error: $e");
    }
  }
}