import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/transfer.dart';

class FirebaseService {
  // ✅ Use the custom 'interstore' database instead of default
  static final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'interstore',
  );

  // 🔥 Format date as 04-23
  static String _dayKey(DateTime date) {
    return "${date.month.toString().padLeft(2, '0')}-"
        "${date.day.toString().padLeft(2, '0')}";
  }

  // =========================================================
  // ✅ SAVE TRANSFER (WITH DUPLICATE + ASSIGNMENT SUPPORT)
  // =========================================================
  static Future<void> saveTransfer(
    String transferNo,
    List<Transfer> items, {
    String? assignedTo,
    String? assignedToName,
  }) async {
    final now = DateTime.now();

    final year = now.year.toString();
    final dayKey = _dayKey(now);

    final transferRef = _db
        .collection('transfers')
        .doc(year)
        .collection(dayKey)
        .doc(transferNo);

    // 🔥 GLOBAL INDEX (prevents duplicates across ALL dates)
    final indexRef = _db.collection('transfer_index').doc(transferNo);

    await _db.runTransaction((transaction) async {
      final indexSnapshot = await transaction.get(indexRef);

      // ❌ If transfer already exists anywhere → block
      if (indexSnapshot.exists) {
        throw Exception("Transfer number already exists");
      }

      // ✅ Reserve transfer number globally
      transaction.set(indexRef, {
        'transferNo': transferNo,
        'createdAt': Timestamp.fromDate(now),
        'year': year,
        'dayKey': dayKey,
      });

      // ✅ Save actual transfer
      transaction.set(transferRef, {
        'transferNo': transferNo,
        'fromStore': items.first.from,
        'toStore': items.first.to,
        'status': 'pending',
        'createdAt': Timestamp.fromDate(now),

        // 🔥 indexing fields
        'year': year,
        'dayKey': dayKey,

        // 👇 ASSIGNMENT (NEW)
        'assignedTo': assignedTo,
        'assignedToName': assignedToName,
        'assignedAt': assignedTo != null ? Timestamp.fromDate(now) : null,

        // 👇 DRIVER MUST ACCEPT
        'assignmentStatus': assignedTo != null ? 'pending' : null,

        'items': items.map((e) {
          return {
            'code': e.code,
            'descr': e.descr,
            'qty': e.qty,
            'batchNo': e.batchNo,
            'serialNo': e.serialNo,
          };
        }).toList(),
      });
    });
  }

  // =========================================================
  // ✅ GET TRANSFERS BY DATE
  // =========================================================
  static Stream<QuerySnapshot> getTransfersByDate(
    String year,
    String dayKey,
    String status,
  ) {
    return _db
        .collection('transfers')
        .doc(year)
        .collection(dayKey)
        .where('status', isEqualTo: status)
        .snapshots();
  }

  // =========================================================
  // ✅ GET TRANSFERS FOR DRIVER
  // =========================================================
  static Stream<QuerySnapshot> getDriverTransfers(
    String year,
    String dayKey,
    String driverUid,
  ) {
    return _db
        .collection('transfers')
        .doc(year)
        .collection(dayKey)
        .where('assignedTo', isEqualTo: driverUid)
        .snapshots();
  }

  // =========================================================
  // ✅ ASSIGN DRIVER (ADMIN ACTION)
  // =========================================================
  static Future<void> assignDriver(
    String year,
    String dayKey,
    String transferNo,
    String driverUid,
    String driverName,
  ) async {
    final ref = _db
        .collection('transfers')
        .doc(year)
        .collection(dayKey)
        .doc(transferNo);

    await ref.update({
      'assignedTo': driverUid,
      'assignedToName': driverName,
      'assignedAt': Timestamp.now(),

      // 👇 MUST ACCEPT
      'assignmentStatus': 'pending',

      // reset previous decisions if reassigned
      'acceptedAt': null,
      'rejectedAt': null,
    });
  }

  // =========================================================
  // ✅ DRIVER ACCEPTS TRANSFER
  // =========================================================
  static Future<void> acceptTransfer(
    String year,
    String dayKey,
    String transferNo,
  ) async {
    final ref = _db
        .collection('transfers')
        .doc(year)
        .collection(dayKey)
        .doc(transferNo);

    await ref.update({
      'assignmentStatus': 'accepted',
      'acceptedAt': Timestamp.now(),
    });
  }

  // =========================================================
  // ❌ DRIVER REJECTS TRANSFER
  // =========================================================
  static Future<void> rejectTransfer(
    String year,
    String dayKey,
    String transferNo,
  ) async {
    final ref = _db
        .collection('transfers')
        .doc(year)
        .collection(dayKey)
        .doc(transferNo);

    await ref.update({
      'assignmentStatus': 'rejected',
      'rejectedAt': Timestamp.now(),
    });
  }

  // =========================================================
  // ✅ MARK AS COMPLETED
  // =========================================================
  static Future<void> markCompleted(
    String year,
    String dayKey,
    String transferNo,
  ) async {
    final ref = _db
        .collection('transfers')
        .doc(year)
        .collection(dayKey)
        .doc(transferNo);

    await ref.update({'status': 'completed'});
  }

  // =========================================================
  // ✅ SAVE RECEIVER EMAIL TO TRANSFER
  // =========================================================
  static Future<void> saveReceiverEmail(
    String year,
    String dayKey,
    String transferNo,
    String email,
  ) async {
    final ref = _db
        .collection('transfers')
        .doc(year)
        .collection(dayKey)
        .doc(transferNo);

    await ref.update({'receiverEmail': email});
  }
}