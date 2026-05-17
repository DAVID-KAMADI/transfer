import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class TransferCompletionService {
  // ✅ Use interstore database
  static FirebaseFirestore get _db {
    return FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: 'interstore',
    );
  }

  static Future<void> completeTransfer({
    required String year,
    required String dayKey,
    required String transferNo,
    required List<int> selectedIndexes,
    required String signatureBase64,
    required String receivedBy,
    required String receiverName,
    required String receiverEmail,
    required String otp,
    required dynamic otpCreatedAt,
    required dynamic otpVerifiedAt,
  }) async {
    if (year.isEmpty || dayKey.isEmpty || transferNo.isEmpty) {
      throw Exception(
        "Missing transfer path data: year=$year, dayKey=$dayKey, transferNo=$transferNo",
      );
    }

    // ✅ SAME PATH (only change if your structure is different)
    final docRef = _db
        .collection('transfers')
        .doc(year)
        .collection(dayKey)
        .doc(transferNo);

    await docRef.update({
      // ✅ STATUS
      'status': 'completed',
      'receivedAt': FieldValue.serverTimestamp(),
      'completedAt': FieldValue.serverTimestamp(),

      // ✅ ITEMS
      'selectedItems': selectedIndexes,

      // ✅ SIGNATURE (MAIN FIX)
      'signature': signatureBase64,

      // ✅ RECEIVER INFO (clean + consistent)
      'receivedBy': receivedBy,
      'receiverName': receiverName,
      'receiverEmail': receiverEmail,

      // ✅ OTP (merge instead of overwrite structure blindly)
      'otpData.code': otp,
      'otpData.createdAt': otpCreatedAt,
      'otpData.verifiedAt': otpVerifiedAt,
    });
  }
}
