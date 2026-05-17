// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:inter_store/AdminTransferDetailsPage.dart';
import 'package:shimmer/shimmer.dart';
import '../services/firebase_service.dart';

class AssignTransferPage extends StatefulWidget {
  const AssignTransferPage({super.key});

  @override
  State<AssignTransferPage> createState() => _AssignTransferPageState();
}

class _AssignTransferPageState extends State<AssignTransferPage> {
  DateTime selectedDate = DateTime.now();

  String? selectedTransferId;
  Map<String, dynamic>? selectedTransferData;

  bool isAssigning = false;

  String searchQuery = "";

  Set<String> selectedTransfers = {};
  String selectedFilter = "all";
  bool multiSelectMode = false;

  // Consistent color palette
  static const Color primaryDark = Color(0xFF1E3A5F);
  static const Color primaryMedium = Color(0xFF2E5A8C);
  static const Color accentColor = Color(0xFF4A90D9);

  // ✅ Use interstore database
  final FirebaseFirestore db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'interstore',
  );

  String get selectedYear => selectedDate.year.toString();

  String get selectedDayKey =>
      "${selectedDate.month.toString().padLeft(2, '0')}-"
      "${selectedDate.day.toString().padLeft(2, '0')}";

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
        selectedTransfers.clear();
        multiSelectMode = false;
        selectedTransferId = null;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _fetchDrivers() async {
    final snapshot = await db
        .collection('users')
        .where('role', isEqualTo: 'driver')
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {'uid': doc.id, 'name': data['name'] ?? 'No Name'};
    }).toList();
  }

  Future<void> _assignDriver() async {
    final driver = await _selectDriverDialog();
    if (driver == null) return;

    setState(() => isAssigning = true);

    try {
      final targets = multiSelectMode
          ? selectedTransfers
          : {selectedTransferId!};

      for (final id in targets) {
        await FirebaseService.assignDriver(
          selectedYear,
          selectedDayKey,
          id,
          driver['uid'],
          driver['name'],
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text("Assigned ${targets.length} transfer(s)"),
              ],
            ),
            backgroundColor: primaryDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }

      setState(() {
        selectedTransfers.clear();
        multiSelectMode = false;
        selectedTransferId = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Assignment failed'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isAssigning = false);
    }
  }

  Future<Map<String, dynamic>?> _selectDriverDialog() async {
    final drivers = await _fetchDrivers();

    if (!mounted) return null;

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.local_shipping, color: primaryDark),
              SizedBox(width: 12),
              Text(
                'Select Driver',
                style: TextStyle(
                  color: primaryDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: drivers.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'No drivers found',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: drivers.length,
                    itemBuilder: (context, index) {
                      final driver = drivers[index];

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: accentColor.withOpacity(0.1),
                            child: const Icon(Icons.person, color: accentColor),
                          ),
                          title: Text(
                            driver['name'],
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            driver['uid'],
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          onTap: () => Navigator.pop(context, driver),
                        ),
                      );
                    },
                  ),
          ),
        );
      },
    );
  }

  bool _matchesFilter(Map<String, dynamic> data) {
    final status = data['assignmentStatus'];
    final assignedTo = data['assignedTo'];

    switch (selectedFilter) {
      case "unassigned":
        return assignedTo == null;
      case "pending":
        return status == 'pending';
      case "accepted":
        return status == 'accepted';
      case "rejected":
        return status == 'rejected';
      default:
        return true;
    }
  }

  Future<void> _selectAllVisible() async {
    final snapshot = await db
        .collection('transfers')
        .doc(selectedYear)
        .collection(selectedDayKey)
        .get();

    final filtered = snapshot.docs.where((doc) {
      final data = doc.data();
      return _matchesFilter(data);
    });

    setState(() {
      selectedTransfers = filtered.map((d) => d.id).toSet();
    });
  }

  void _viewTransferDetails(DocumentSnapshot doc) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AdminTransferDetailsPage(doc: doc)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryDark,
        foregroundColor: Colors.white,
        title: const Text(
          'Assign Transfer',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          if (multiSelectMode)
            TextButton(
              onPressed: () {
                setState(() {
                  multiSelectMode = false;
                  selectedTransfers.clear();
                });
              },
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),

      floatingActionButton:
          (selectedTransferId != null || selectedTransfers.isNotEmpty)
          ? Padding(
              padding: const EdgeInsets.all(8),
              child: ElevatedButton.icon(
                onPressed: isAssigning ? null : _assignDriver,
                icon: isAssigning
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.assignment_ind),
                label: Text(
                  isAssigning
                      ? "Assigning..."
                      : multiSelectMode
                      ? "Assign ${selectedTransfers.length} Selected"
                      : "Assign Driver",
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryDark,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(220, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
              ),
            )
          : null,

      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,

      body: Column(
        children: [
          _buildHeader(),
          _buildSearchBar(),
          _buildFilters(),
          Expanded(child: _buildTransferList()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: primaryDark.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "$selectedYear / $selectedDayKey",
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: primaryDark,
                fontSize: 14,
              ),
            ),
          ),
          const Spacer(),
          if (multiSelectMode)
            TextButton.icon(
              onPressed: _selectAllVisible,
              icon: const Icon(Icons.select_all, size: 18),
              label: const Text("Select All"),
            ),
          IconButton(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_month, color: primaryDark),
            tooltip: "Pick Date",
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: TextField(
        decoration: InputDecoration(
          hintText: "Search transfer number...",
          hintStyle: TextStyle(color: Colors.grey.shade400),
          prefixIcon: const Icon(Icons.search, color: primaryMedium),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        onChanged: (value) {
          setState(() => searchQuery = value.toLowerCase());
        },
      ),
    );
  }

  Widget _buildFilters() {
    final filters = ["all", "unassigned", "pending", "accepted", "rejected"];
    final filterColors = {
      "all": Colors.grey,
      "unassigned": Colors.orange,
      "pending": Colors.blue,
      "accepted": Colors.green,
      "rejected": Colors.red,
    };

    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = selectedFilter == filter;
          final color = filterColors[filter] ?? Colors.grey;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(filter.toUpperCase()),
              selected: isSelected,
              selectedColor: color.withOpacity(0.15),
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? color : Colors.grey.shade600,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected
                      ? color.withOpacity(0.3)
                      : Colors.grey.shade200,
                ),
              ),
              onSelected: (_) {
                setState(() {
                  selectedFilter = filter;
                  selectedTransfers.clear();
                  multiSelectMode = false;
                  selectedTransferId = null;
                });
              },
            ),
          );
        },
      ),
    );
  }

  // =========================================================
  // ✨ SHIMMER LOADING SKELETON
  // =========================================================
  Widget _buildShimmerLoading() {
    return ListView.builder(
      itemCount: 6,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey.shade200,
          highlightColor: Colors.grey.shade100,
          child: Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Container(
              height: 120,
              padding: const EdgeInsets.all(16),
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
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              height: 16,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: 150,
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

  Widget _buildTransferList() {
    return StreamBuilder<QuerySnapshot>(
      stream: db
          .collection('transfers')
          .doc(selectedYear)
          .collection(selectedDayKey)
          .snapshots(),
      builder: (context, snapshot) {
        // ✨ Show shimmer while waiting for first data
        if (!snapshot.hasData && !snapshot.hasError) {
          return _buildShimmerLoading();
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                const SizedBox(height: 12),
                const Text(
                  'Error loading transfers',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;

          final matchesSearch =
              searchQuery.isEmpty || doc.id.toLowerCase().contains(searchQuery);

          final matchesFilter = _matchesFilter(data);

          return matchesSearch && matchesFilter;
        }).toList();

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 64,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  'No transfers found',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: docs.length,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;

            final isSelected = selectedTransfers.contains(doc.id);
            final isSingleSelected =
                selectedTransferId == doc.id && !multiSelectMode;

            final assignedToName = data['assignedToName'];
            final assignmentStatus = data['assignmentStatus'];

            return Card(
              elevation: isSingleSelected ? 3 : 1,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: isSelected || isSingleSelected
                    ? const BorderSide(color: accentColor, width: 2)
                    : BorderSide.none,
              ),
              child: InkWell(
                onTap: () {
                  setState(() {
                    if (multiSelectMode) {
                      if (isSelected) {
                        selectedTransfers.remove(doc.id);
                        if (selectedTransfers.isEmpty) {
                          multiSelectMode = false;
                        }
                      } else {
                        selectedTransfers.add(doc.id);
                      }
                    } else {
                      selectedTransferId = doc.id;
                      selectedTransferData = data;
                    }
                  });
                },
                onLongPress: () {
                  setState(() {
                    if (!multiSelectMode) {
                      selectedTransferId = null;
                      multiSelectMode = true;
                      selectedTransfers = {doc.id};
                    } else {
                      if (isSelected) {
                        selectedTransfers.remove(doc.id);
                        if (selectedTransfers.isEmpty) {
                          multiSelectMode = false;
                        }
                      } else {
                        selectedTransfers.add(doc.id);
                      }
                    }
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (multiSelectMode)
                            Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: Icon(
                                isSelected
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                color: isSelected
                                    ? accentColor
                                    : Colors.grey.shade400,
                                size: 24,
                              ),
                            ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Transfer #${doc.id}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: primaryDark,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "${data['fromStore'] ?? '-'} → ${data['toStore'] ?? '-'}",
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                  ),
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
                              color: _statusColor(
                                assignmentStatus,
                              ).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              assignmentStatus ?? 'unassigned',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _statusColor(assignmentStatus),
                                fontSize: 11,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),

                      if (assignedToName != null) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(
                              Icons.local_shipping,
                              size: 16,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "Driver: $assignedToName",
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 12),
                      const Divider(height: 1),

                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _viewTransferDetails(doc),
                                icon: const Icon(Icons.visibility, size: 18),
                                label: const Text("View Details"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: primaryDark,
                                  elevation: 0,
                                  side: BorderSide(color: Colors.grey.shade200),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),

                            if (isSingleSelected && !multiSelectMode) ...[
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: isAssigning ? null : _assignDriver,
                                  icon: isAssigning
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.assignment_ind,
                                          size: 18,
                                        ),
                                  label: const Text("Assign"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: accentColor,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'assigned':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
