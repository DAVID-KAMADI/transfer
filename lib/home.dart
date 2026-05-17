// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:inter_store/admin/users_page.dart';
import 'package:inter_store/admin/logo_upload_page.dart';
import 'package:inter_store/admin/reports_page.dart';
import 'package:inter_store/admin_transfers_page.dart';
import 'package:inter_store/assign_transfer_page.dart';
import 'package:inter_store/auth/login_page.dart';
import '../services/api_service.dart';
import '../services/firebase_service.dart';
import '../models/transfer.dart';

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E3A5F),
          primary: const Color(0xFF1E3A5F),
          secondary: const Color(0xFF4A90D9),
          surface: Colors.white,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
      child: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Transfer> transfers = [];
  bool isLoading = false;
  Set<int> selectedIndexes = {};
  User? user;
  Map<String, dynamic>? userData;
  int pendingTransfersCount = 0;

  // Firestore database instance
  final FirebaseFirestore db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'interstore',
  );

  // Consistent color palette
  static const Color primaryDark = Color(0xFF1E3A5F);
  static const Color primaryMedium = Color(0xFF2E5A8C);
  static const Color accentColor = Color(0xFF4A90D9);

  @override
  void initState() {
    super.initState();
    user = FirebaseAuth.instance.currentUser;
    _fetchUserData();
    _countPendingTransfers();
  }

  // =========================================================
  // NAVIGATE TO ADMIN TRANSFERS
  // =========================================================
  void _navigateToAdminTransfers() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminTransfersPage()),
    );
  }

  // =========================================================
  // COUNT PENDING TRANSFERS
  // =========================================================
  Future<void> _countPendingTransfers() async {
    try {
      int totalCount = 0;

      debugPrint('=== DEBUG: Counting ALL pending transfers ===');

      // Query recent days to find all pending transfers
      final now = DateTime.now();

      // Check last 30 days for pending transfers
      for (int i = 0; i < 30; i++) {
        final date = now.subtract(Duration(days: i));
        final year = date.year.toString();
        final dayKey =
            "${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

        debugPrint('Querying date: $year/$dayKey');

        try {
          // Query transfers for pending status
          final snapshot = await db
              .collection('transfers')
              .doc(year)
              .collection(dayKey)
              .where('status', isEqualTo: 'pending')
              .get();

          final dayCount = snapshot.docs.length;
          totalCount += dayCount;

          if (dayCount > 0) {
            debugPrint('Found $dayCount pending transfers for $year/$dayKey');

            // Print details of found transfers
            for (final doc in snapshot.docs) {
              final data = doc.data();
              debugPrint(
                '  - Transfer: ${data['transferNo']}, Status: ${data['status']}',
              );
            }
          }
        } catch (e) {
          // Continue even if a specific day doesn't exist
          debugPrint('Error querying $year/$dayKey: $e');
        }
      }

      debugPrint('Total pending transfers: $totalCount');
      debugPrint('Will show badge: ${totalCount > 0 ? 'YES' : 'NO'}');

      if (mounted) {
        setState(() {
          pendingTransfersCount = totalCount;
        });
        debugPrint('setState called with count: $totalCount');
      }
    } catch (e) {
      debugPrint('Error counting pending transfers: $e');
      if (mounted) {
        setState(() {
          pendingTransfersCount = 0;
        });
      }
    }
  }

  // Refresh pending transfers count when returning to page
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _countPendingTransfers();
    });
  }

  // =========================================================
  // FETCH USER DATA
  // =========================================================
  Future<void> _fetchUserData() async {
    if (user?.email == null) return;

    try {
      final doc = await db.collection('users').doc(user!.email).get();
      if (doc.exists && doc.data() != null) {
        setState(() {
          userData = doc.data() as Map<String, dynamic>;
        });
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
    }
  }

  @override
  void dispose() {
    controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void searchTransfer() async {
    if (controller.text.isEmpty) {
      _showSnackBar('Please enter a transfer number', isError: true);
      return;
    }

    setState(() {
      isLoading = true;
      selectedIndexes.clear();
    });

    try {
      final result = await ApiService.fetchTransferDetails(controller.text);
      setState(() {
        transfers = result;
      });
      if (result.isEmpty) {
        _showSnackBar('No transfers found');
      }
    } catch (e) {
      _showSnackBar('Error fetching data', isError: true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  void createTransfer() async {
    if (selectedIndexes.isEmpty) {
      _showSnackBar('Please select at least one item', isError: true);
      return;
    }

    final transferNo = controller.text.trim();

    if (transferNo.isEmpty) {
      _showSnackBar('Enter a valid transfer number', isError: true);
      return;
    }

    final selectedItems = selectedIndexes.map((i) => transfers[i]).toList();

    setState(() => isLoading = true);

    try {
      await FirebaseService.saveTransfer(transferNo, selectedItems);

      _showSnackBar('Transfer saved successfully');

      setState(() {
        selectedIndexes.clear();
        transfers.clear();
        controller.clear();
      });
    } catch (e) {
      final message = e.toString();

      if (message.contains('already exists')) {
        _showSnackBar(
          'This transfer already exists. Please use a different number.',
          isError: true,
        );
      } else {
        _showSnackBar('Failed to save transfer. Try again.', isError: true);
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  void toggleSelectAll() {
    setState(() {
      if (selectedIndexes.length == transfers.length && transfers.isNotEmpty) {
        selectedIndexes.clear();
      } else {
        selectedIndexes = Set.from(List.generate(transfers.length, (i) => i));
      }
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade700 : primaryDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAllSelected =
        selectedIndexes.length == transfers.length && transfers.isNotEmpty;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;
    final isDesktop = screenWidth >= 900;

    // Debug print to track badge visibility
    debugPrint(
      'BUILD: pendingTransfersCount = $pendingTransfersCount, will show badge: ${pendingTransfersCount > 0}',
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryDark,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.store_rounded, size: 24),
            SizedBox(width: 10),
            Text(
              '748 Store',
              style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5),
            ),
          ],
        ),
        actions: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => _navigateToAdminTransfers(),
              ),
              if (pendingTransfersCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    pendingTransfersCount > 99
                        ? '99+'
                        : pendingTransfersCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.all(isTablet ? 32 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Section
                  _buildWelcomeSection(isTablet, isDesktop),
                  SizedBox(height: isTablet ? 32 : 24),

                  // Search Section
                  _buildSearchSection(isTablet),
                  SizedBox(height: isTablet ? 24 : 20),

                  // Action Buttons
                  if (transfers.isNotEmpty) ...[
                    _buildActionButtons(isAllSelected, isTablet),
                    SizedBox(height: isTablet ? 24 : 16),
                  ],

                  // Results Header
                  if (transfers.isNotEmpty) ...[
                    _buildResultsHeader(),
                    SizedBox(height: isTablet ? 16 : 12),
                  ],

                  // Transfer List
                  _buildTransferList(constraints, isTablet, isDesktop),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWelcomeSection(bool isTablet, bool isDesktop) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(
        isDesktop
            ? 32
            : isTablet
            ? 28
            : 20,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [primaryDark, primaryMedium],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: isDesktop
                    ? 28
                    : isTablet
                    ? 24
                    : 20,
                backgroundColor: Colors.white.withOpacity(0.2),
                child: Text(
                  user?.email != null && user!.email!.isNotEmpty
                      ? user!.email![0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontSize: isDesktop
                        ? 24
                        : isTablet
                        ? 20
                        : 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              SizedBox(
                width: isDesktop
                    ? 20
                    : isTablet
                    ? 16
                    : 12,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back,',
                      style: TextStyle(
                        fontSize: isDesktop
                            ? 16
                            : isTablet
                            ? 14
                            : 12,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      userData?['name'] ??
                          user?.displayName ??
                          user?.email ??
                          'User',
                      style: TextStyle(
                        fontSize: isDesktop
                            ? 28
                            : isTablet
                            ? 24
                            : 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: isDesktop ? 16 : 12),
          Text(
            'Manage your transfers efficiently',
            style: TextStyle(
              fontSize: isDesktop
                  ? 16
                  : isTablet
                  ? 14
                  : 14,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection(bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 28 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Search Transfer',
            style: TextStyle(
              fontSize: isTablet ? 18 : 16,
              fontWeight: FontWeight.w600,
              color: primaryDark,
            ),
          ),
          SizedBox(height: isTablet ? 16 : 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: 'Enter Transfer No',
                    prefixIcon: const Icon(Icons.search, color: primaryMedium),
                    suffixIcon: controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              controller.clear();
                              setState(() => transfers.clear());
                            },
                          )
                        : null,
                  ),
                  onSubmitted: (_) => searchTransfer(),
                ),
              ),
              SizedBox(width: isTablet ? 16 : 12),
              ElevatedButton.icon(
                onPressed: isLoading ? null : searchTransfer,
                icon: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.search),
                label: const Text('Search'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryDark,
                  foregroundColor: Colors.white,
                  minimumSize: Size(isTablet ? 120 : 100, isTablet ? 56 : 50),
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 24 : 20,
                    vertical: isTablet ? 16 : 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isAllSelected, bool isTablet) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Wrap(
        spacing: isTablet ? 14 : 10,
        runSpacing: isTablet ? 14 : 10,
        children: [
          _ActionButton(
            icon: Icons.save_alt,
            label: 'Create Transfer',
            onPressed: selectedIndexes.isEmpty ? null : createTransfer,
            isPrimary: true,
            isTablet: isTablet,
          ),
          _ActionButton(
            icon: isAllSelected ? Icons.deselect : Icons.select_all,
            label: isAllSelected ? 'Deselect All' : 'Select All',
            onPressed: transfers.isEmpty ? null : toggleSelectAll,
            isTablet: isTablet,
          ),
        ],
      ),
    );
  }

  Widget _buildResultsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Results (${transfers.length})',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: primaryDark,
          ),
        ),
        if (selectedIndexes.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${selectedIndexes.length} selected',
              style: const TextStyle(
                color: accentColor,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTransferList(
    BoxConstraints constraints,
    bool isTablet,
    bool isDesktop,
  ) {
    if (transfers.isEmpty) {
      return SizedBox(
        height: constraints.maxHeight * 0.4,
        child: _buildEmptyState(),
      );
    }

    // For desktop/tablet, use a grid layout
    if (isDesktop) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 3.5,
          crossAxisSpacing: 16,
          mainAxisSpacing: 12,
        ),
        itemCount: transfers.length,
        itemBuilder: (context, index) => _buildTransferCard(index),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: transfers.length,
      padding: const EdgeInsets.only(bottom: 20),
      itemBuilder: (context, index) => _buildTransferCard(index),
    );
  }

  Widget _buildTransferCard(int index) {
    final item = transfers[index];
    final isSelected = selectedIndexes.contains(index);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 10),
      child: Card(
        elevation: isSelected ? 4 : 1,
        color: isSelected ? accentColor.withOpacity(0.05) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isSelected
              ? const BorderSide(color: accentColor, width: 2)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: () {
            setState(() {
              if (isSelected) {
                selectedIndexes.remove(index);
              } else {
                selectedIndexes.add(index);
              }
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected ? accentColor : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? accentColor : Colors.grey.shade400,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.code,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: primaryDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.descr,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: primaryDark.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Qty: ${item.qty}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: primaryDark,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_outlined,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No transfers yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Search for a transfer number to get started',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryDark, primaryMedium],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            accountName: Text(
              userData?['name'] ?? user?.displayName ?? 'No Name',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            accountEmail: Text(user?.email ?? 'No Email'),
            currentAccountPicture: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  user?.email != null ? user!.email![0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          _DrawerItem(
            icon: Icons.home_rounded,
            label: 'Home',
            onTap: () => Navigator.pop(context),
          ),
          _DrawerItem(
            icon: Icons.list_alt_rounded,
            label: 'Users',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UsersPage()),
              );
            },
          ),
          _DrawerItem(
            icon: Icons.cloud_upload,
            label: 'Upload Logo',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LogoUploadPage()),
              );
            },
          ),
          _DrawerItem(
            icon: Icons.analytics_outlined,
            label: 'Reports',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReportsPage()),
              );
            },
          ),
          _DrawerItem(
            icon: Icons.list_alt_rounded,
            label: 'Transfers',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminTransfersPage()),
              );
            },
          ),
          _DrawerItem(
            icon: Icons.list_alt_rounded,
            label: 'Assign Transfer',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AssignTransferPage()),
              );
            },
          ),

          const Divider(height: 1),
          _DrawerItem(
            icon: Icons.logout_rounded,
            label: 'Logout',
            color: Colors.red.shade700,
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginPage()),
                (Route<dynamic> route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool isTablet;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.onPressed,
    this.isPrimary = false,
    this.isTablet = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: isTablet ? 22 : 18),
      label: Text(label, style: TextStyle(fontSize: isTablet ? 15 : 14)),
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary ? const Color(0xFF1E3A5F) : Colors.white,
        foregroundColor: isPrimary ? Colors.white : const Color(0xFF1E3A5F),
        side: isPrimary ? null : const BorderSide(color: Color(0xFFE2E8F0)),
        elevation: 0,
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 20 : 16,
          vertical: isTablet ? 14 : 12,
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color ?? const Color(0xFF1E3A5F)),
      title: Text(
        label,
        style: TextStyle(
          color: color ?? const Color(0xFF1E3A5F),
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}
