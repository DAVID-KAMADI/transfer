// ignore_for_file: deprecated_member_use, use_build_context_synchronously, file_names

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shimmer/shimmer.dart';

class AdminTransferDetailsPage extends StatefulWidget {
  final DocumentSnapshot doc;

  const AdminTransferDetailsPage({super.key, required this.doc});

  @override
  State<AdminTransferDetailsPage> createState() =>
      _AdminTransferDetailsPageState();
}

class _AdminTransferDetailsPageState extends State<AdminTransferDetailsPage> {
  final picker = ImagePicker();

  // Track uploading state per part code instead of global
  final Set<String> _uploadingParts = {};

  // ✅ Use interstore database
  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'interstore',
  );

  // Store receiver user name
  String? _receiverUserName;

  static const Color primaryDark = Color(0xFF1E3A5F);
  static const Color primaryMedium = Color(0xFF2E5A8C);
  static const Color accentColor = Color(0xFF4A90D9);

  @override
  void initState() {
    super.initState();
    _fetchReceiverUserName();
  }

  Future<void> _fetchReceiverUserName() async {
    final data = widget.doc.data() as Map<String, dynamic>?;
    final receiverEmail =
        data?['receiverEmail']?.toString() ??
        data?['receivedBy']?.toString() ??
        '';

    if (receiverEmail.isNotEmpty) {
      try {
        final userSnapshot = await _db
            .collection('users')
            .where('email', isEqualTo: receiverEmail)
            .limit(1)
            .get();

        if (userSnapshot.docs.isNotEmpty) {
          final userData = userSnapshot.docs.first.data();
          final name =
              userData['name']?.toString() ??
              userData['displayName']?.toString() ??
              '';
          if (name.isNotEmpty && mounted) {
            setState(() {
              _receiverUserName = name;
            });
          }
        }
      } catch (e) {
        debugPrint('Error fetching user for email $receiverEmail: $e');
      }
    }
  }

  // =========================================================
  // 📸 IMAGE UPLOAD — INDIVIDUAL FOR EACH ITEM
  // =========================================================
  Future<void> _addImage(String partCode, int itemIndex) async {
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );

    if (picked == null) return;

    setState(() => _uploadingParts.add('$partCode-$itemIndex'));

    try {
      final file = File(picked.path);

      // Use unique identifier: partCode + itemIndex + timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = FirebaseStorage.instance.ref().child(
        "transfer_images/${widget.doc.id}/${partCode}_${itemIndex}_$timestamp.jpg",
      );

      await ref.putFile(file);

      final url = await ref.getDownloadURL();

      final data = widget.doc.data() as Map<String, dynamic>? ?? {};
      final items = List<Map<String, dynamic>>.from(data['items'] ?? []);

      if (itemIndex < items.length) {
        items[itemIndex]['imageUrl'] = url;
        items[itemIndex]['imageTakenAt'] = Timestamp.now();
      }

      await _db
          .collection('transfers')
          .doc(data['year']?.toString() ?? DateTime.now().year.toString())
          .collection(data['dayKey']?.toString() ?? _dayKey(DateTime.now()))
          .doc(widget.doc.id)
          .update({'items': items});

      await widget.doc.reference.update({'items': items});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text("Image uploaded successfully"),
              ],
            ),
            backgroundColor: primaryDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Upload failed: $e"),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _uploadingParts.remove('$partCode-$itemIndex'));
      }
    }
  }

  // =========================================================
  // 🖼️ PREVIEW IMAGE DIALOG
  // =========================================================
  void _previewImage(String imageUrl, String partCode) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 300,
                    color: Colors.grey.shade900,
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                            : null,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "Part: $partCode",
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Close",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // ✨ SHIMMER IMAGE PLACEHOLDER
  // =========================================================
  Widget _buildImageShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade100,
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  // =========================================================
  // 🕒 FORMAT DATE
  // =========================================================
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return "-";

    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return "${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
    }

    return "-";
  }

  String _dayKey(DateTime date) {
    return "${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.doc.data() as Map<String, dynamic>? ?? {};
    final items = List<Map<String, dynamic>>.from(data['items'] ?? []);
    final status = (data['status'] ?? 'pending').toString();
    final isCompleted = status.toLowerCase() == 'completed';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryDark,
        foregroundColor: Colors.white,
        title: const Text(
          "Transfer Details",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          // =========================================================
          // HEADER
          // =========================================================
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryDark, primaryMedium],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.store, color: Colors.white70, size: 20),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        "${data['fromStore'] ?? '-'}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(
                        Icons.arrow_forward,
                        color: Colors.white70,
                        size: 20,
                      ),
                    ),
                    const Icon(Icons.store, color: Colors.white70, size: 20),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        "${data['toStore'] ?? '-'}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? Colors.green.withOpacity(0.2)
                        : Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isCompleted
                          ? Colors.green.shade700
                          : Colors.orange.shade700,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // =========================================================
          // COMPLETED INFO
          // =========================================================
          if (isCompleted) _buildCompletedInfo(data),

          // =========================================================
          // ITEMS
          // =========================================================
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final item = items[index];
                final partCode = item['code']?.toString() ?? 'Unknown';
                final hasImage = item['imageUrl'] != null;
                final isUploading = _uploadingParts.contains(
                  '$partCode-$index',
                );

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Part Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: primaryDark.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "Part ${index + 1}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: primaryDark,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (hasImage)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      size: 14,
                                      color: Colors.green.shade700,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "Photo OK",
                                      style: TextStyle(
                                        color: Colors.green.shade700,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Part Details
                        _detailRow("Code", partCode),
                        _detailRow("Description", item['descr'] ?? '-'),
                        _detailRow("Quantity", "${item['qty'] ?? 0}"),
                        if (item['batchNo'] != null)
                          _detailRow("Batch No", item['batchNo']),
                        if (item['serialNo'] != null)
                          _detailRow("Serial No", item['serialNo']),

                        const SizedBox(height: 16),

                        // Image Section
                        if (isUploading) ...[
                          // ✨ Uploading animation
                          _buildImageShimmer(),
                          const SizedBox(height: 12),
                          Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      accentColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Uploading photo...",
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else if (hasImage) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: GestureDetector(
                              onTap: () =>
                                  _previewImage(item['imageUrl'], partCode),
                              child: Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  Image.network(
                                    item['imageUrl'],
                                    height: 180,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, progress) {
                                      if (progress == null) return child;
                                      return _buildImageShimmer();
                                    },
                                    errorBuilder: (context, error, stack) {
                                      return Container(
                                        height: 180,
                                        color: Colors.grey.shade100,
                                        child: const Center(
                                          child: Icon(
                                            Icons.broken_image,
                                            color: Colors.grey,
                                            size: 48,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  Container(
                                    margin: const EdgeInsets.all(8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.zoom_in,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          "Tap to preview",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ] else ...[
                          // No image — prompt user
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.orange.withOpacity(0.2),
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.camera_alt_outlined,
                                  size: 40,
                                  color: Colors.orange.shade400,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "No photo taken for this part",
                                  style: TextStyle(
                                    color: Colors.orange.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (!isCompleted)
                                  ElevatedButton.icon(
                                    onPressed: () => _addImage(partCode, index),
                                    icon: const Icon(Icons.camera_alt),
                                    label: const Text("Take Photo"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryDark,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  )
                                else
                                  const Text(
                                    "Cannot add photo — transfer completed",
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: primaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedInfo(Map<String, dynamic> data) {
    final otpData = data['otpData'] as Map<String, dynamic>? ?? {};

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified, color: Colors.green),
              SizedBox(width: 8),
              Text(
                "Transfer Completed",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _infoRow(
            "Received By",
            _receiverUserName ??
                data['receiverEmail'] ??
                data['receivedBy'] ??
                '-',
          ),
          _infoRow("Receiver Email", data['receiverEmail'] ?? '-'),
          _infoRow("Received At", _formatTimestamp(data['receivedAt'])),
          const Divider(height: 20),
          const Text(
            "OTP Verification",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          _infoRow("OTP Code", otpData['code']),
          _infoRow("Created", _formatTimestamp(otpData['createdAt'])),
          _infoRow("Verified", _formatTimestamp(otpData['verifiedAt'])),
        ],
      ),
    );
  }

  Widget _infoRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value?.toString() ?? "-",
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
