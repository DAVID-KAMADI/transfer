// ignore_for_file: deprecated_member_use

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shimmer/shimmer.dart';
import '../transfer_details_page.dart';

class TransfersPage extends StatelessWidget {
  const TransfersPage({super.key});

  static const Color primaryDark = Color(0xFF1E3A5F);
  static const Color primaryMedium = Color(0xFF2E5A8C);
  static const Color accentColor = Color(0xFF4A90D9);
  static const Color successColor = Color(0xFF10B981);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color backgroundColor = Color(0xFFF8FAFC);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: primaryDark,
          foregroundColor: Colors.white,
          centerTitle: true,
          title: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.swap_horiz, size: 24),
              SizedBox(width: 10),
              Text(
                'Transfers',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          bottom: TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: const [
              Tab(icon: Icon(Icons.pending_actions_outlined), text: "Pending"),
              Tab(icon: Icon(Icons.check_circle_outline), text: "Completed"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            TransferList(status: 'pending'),
            TransferList(status: 'completed'),
          ],
        ),
      ),
    );
  }
}

// =========================================================
// USER ROLE & PROFILE MODEL
// =========================================================
class UserProfile {
  final String uid;
  final String email;
  final String? name;
  final String role; // 'admin' or 'driver'
  final String? station;

  UserProfile({
    required this.uid,
    required this.email,
    this.name,
    required this.role,
    this.station,
  });

  bool get isAdmin => role == 'admin';
  bool get isDriver => role == 'driver';
}

class TransferList extends StatelessWidget {
  final String status;

  const TransferList({super.key, required this.status});

  // ✅ FIXED: Use getter to access interstore database
  FirebaseFirestore get _db {
    return FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: 'interstore',
    );
  }

  Color? _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return TransfersPage.successColor;
      case 'pending':
        return TransfersPage.warningColor;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return Icons.check_circle;
      case 'pending':
        return Icons.pending;
      default:
        return Icons.help_outline;
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return "N/A";

    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return "${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
    }

    return "N/A";
  }

  // =========================================================
  // FETCH USER PROFILE WITH ROLE FROM INTERSTORE
  // =========================================================
  Future<UserProfile?> _getUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    try {
      // ✅ FIXED: Query interstore database, not default
      final query = await _db
          .collection('users')
          .where('email', isEqualTo: user.email)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;

      final data = query.docs.first.data();
      return UserProfile(
        uid: user.uid,
        email: user.email ?? '',
        name: data['name'],
        role: data['role'] ?? 'driver',
        station: data['station'],
      );
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
      return null;
    }
  }

  // =========================================================
  // ✨ SHIMMER LOADING SKELETON
  // =========================================================
  Widget _buildShimmerLoading() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey.shade200,
          highlightColor: Colors.grey.shade100,
          child: Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Container(
              height: 140,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 120,
                              height: 16,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: 180,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // =========================================================
  // BUILD TRANSFER STREAM BASED ON ROLE
  // =========================================================
  Widget _buildTransferStream(UserProfile profile) {
    // Admin: see ALL transfers across all dates by status
    if (profile.isAdmin) {
      return StreamBuilder<QuerySnapshot>(
        stream: _getAllTransfersByStatus(status),
        builder: (context, snapshot) {
          return _buildTransferList(context, snapshot, profile);
        },
      );
    }

    // Driver: see ONLY transfers assigned to them across all dates
    return StreamBuilder<QuerySnapshot>(
      stream: _getAllDriverTransfers(profile.email),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _buildTransferList(context, snapshot, profile);
        }

        final filteredDocs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final docStatus = (data['status'] ?? 'pending')
              .toString()
              .toLowerCase();
          return docStatus == status.toLowerCase();
        }).toList();

        return _buildDriverTransferList(context, filteredDocs, profile);
      },
    );
  }

  // =========================================================
  // GET ALL TRANSFERS BY STATUS (ACROSS ALL DATES)
  // =========================================================
  Stream<QuerySnapshot> _getAllTransfersByStatus(String status) {
    // Query current year's transfers directly
    final now = DateTime.now();
    final currentYear = now.year.toString();
    final dayKey =
        "${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    return _db
        .collection('transfers')
        .doc(currentYear)
        .collection(dayKey)
        .where('status', isEqualTo: status)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // =========================================================
  // GET ALL DRIVER TRANSFERS (ACROSS ALL DATES)
  // =========================================================
  Stream<QuerySnapshot> _getAllDriverTransfers(String driverEmail) {
    // Query current year's transfers for this specific driver
    final now = DateTime.now();
    final currentYear = now.year.toString();
    final dayKey =
        "${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    return _db
        .collection('transfers')
        .doc(currentYear)
        .collection(dayKey)
        .where('assignedTo', isEqualTo: driverEmail)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // =========================================================
  // DRIVER-SPECIFIC LIST (filtered by status)
  // =========================================================
  Widget _buildDriverTransferList(
    BuildContext context,
    List<QueryDocumentSnapshot> docs,
    UserProfile profile,
  ) {
    if (docs.isEmpty) {
      return _buildDriverEmptyState(profile, status);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      itemBuilder: (_, i) {
        final doc = docs[i];
        final data = doc.data() as Map<String, dynamic>;
        final itemStatus = data['status'] ?? 'pending';
        final items = (data['items'] as List?) ?? [];
        final assignmentStatus = data['assignmentStatus'];

        final statusColor = _getStatusColor(itemStatus) ?? Colors.grey;

        return _buildTransferCard(
          context: context,
          doc: doc,
          data: data,
          itemStatus: itemStatus,
          items: items,
          statusColor: statusColor,
          assignmentStatus: assignmentStatus,
          profile: profile,
        );
      },
    );
  }

  // =========================================================
  // MAIN TRANSFER LIST BUILDER
  // =========================================================
  Widget _buildTransferList(
    BuildContext context,
    AsyncSnapshot<QuerySnapshot> snapshot,
    UserProfile profile,
  ) {
    if (snapshot.hasError) {
      return _buildErrorState(profile);
    }

    if (!snapshot.hasData) {
      return _buildShimmerLoading();
    }

    final docs = snapshot.data!.docs;

    final filteredDocs = profile.isAdmin
        ? docs
              .toList() // Admins see ALL transfers, no station filtering
        : docs.toList();

    if (filteredDocs.isEmpty) {
      return profile.isAdmin
          ? _buildAdminEmptyState(status)
          : _buildDriverEmptyState(profile, status);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredDocs.length,
      itemBuilder: (_, i) {
        final doc = filteredDocs[i];
        final data = doc.data() as Map<String, dynamic>;
        final itemStatus = data['status'] ?? 'pending';
        final items = (data['items'] as List?) ?? [];
        final assignmentStatus = data['assignmentStatus'];

        final statusColor = _getStatusColor(itemStatus) ?? Colors.grey;

        return _buildTransferCard(
          context: context,
          doc: doc,
          data: data,
          itemStatus: itemStatus,
          items: items,
          statusColor: statusColor,
          assignmentStatus: assignmentStatus,
          profile: profile,
        );
      },
    );
  }

  // =========================================================
  // TRANSFER CARD WIDGET
  // =========================================================
  Widget _buildTransferCard({
    required BuildContext context,
    required DocumentSnapshot doc,
    required Map<String, dynamic> data,
    required String itemStatus,
    required List items,
    required Color statusColor,
    required dynamic assignmentStatus,
    required UserProfile profile,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => TransferDetailsPage(doc: doc)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // HEADER
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _getStatusIcon(itemStatus),
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['transferNo'] ?? '-',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: TransfersPage.primaryDark,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${data['fromStore']} → ${data['toStore']}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        itemStatus.toString().toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // ASSIGNMENT STATUS (for drivers)
                if (profile.isDriver && assignmentStatus != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _getAssignmentColor(
                        assignmentStatus,
                      ).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _getAssignmentColor(
                          assignmentStatus,
                        ).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getAssignmentIcon(assignmentStatus),
                          size: 16,
                          color: _getAssignmentColor(assignmentStatus),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Assignment: ${assignmentStatus.toString().toUpperCase()}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _getAssignmentColor(assignmentStatus),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // STORE ROW
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'From',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            data['fromStore'] ?? '-',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: TransfersPage.primaryDark,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: TransfersPage.accentColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward,
                        size: 16,
                        color: TransfersPage.accentColor,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'To',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            data['toStore'] ?? '-',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: TransfersPage.primaryDark,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),
                const Divider(height: 1),

                // DATE INFO
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.schedule_outlined,
                        size: 14,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Created: ${_formatDate(data['createdAt'])}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11,
                        ),
                      ),
                      if (itemStatus == 'completed' &&
                          data['completedAt'] != null) ...[
                        const SizedBox(width: 12),
                        Icon(
                          Icons.check_circle_outline,
                          size: 14,
                          color: TransfersPage.successColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Completed: ${_formatDate(data['completedAt'])}',
                          style: TextStyle(
                            color: TransfersPage.successColor,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // FOOTER
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 16,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${items.length} items',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      if (profile.isDriver && assignmentStatus == 'pending')
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Action Required',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      const Text(
                        'View',
                        style: TextStyle(
                          color: TransfersPage.accentColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // ASSIGNMENT STATUS HELPERS
  // =========================================================
  Color _getAssignmentColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getAssignmentIcon(String? status) {
    switch (status?.toLowerCase()) {
      case 'accepted':
        return Icons.thumb_up;
      case 'rejected':
        return Icons.thumb_down;
      case 'pending':
        return Icons.hourglass_top;
      default:
        return Icons.help_outline;
    }
  }

  // =========================================================
  // EMPTY STATES
  // =========================================================
  Widget _buildAdminEmptyState(String status) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            status == 'pending' ? Icons.inbox_outlined : Icons.done_all,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            status == 'pending'
                ? 'No pending transfers today'
                : 'No completed transfers today',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Transfers will appear here',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverEmptyState(UserProfile profile, String status) {
    final isPending = status == 'pending';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isPending
                ? Icons.local_shipping_outlined
                : Icons.check_circle_outline,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            isPending
                ? 'No transfers assigned to you'
                : 'No completed deliveries',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isPending
                ? 'Check back when admin assigns you a transfer'
                : 'Great job! All your deliveries are done',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(UserProfile profile) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
          const SizedBox(height: 16),
          const Text(
            'Error loading transfers',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            profile.isDriver
                ? 'Could not load your assigned transfers'
                : 'Could not load transfers',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile?>(
      future: _getUserProfile(),
      builder: (context, profileSnapshot) {
        if (profileSnapshot.connectionState == ConnectionState.waiting) {
          return _buildShimmerLoading();
        }

        final profile = profileSnapshot.data;

        if (profile == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_off_outlined,
                  size: 64,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                const Text(
                  'User profile not found',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        return _buildTransferStream(profile);
      },
    );
  }
}
