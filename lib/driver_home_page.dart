// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shimmer/shimmer.dart';
import '../services/firebase_service.dart';
import '../transfer_details_page.dart';
import '../auth/login_page.dart';

class DriverHomePage extends StatefulWidget {
  const DriverHomePage({super.key});

  @override
  State<DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends State<DriverHomePage> {
  final user = FirebaseAuth.instance.currentUser;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String selectedYear = DateTime.now().year.toString();
  DateTime selectedDate = DateTime.now();

  String statusFilter = "all";

  // ✅ Use interstore database
  FirebaseFirestore get _db {
    return FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: 'interstore',
    );
  }

  // =========================================================
  // DESIGN SYSTEM
  // =========================================================
  static const Color primaryDark = Color(0xFF1E3A5F);
  static const Color primaryMedium = Color(0xFF2E5A8C);
  static const Color accentColor = Color(0xFF4A90D9);
  static const Color successColor = Color(0xFF10B981);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color dangerColor = Color(0xFFEF4444);
  static const Color backgroundColor = Color(0xFFF8FAFC);
  static const Color cardBackground = Colors.white;
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);

  static String _dayKey(DateTime date) {
    return "${date.month.toString().padLeft(2, '0')}-"
        "${date.day.toString().padLeft(2, '0')}";
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: selectedDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryDark,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
        selectedYear = picked.year.toString();
      });
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();

    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 48, color: textSecondary),
              SizedBox(height: 16),
              Text(
                "Not logged in",
                style: TextStyle(
                  fontSize: 18,
                  color: textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final dayKey = _dayKey(selectedDate);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: backgroundColor,
      drawer: _buildDrawer(),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryDark,
        foregroundColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          icon: const Icon(Icons.menu),
          tooltip: "Menu",
        ),
        title: const Text(
          "Driver Dashboard",
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        actions: [
          IconButton(
            onPressed: _pickDate,
            icon: const Icon(Icons.date_range),
            tooltip: "Select Date",
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // ✅ FIXED: Query by email instead of UID since assignedTo stores email
        stream: _db
            .collection('transfers')
            .doc(selectedYear)
            .collection(dayKey)
            .where(
              'assignedTo',
              isEqualTo: user!.email,
            ) // ← Use email, not UID!
            .snapshots(),
        builder: (context, snapshot) {
          final counts = _calculateCounts(snapshot);

          return Column(
            children: [
              // Hero Header
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [primaryDark, primaryMedium],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: primaryDark.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${_dayName(selectedDate.weekday)}, ${_selectedDateFormatted()}",
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              "Transfers for Today",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.local_shipping,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white24, height: 1),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _statBadge(
                          icon: Icons.pending_actions,
                          label: "Pending",
                          count: counts['pending'] ?? 0,
                          color: warningColor,
                        ),
                        _statBadge(
                          icon: Icons.check_circle,
                          label: "Accepted",
                          count: counts['accepted'] ?? 0,
                          color: successColor,
                        ),
                        _statBadge(
                          icon: Icons.done_all,
                          label: "Completed",
                          count: counts['completed'] ?? 0,
                          color: accentColor,
                        ),
                        _statBadge(
                          icon: Icons.cancel,
                          label: "Rejected",
                          count: counts['rejected'] ?? 0,
                          color: dangerColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Filter Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _filterChipWithBadge(
                          value: "all",
                          displayLabel: "All",
                          count: counts['total'] ?? 0,
                        ),
                        _filterChipWithBadge(
                          value: "pending",
                          displayLabel: "Pending",
                          count: counts['pending'] ?? 0,
                        ),
                        _filterChipWithBadge(
                          value: "accepted",
                          displayLabel: "Accepted",
                          count: counts['accepted'] ?? 0,
                        ),
                        _filterChipWithBadge(
                          value: "completed",
                          displayLabel: "Completed",
                          count: counts['completed'] ?? 0,
                        ),
                        _filterChipWithBadge(
                          value: "rejected",
                          displayLabel: "Rejected",
                          count: counts['rejected'] ?? 0,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // List
              Expanded(child: _buildTransferList(snapshot)),
            ],
          );
        },
      ),
    );
  }

  // =========================================================
  // LIVE COUNT CALCULATION
  // =========================================================
  Map<String, int> _calculateCounts(AsyncSnapshot<QuerySnapshot> snapshot) {
    if (!snapshot.hasData || snapshot.data == null) {
      return {
        'total': 0,
        'pending': 0,
        'accepted': 0,
        'completed': 0,
        'rejected': 0,
      };
    }

    final docs = snapshot.data!.docs;
    int total = docs.length;
    int pending = 0;
    int accepted = 0;
    int completed = 0;
    int rejected = 0;

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final effectiveStatus = _getEffectiveStatus(data);

      switch (effectiveStatus) {
        case 'pending':
          pending++;
          break;
        case 'accepted':
          accepted++;
          break;
        case 'completed':
          completed++;
          break;
        case 'rejected':
          rejected++;
          break;
      }
    }

    return {
      'total': total,
      'pending': pending,
      'accepted': accepted,
      'completed': completed,
      'rejected': rejected,
    };
  }

  // =========================================================
  // TRANSFER LIST
  // =========================================================
  Widget _buildTransferList(AsyncSnapshot<QuerySnapshot> snapshot) {
    if (snapshot.hasError) {
      return _buildErrorState();
    }

    if (!snapshot.hasData) {
      return _buildShimmerLoading();
    }

    final docs = snapshot.data!.docs;

    // Filter by effective status
    final filteredDocs = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final effectiveStatus = _getEffectiveStatus(data);

      if (statusFilter == "all") return true;
      return effectiveStatus == statusFilter;
    }).toList();

    if (filteredDocs.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: filteredDocs.length,
      itemBuilder: (context, index) {
        final doc = filteredDocs[index];
        final data = doc.data() as Map<String, dynamic>;

        final effectiveStatus = _getEffectiveStatus(data);
        final transferNo = data['transferNo'] ?? doc.id;
        final fromStore = data['fromStore'] ?? 'Unknown';
        final toStore = data['toStore'] ?? 'Unknown';
        final items = (data['items'] as List?) ?? [];

        return _buildTransferCard(
          doc: doc,
          transferNo: transferNo,
          fromStore: fromStore,
          toStore: toStore,
          effectiveStatus: effectiveStatus,
          itemsCount: items.length,
          year: selectedYear,
          dayKey: _dayKey(selectedDate),
        );
      },
    );
  }

  // =========================================================
  // ✨ SHIMMER LOADING
  // =========================================================
  Widget _buildShimmerLoading() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey.shade200,
          highlightColor: Colors.grey.shade100,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
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
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
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
  // EFFECTIVE STATUS
  // =========================================================
  String _getEffectiveStatus(Map<String, dynamic> data) {
    final transferStatus = (data['status'] ?? 'pending')
        .toString()
        .toLowerCase();
    final assignmentStatus = (data['assignmentStatus'] ?? 'pending')
        .toString()
        .toLowerCase();

    if (transferStatus == 'completed') return 'completed';
    if (transferStatus == 'cancelled') return 'rejected';
    if (transferStatus == 'received') return 'completed';

    return assignmentStatus;
  }

  // =========================================================
  // TRANSFER CARD
  // =========================================================
  Widget _buildTransferCard({
    required DocumentSnapshot doc,
    required String transferNo,
    required String fromStore,
    required String toStore,
    required String effectiveStatus,
    required int itemsCount,
    required String year,
    required String dayKey,
  }) {
    final statusColor = _statusColor(effectiveStatus);
    final statusIcon = _statusIcon(effectiveStatus);
    final isPending = effectiveStatus == 'pending';
    final isAccepted = effectiveStatus == 'accepted';
    final isCompleted = effectiveStatus == 'completed';
    final isRejected = effectiveStatus == 'rejected';
    final canTap = isAccepted || isCompleted;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: statusColor.withOpacity(0.15), width: 1.5),
      ),
      child: InkWell(
        onTap: canTap
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TransferDetailsPage(doc: doc),
                  ),
                );
              }
            : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primaryDark.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.local_shipping_outlined,
                            color: primaryDark,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Transfer #$transferNo",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "$itemsCount item${itemsCount != 1 ? 's' : ''}",
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: statusColor.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 14, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          effectiveStatus.toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            color: statusColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Route info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "FROM",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: textSecondary.withOpacity(0.7),
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            fromStore,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.arrow_forward,
                        color: accentColor,
                        size: 18,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "TO",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: textSecondary.withOpacity(0.7),
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            toStore,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Action buttons / status banners
              if (isPending)
                Row(
                  children: [
                    Expanded(
                      child: _actionButton(
                        label: "Accept",
                        icon: Icons.check_circle_outline,
                        color: successColor,
                        onPressed: () => _accept(year, dayKey, doc.id, context),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _actionButton(
                        label: "Reject",
                        icon: Icons.cancel_outlined,
                        color: dangerColor,
                        onPressed: () => _reject(year, dayKey, doc.id, context),
                      ),
                    ),
                  ],
                ),

              if (isCompleted)
                _statusBanner(
                  icon: Icons.verified,
                  text: "Completed — Tap to view details",
                  color: accentColor,
                ),

              if (isAccepted)
                _statusBanner(
                  icon: Icons.check_circle,
                  text: "Accepted — Tap to view details",
                  color: successColor,
                ),

              if (isRejected)
                _statusBanner(
                  icon: Icons.cancel,
                  text: "Rejected",
                  color: dangerColor,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // STATUS BANNER
  // =========================================================
  Widget _statusBanner({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // ACTION BUTTON
  // =========================================================
  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // =========================================================
  // STAT BADGE
  // =========================================================
  Widget _statBadge({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                count.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // =========================================================
  // FILTER CHIP with badge
  // =========================================================
  Widget _filterChipWithBadge({
    required String value,
    required String displayLabel,
    required int count,
  }) {
    final isSelected = statusFilter == value;
    final chipColor = value == 'pending'
        ? warningColor
        : value == 'accepted'
        ? successColor
        : value == 'completed'
        ? accentColor
        : value == 'rejected'
        ? dangerColor
        : primaryDark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => statusFilter = value),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? chipColor : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? chipColor : Colors.grey.shade300,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayLabel,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      fontSize: 13,
                      color: isSelected ? Colors.white : textSecondary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withOpacity(0.25)
                          : chipColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      count.toString(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: isSelected ? Colors.white : chipColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // DRAWER
  // =========================================================
  Widget _buildDrawer() {
    final userEmail = user?.email ?? 'No email';
    final userName = user?.displayName ?? userEmail.split('@').first;
    final userPhoto = user?.photoURL;

    return Drawer(
      backgroundColor: cardBackground,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryDark, primaryMedium],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: userPhoto != null
                      ? ClipOval(
                          child: Image.network(
                            userPhoto,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 36,
                            ),
                          ),
                        )
                      : const Icon(Icons.person, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 16),
                Text(
                  userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  userEmail,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.local_shipping,
                        color: Colors.white70,
                        size: 14,
                      ),
                      SizedBox(width: 6),
                      Text(
                        "Driver",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _drawerItem(
                  icon: Icons.dashboard_outlined,
                  label: "Dashboard",
                  onTap: () => Navigator.pop(context),
                ),
                _drawerItem(
                  icon: Icons.history_outlined,
                  label: "Transfer History",
                  onTap: () => Navigator.pop(context),
                ),
                _drawerItem(
                  icon: Icons.notifications_outlined,
                  label: "Notifications",
                  badge: "3",
                  onTap: () => Navigator.pop(context),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _drawerItem(
                  icon: Icons.settings_outlined,
                  label: "Settings",
                  onTap: () => Navigator.pop(context),
                ),
                _drawerItem(
                  icon: Icons.help_outline,
                  label: "Help & Support",
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: dangerColor.withOpacity(0.05),
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: SafeArea(
              child: InkWell(
                onTap: _logout,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: dangerColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout, color: dangerColor, size: 20),
                      SizedBox(width: 10),
                      Text(
                        "Logout",
                        style: TextStyle(
                          color: dangerColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String label,
    String? badge,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: primaryMedium, size: 22),
      title: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 15,
          color: textPrimary,
        ),
      ),
      trailing: badge != null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: dangerColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badge,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : const Icon(Icons.chevron_right, color: textSecondary, size: 18),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      minLeadingWidth: 24,
    );
  }

  // =========================================================
  // EMPTY & ERROR STATES
  // =========================================================
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: primaryDark.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.local_shipping_outlined,
              size: 48,
              color: primaryDark.withOpacity(0.3),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "No transfers found",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: textPrimary.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Try changing the date or filter",
            style: TextStyle(
              fontSize: 14,
              color: textSecondary.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: dangerColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.error_outline,
              size: 48,
              color: dangerColor.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "Error loading transfers",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: textPrimary.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Please check your connection and try again",
            style: TextStyle(
              fontSize: 14,
              color: textSecondary.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // HELPERS
  // =========================================================
  String _selectedDateFormatted() {
    return "${selectedDate.day.toString().padLeft(2, '0')}/"
        "${selectedDate.month.toString().padLeft(2, '0')}/"
        "${selectedDate.year}";
  }

  String _dayName(int weekday) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[weekday - 1];
  }

  Future<void> _accept(
    String year,
    String dayKey,
    String transferNo,
    BuildContext context,
  ) async {
    try {
      await FirebaseService.acceptTransfer(year, dayKey, transferNo);
      _showSnackBar("Transfer accepted successfully", successColor);
    } catch (e) {
      _showSnackBar("Failed to accept transfer", dangerColor);
    }
  }

  Future<void> _reject(
    String year,
    String dayKey,
    String transferNo,
    BuildContext context,
  ) async {
    try {
      await FirebaseService.rejectTransfer(year, dayKey, transferNo);
      _showSnackBar("Transfer rejected", dangerColor);
    } catch (e) {
      _showSnackBar("Failed to reject transfer", dangerColor);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Text(message),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return warningColor;
      case 'accepted':
        return successColor;
      case 'completed':
        return accentColor;
      case 'rejected':
        return dangerColor;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.pending_actions;
      case 'accepted':
        return Icons.check_circle;
      case 'completed':
        return Icons.verified;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }
}
