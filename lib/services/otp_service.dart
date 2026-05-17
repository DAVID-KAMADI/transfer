import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class OtpService {
  // ✅ FIXED: Use interstore database
  static FirebaseFirestore get _db {
    return FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: 'interstore',
    );
  }

  // ================================
  // GENERATE OTP
  // ================================
  static String _generateOtp() {
    final random = Random();
    return List.generate(6, (_) => random.nextInt(10)).join();
  }

  // ================================
  // SEND OTP
  // ================================
  static Future<String> sendOtp({
    required String year,
    required String dayKey,
    required String transferNo,
    required String email,
    required List<int> selectedIndexes,
    required Future<void> Function(
      String recipient,
      String subject,
      String body,
    ) sendEmail,
  }) async {
    final otp = _generateOtp();

    final docRef = _db
        .collection('transfers')
        .doc(year)
        .collection(dayKey)
        .doc(transferNo);

    final now = DateTime.now();
    final expiresAt = now.add(const Duration(minutes: 5));

    await docRef.set({
      'otpData': {
        'code': otp,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'verified': false,
        'used': false,
        'sentTo': email,
      },
      'pendingSelectedItems': selectedIndexes,
    }, SetOptions(merge: true));

    // ================= EMAIL =================
    await sendEmail(
      email,
      "Transfer OTP Code",
      "Your OTP is: $otp\n\nThis code will expire in 5 minutes.",
    );

    return otp;
  }

  // ================================
  // VERIFY OTP
  // ================================
  static Future<void> verifyOtp({
    required String year,
    required String dayKey,
    required String transferNo,
    required String otp,
  }) async {
    final docRef = _db
        .collection('transfers')
        .doc(year)
        .collection(dayKey)
        .doc(transferNo);

    final doc = await docRef.get();

    if (!doc.exists) throw Exception("Transfer not found");

    final data = doc.data()!;
    final otpData = data['otpData'];

    if (otpData == null) throw Exception("OTP not generated");

    final storedOtp = otpData['code'];
    final used = otpData['used'] ?? false;

    final Timestamp? expiresTimestamp = otpData['expiresAt'];
    final expiresAt = expiresTimestamp?.toDate();

    if (used) throw Exception("OTP already used");

    if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
      throw Exception("OTP expired");
    }

    if (otp != storedOtp) {
      throw Exception("Invalid OTP");
    }

    await docRef.update({
      'otpData.verified': true,
      'otpData.used': true,
      'otpData.verifiedAt': FieldValue.serverTimestamp(),
    });
  }
}