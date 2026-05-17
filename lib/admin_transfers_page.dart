// ignore_for_file: deprecated_member_use

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';
import '../transfer_details_page.dart';

class AdminTransfersPage extends StatelessWidget {
  const AdminTransfersPage({super.key});

  static const Color primaryDark = Color(0xFF1E3A5F);
  static const Color primaryMedium = Color(0xFF2E5A8C);
  static const Color accentColor = Color(0xFF4A90D9);
  static const Color successColor = Color(0xFF10B981);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color backgroundColor = Color(0xFFF8FAFC);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
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
                'Admin Transfers',
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
              Tab(icon: Icon(Icons.person_outline), text: "Unassigned"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            AdminTransferList(status: 'pending'),
            AdminTransferList(status: 'completed'),
            AdminTransferList(status: 'unassigned'),
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

class AdminTransferList extends StatefulWidget {
  final String status;

  const AdminTransferList({super.key, required this.status});

  @override
  State<AdminTransferList> createState() => _AdminTransferListState();
}

class _AdminTransferListState extends State<AdminTransferList> {
  DateTimeRange? _selectedDateRange;

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
        return AdminTransfersPage.successColor;
      case 'pending':
        return AdminTransfersPage.warningColor;
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

      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data();
        return UserProfile(
          uid: user.uid,
          email: user.email!,
          name: data['name'],
          role: data['role'] ?? 'user',
          station: data['station'],
        );
      }
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
    }
    return null;
  }

  // =========================================================
  // SHIMMER LOADING EFFECT
  // =========================================================
  Widget _buildShimmerLoading() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (_, __) {
        return Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
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
        );
      },
    );
  }

  // =========================================================
  // BUILD TRANSFER STREAM - SHOW ALL TRANSFERS
  // =========================================================
  Widget _buildTransferStream(UserProfile profile) {
    // Admin: see ALL transfers across all dates by status
    return StreamBuilder<List<DocumentSnapshot>>(
      stream: _getAllTransfersByStatus(widget.status, _selectedDateRange),
      builder: (context, snapshot) {
        return _buildTransferList(context, snapshot, profile);
      },
    );
  }

  // =========================================================
  // SELECT DATE RANGE
  // =========================================================
  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AdminTransfersPage.primaryDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  // =========================================================
  // GET ALL TRANSFERS BY STATUS (ADMIN ONLY)
  // =========================================================
  Stream<List<DocumentSnapshot>> _getAllTransfersByStatus(
    String status,
    DateTimeRange? dateRange,
  ) async* {
    final now = DateTime.now();
    final currentYear = now.year.toString();

    // Generate day keys based on date range or default to last 30 days
    final List<String> dayKeys = [];

    if (dateRange != null) {
      // Generate day keys for selected date range
      var current = DateTime(
        dateRange.start.year,
        dateRange.start.month,
        dateRange.start.day,
      );
      final end = DateTime(
        dateRange.end.year,
        dateRange.end.month,
        dateRange.end.day,
      );

      while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
        dayKeys.add(DateFormat('MM-dd').format(current));
        current = current.add(const Duration(days: 1));
      }
    } else {
      // Default to last 30 days
      for (int i = 0; i < 30; i++) {
        final date = now.subtract(Duration(days: i));
        dayKeys.add(DateFormat('MM-dd').format(date));
      }
    }

    debugPrint('Querying $status transfers for day keys: $dayKeys');

    final List<DocumentSnapshot> allTransfers = [];

    for (final dayKey in dayKeys) {
      try {
        final snapshot = await _db
            .collection('transfers')
            .doc(currentYear)
            .collection(dayKey)
            .get();

        allTransfers.addAll(snapshot.docs);
      } catch (e) {
        debugPrint('Error querying $dayKey: $e');
        // Continue with next day if one doesn't exist
      }
    }

    // Filter by status in memory
    allTransfers.removeWhere((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final docStatus = data['status']?.toString() ?? '';

      if (status == 'unassigned') {
        // For unassigned, check if assignedTo is null
        final assignedTo = data['assignedTo'];
        return assignedTo != null;
      } else {
        // For other statuses, filter by status field
        return docStatus != status;
      }
    });

    // Sort all transfers by creation date
    allTransfers.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;
      final aTime = aData['createdAt'] as Timestamp?;
      final bTime = bData['createdAt'] as Timestamp?;

      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;

      return bTime.compareTo(aTime);
    });

    yield allTransfers;
  }

  // =========================================================
  // MAIN TRANSFER LIST BUILDER - SHOW ALL TRANSFERS
  // =========================================================
  Widget _buildTransferList(
    BuildContext context,
    AsyncSnapshot<List<DocumentSnapshot>> snapshot,
    UserProfile profile,
  ) {
    if (snapshot.hasError) {
      return _buildErrorState(profile);
    }

    if (!snapshot.hasData) {
      return _buildShimmerLoading();
    }

    final docs = snapshot.data!;

    if (docs.isEmpty) {
      return _buildAdminEmptyState(widget.status);
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
  // BUILD TRANSFER CARD
  // =========================================================
  Widget _buildTransferCard({
    required BuildContext context,
    required DocumentSnapshot doc,
    required Map<String, dynamic> data,
    required String itemStatus,
    required List<dynamic> items,
    required Color statusColor,
    required String? assignmentStatus,
    required UserProfile profile,
  }) {
    final transferNo = data['transferNo'] ?? 'Unknown';
    final fromStore = data['fromStore'] ?? 'Unknown';
    final toStore = data['toStore'] ?? 'Unknown';
    final createdAt = data['createdAt'];
    final completedAt = data['completedAt'];
    final createdBy = data['createdBy'] ?? 'Unknown';
    final assignedTo = data['assignedTo'];

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withOpacity(0.3), width: 1),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => TransferDetailsPage(doc: doc)),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getStatusIcon(itemStatus),
                          size: 16,
                          color: statusColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          itemStatus.toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    transferNo,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AdminTransfersPage.primaryDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Store Information
              Row(
                children: [
                  Icon(Icons.store, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '$fromStore → $toStore',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Items Count
              Row(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${items.length} items',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Date Information
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Created: ${_formatDate(createdAt)}',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (completedAt != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const SizedBox(width: 20), // Align with icon
                        Icon(
                          Icons.check_circle,
                          size: 16,
                          color: Colors.green.shade600,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Completed: ${_formatDate(completedAt)}',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),

              // Assignment Info (Admin view)
              if (profile.isAdmin) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Created by: $createdBy',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                      ),
                    ),
                    if (assignedTo != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '•',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Assigned to: $assignedTo',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
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
            status == 'pending'
                ? Icons.pending_actions_outlined
                : Icons.check_circle_outline,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No $status transfers',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'All transfers will appear here',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
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
          Text(
            'Error loading transfers',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.red.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please try again later',
            style: TextStyle(fontSize: 14, color: Colors.red.shade500),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // MAIN BUILD METHOD
  // =========================================================
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

        return Column(
          children: [
            // Date Filter Section
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Row(
                children: [
                  Icon(
                    Icons.filter_list,
                    color: AdminTransfersPage.primaryDark,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Date Filter:',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: AdminTransfersPage.primaryDark,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDateRange(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _selectedDateRange == null
                                    ? 'All (Last 30 days)'
                                    : '${DateFormat('MMM dd').format(_selectedDateRange!.start)} - ${DateFormat('MMM dd').format(_selectedDateRange!.end)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ),
                            if (_selectedDateRange != null)
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedDateRange = null;
                                  });
                                },
                                child: Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Transfer List
            Expanded(child: _buildTransferStream(profile)),
          ],
        );
      },
    );
  }
}
