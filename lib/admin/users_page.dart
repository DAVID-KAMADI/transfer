// ignore_for_file: unused_field, deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../services/api_service.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage>
    with SingleTickerProviderStateMixin {
  String searchQuery = '';
  List<Map<String, dynamic>> availableUsers = [];
  List<Map<String, dynamic>> selectedUsers = [];
  bool isLoadingUsers = false;
  String selectedRole = 'PARTS & PROCUREMENT'; // Default role
  final List<String> availableRoles = [
    'PARTS & PROCUREMENT',
    'LOGISTICS SUPPORT',
    'ADMIN',
    'DRIVER',
    'MANAGER',
  ];

  TabController? _tabController;
  List<Map<String, dynamic>> interstoreUsers = [];
  bool isLoadingInterstoreUsers = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Initialize with users for the default role
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchUsersByRole();
      _fetchInterstoreUsers();
    });
  }

  // =========================================================
  // BUILD EXISTING USERS TAB
  // =========================================================
  Widget _buildExistingUsersTab() {
    return Column(
      children: [
        // SEARCH BOX
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            onChanged: (value) =>
                setState(() => searchQuery = value.toLowerCase()),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Search users...",
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
              prefixIcon: const Icon(Icons.search, color: Colors.white),
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ROLE SELECTION
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.people, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButton<String>(
                    value: selectedRole,
                    dropdownColor: Colors.white,
                    style: const TextStyle(color: Colors.white),
                    underline: Container(
                      height: 2,
                      color: Colors.white.withOpacity(0.5),
                    ),
                    items: availableRoles.map((role) {
                      return DropdownMenuItem<String>(
                        value: role,
                        child: Text(
                          role,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedRole = value!;
                        selectedUsers.clear();
                      });
                      _fetchUsersByRole();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                if (isLoadingUsers)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                else
                  IconButton(
                    onPressed: _fetchUsersByRole,
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    tooltip: 'Refresh Users',
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // AVAILABLE USERS LIST
        Expanded(
          child: availableUsers.isEmpty
              ? const Center(
                  child: Text(
                    'No users found for this role',
                    style: TextStyle(color: Colors.white70),
                  ),
                )
              : ListView.builder(
                  itemCount: availableUsers.length,
                  itemBuilder: (context, index) {
                    final user = availableUsers[index];
                    final email = user['email'] ?? '';
                    final name = user['name'] ?? 'Unknown';
                    final isSelected = selectedUsers.any(
                      (selected) => selected['email'] == email,
                    );

                    return Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? successColor
                              : Colors.grey.shade300,
                          width: 1,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: isSelected
                              ? successColor
                              : primaryMedium,
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'U',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? successColor : textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (user['Staff_Section'] != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: _getRoleColor(user['Staff_Section']),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  user['Staff_Section'],
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          email,
                          style: TextStyle(fontSize: 12, color: textSecondary),
                        ),
                        trailing: Checkbox(
                          value: isSelected,
                          onChanged: (_) => _toggleUserSelection(user),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                        onTap: () => _toggleUserSelection(user),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // =========================================================
  // BUILD MANAGE ROLES TAB
  // =========================================================
  Widget _buildManageRolesTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Manage Interstore Users',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Assign roles to control page access',
                  style: TextStyle(fontSize: 14, color: textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // USERS LIST
          Expanded(
            child: isLoadingInterstoreUsers
                ? const Center(child: CircularProgressIndicator())
                : interstoreUsers.isEmpty
                ? const Center(
                    child: Text(
                      'No users found in interstore',
                      style: TextStyle(color: textSecondary),
                    ),
                  )
                : ListView.builder(
                    itemCount: interstoreUsers.length,
                    itemBuilder: (context, index) {
                      final user = interstoreUsers[index];
                      final email = user['email'] ?? '';
                      final name = user['name'] ?? 'Unknown';
                      final role = user['role'] ?? 'user';
                      final station = user['station'] ?? 'Not Assigned';

                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // User info row
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: primaryMedium,
                                    child: Text(
                                      name.isNotEmpty
                                          ? name[0].toUpperCase()
                                          : 'U',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          email,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: _getRoleColor(role),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                role.toUpperCase(),
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: primaryDark.withOpacity(
                                                  0.1,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                station,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w500,
                                                  color: primaryDark,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => _editUserDialog(user),
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 20,
                                    ),
                                    color: textSecondary,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Action buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _editUserDialog(user),
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 18,
                                      ),
                                      label: const Text('Edit User'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: primaryDark,
                                        side: const BorderSide(
                                          color: primaryDark,
                                        ),
                                        minimumSize: const Size(
                                          double.infinity,
                                          40,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
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

  void _editUserDialog(Map<String, dynamic> user) {
    final nameController = TextEditingController(text: user['name'] ?? '');
    final email = user['email'] ?? '';
    final currentRole = user['role'] ?? 'user';
    final currentStation = user['station'] ?? '';

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [primaryDark, primaryMedium],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'Edit User Role & Station',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),

              // User info display
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      email,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'User ID: ${user['id']}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Form fields
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    // Name field (read-only)
                    TextField(
                      controller: nameController,
                      readOnly: true,
                      style: const TextStyle(fontSize: 16),
                      decoration: InputDecoration(
                        labelText: 'Name',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: primaryDark),
                        ),
                        filled: true,
                        fillColor: backgroundColor,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Role dropdown
                    // Role dropdown
                    DropdownButtonFormField<String>(
                      value:
                          [
                            'user',
                            'driver',
                            'admin',
                            'manager',
                          ].contains(currentRole.toLowerCase())
                          ? currentRole.toLowerCase()
                          : 'user',
                      decoration: InputDecoration(
                        labelText: 'Role',
                        prefixIcon: const Icon(
                          Icons.admin_panel_settings_outlined,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: primaryDark),
                        ),
                        filled: true,
                        fillColor: backgroundColor,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'user', child: Text('User')),
                        DropdownMenuItem(
                          value: 'driver',
                          child: Text('Driver'),
                        ),
                        DropdownMenuItem(value: 'admin', child: Text('Admin')),
                        DropdownMenuItem(
                          value: 'manager',
                          child: Text('Manager'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          user['role'] = value;
                        }
                      },
                      menuMaxHeight: 200,
                    ),
                    const SizedBox(height: 16),

                    // Station dropdown
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: currentStation.isNotEmpty ? currentStation : null,
                      decoration: InputDecoration(
                        labelText: 'Station',
                        prefixIcon: const Icon(Icons.store_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: primaryDark),
                        ),
                        filled: true,
                        fillColor: backgroundColor,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        isDense: true,
                      ),
                      items: stations.map((station) {
                        return DropdownMenuItem(
                          value: station,
                          child: Text(
                            station,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          user['station'] = value;
                        }
                      },
                      menuMaxHeight: 200,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white),
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _updateInterstoreUser(user['id'], {
                          'role': user['role'],
                          'station': user['station'],
                          'updatedAt': FieldValue.serverTimestamp(),
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: primaryDark,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Save Changes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // BUILD IMPORT USERS TAB
  // =========================================================
  Widget _buildImportUsersTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ROLE SELECTION HEADER
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Import Users from 748 Air Services',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryDark,
                  ),
                ),
                const SizedBox(height: 16),

                // ROLE SELECTION
                Row(
                  children: [
                    Expanded(
                      child: DropdownButton<String>(
                        value: selectedRole,
                        items: availableRoles.map((role) {
                          return DropdownMenuItem<String>(
                            value: role,
                            child: Text(
                              role,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedRole = value!;
                            selectedUsers.clear();
                          });
                          _fetchUsersByRole();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (isLoadingUsers)
                      const CircularProgressIndicator()
                    else
                      IconButton(
                        onPressed: _fetchUsersByRole,
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Refresh Users',
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // CONTENT AREA
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // AVAILABLE USERS LIST
                Expanded(
                  flex: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Available Users',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: primaryDark,
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: availableUsers.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No users found for this role',
                                    style: TextStyle(color: textSecondary),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: availableUsers.length,
                                  itemBuilder: (context, index) {
                                    final user = availableUsers[index];
                                    final email = user['email'] ?? '';
                                    final name = user['name'] ?? 'Unknown';
                                    final isSelected = selectedUsers.any(
                                      (selected) => selected['email'] == email,
                                    );

                                    return Container(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? successColor.withOpacity(0.1)
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected
                                              ? successColor
                                              : Colors.grey.shade300,
                                          width: 1,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.05,
                                            ),
                                            blurRadius: 2,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(12),
                                        onTap: () => _showUserDetails(user),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // User info row
                                              Row(
                                                children: [
                                                  CircleAvatar(
                                                    backgroundColor: isSelected
                                                        ? successColor
                                                        : primaryMedium,
                                                    radius: 24,
                                                    child: Text(
                                                      name.isNotEmpty
                                                          ? name[0]
                                                                .toUpperCase()
                                                          : 'U',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 18,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 16),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          name,
                                                          style: TextStyle(
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color: isSelected
                                                                ? successColor
                                                                : textPrimary,
                                                          ),
                                                          maxLines: 2,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                        const SizedBox(
                                                          height: 4,
                                                        ),
                                                        Text(
                                                          email,
                                                          style: TextStyle(
                                                            fontSize: 13,
                                                            color:
                                                                textSecondary,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Checkbox(
                                                    value: isSelected,
                                                    onChanged: (_) =>
                                                        _toggleUserSelection(
                                                          user,
                                                        ),
                                                    materialTapTargetSize:
                                                        MaterialTapTargetSize
                                                            .shrinkWrap,
                                                  ),
                                                ],
                                              ),
                                              // Department badge
                                              if (user['Staff_Section'] !=
                                                  null) ...[
                                                const SizedBox(height: 12),
                                                Container(
                                                  width: double.infinity,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 8,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: primaryDark
                                                        .withOpacity(0.08),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    border: Border.all(
                                                      color: primaryDark
                                                          .withOpacity(0.2),
                                                      width: 1,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.work_outline,
                                                        size: 14,
                                                        color: primaryDark,
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Expanded(
                                                        child: Text(
                                                          user['Staff_Section'],
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: primaryDark,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // SELECTED USERS SECTION
                Expanded(
                  flex: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const Icon(Icons.person_add, color: primaryDark),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Selected Users (${selectedUsers.length})',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: primaryDark,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: selectedUsers.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No users selected',
                                    style: TextStyle(color: textSecondary),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: selectedUsers.length,
                                  itemBuilder: (context, index) {
                                    final user = selectedUsers[index];
                                    final email = user['email'] ?? '';
                                    final name = user['name'] ?? 'Unknown';

                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: successColor,
                                        child: Text(
                                          name.isNotEmpty
                                              ? name[0].toUpperCase()
                                              : 'U',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      title: Text(name),
                                      subtitle: Text(email),
                                      trailing: IconButton(
                                        icon: const Icon(
                                          Icons.remove_circle,
                                          color: dangerColor,
                                        ),
                                        onPressed: () =>
                                            _toggleUserSelection(user),
                                      ),
                                    );
                                  },
                                ),
                        ),
                        // SAVE BUTTON
                        if (selectedUsers.isNotEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            child: ElevatedButton.icon(
                              onPressed: _saveSelectedUsers,
                              icon: const Icon(Icons.save, color: Colors.white),
                              label: const Text(
                                'Save Selected Users to Interstore',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: successColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // FETCH INTERSTORE USERS
  // =========================================================
  Future<void> _fetchInterstoreUsers() async {
    setState(() => isLoadingInterstoreUsers = true);

    try {
      final db = FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'interstore',
      );

      final snapshot = await db.collection('users').get();

      final List<Map<String, dynamic>> users = [];

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          users.add({
            'id': doc.id,
            'name': data['name'] ?? '',
            'email': data['email'] ?? '',
            'phone': data['phone'] ?? '',
            'role': data['role'] ?? 'user',
            'station': data['station'] ?? '',
            'createdAt': data['createdAt'],
          });
        }
      }

      setState(() {
        interstoreUsers = users;
        isLoadingInterstoreUsers = false;
      });

    } catch (e) {
      setState(() => isLoadingInterstoreUsers = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching interstore users: $e'),
            backgroundColor: dangerColor,
          ),
        );
      }
    }
  }

  // =========================================================
  // UPDATE INTERSTORE USER
  // =========================================================
  Future<void> _updateInterstoreUser(
    String userId,
    Map<String, dynamic> userData,
  ) async {
    try {
      final db = FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'interstore',
      );

      await db.collection('users').doc(userId).update(userData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User updated successfully!'),
            backgroundColor: successColor,
          ),
        );
      }

      // Refresh the users list
      _fetchInterstoreUsers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating user: $e'),
            backgroundColor: dangerColor,
          ),
        );
      }
    }
  }

  // =========================================================
  // FETCH USERS FROM 748 AIR SERVICES
  // =========================================================
  Future<void> _fetchUsersByRole() async {
    setState(() => isLoadingUsers = true);

    try {
      final users = await ApiService.fetchUsersByRole(selectedRole);

      setState(() {
        availableUsers = users;
        isLoadingUsers = false;
      });

    } catch (e) {
      setState(() => isLoadingUsers = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching users: $e'),
            backgroundColor: dangerColor,
          ),
        );
      }
    }
  }

  // =========================================================
  // SAVE SELECTED USERS TO INTERSTORE
  // =========================================================
  Future<void> _saveSelectedUsers() async {
    if (selectedUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one user to save'),
          backgroundColor: warningColor,
        ),
      );
      return;
    }

    try {
      await ApiService.saveUsersToInterstore(selectedUsers);

      setState(() => selectedUsers.clear());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Users saved successfully to interstore!'),
            backgroundColor: successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving users: $e'),
            backgroundColor: dangerColor,
          ),
        );
      }
    }
  }

  // =========================================================
  // GET ROLE COLOR
  // =========================================================
  Color _getRoleColor(String role) {
    switch (role.toUpperCase()) {
      case 'PARTS & PROCUREMENT':
        return Colors.purple.shade600;
      case 'LOGISTICS SUPPORT':
        return Colors.blue.shade600;
      case 'ADMIN':
        return Colors.red.shade600;
      case 'DRIVER':
        return Colors.orange.shade600;
      case 'MANAGER':
        return Colors.teal.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  // =========================================================
  // SHOW USER DETAILS POPUP
  // =========================================================
  void _showUserDetails(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [primaryDark, primaryMedium],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: Text(
                        (user['name'] ?? 'Unknown')[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user['name'] ?? 'Unknown Name',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            user['Staff_Section'] ?? 'No Role',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // User Details
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow(
                        Icons.email,
                        'Email',
                        user['email'] ?? 'N/A',
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        Icons.phone,
                        'Phone',
                        user['Staff_Telephone'] ?? 'N/A',
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        Icons.badge,
                        'Staff ID',
                        user['Staff_Number'] ?? 'N/A',
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        Icons.work,
                        'Designation',
                        user['Staff_Designation'] ?? 'N/A',
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        Icons.layers,
                        'Level',
                        user['Staff_Level'] ?? 'N/A',
                      ),
                      if (user['Staff_Nationality'] != null) ...[
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          Icons.flag,
                          'Nationality',
                          user['Staff_Nationality'],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _toggleUserSelection(user);
                        },
                        icon: Icon(
                          selectedUsers.any(
                                (selected) =>
                                    selected['email'] == user['email'],
                              )
                              ? Icons.remove_circle_outline
                              : Icons.add_circle_outline,
                          color: primaryDark,
                        ),
                        label: Text(
                          selectedUsers.any(
                                (selected) =>
                                    selected['email'] == user['email'],
                              )
                              ? 'Remove from Selection'
                              : 'Add to Selection',
                          style: TextStyle(color: primaryDark),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: primaryDark),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                        label: const Text('Close'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryDark,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: primaryMedium),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================
  // TOGGLE USER SELECTION
  // =========================================================
  void _toggleUserSelection(Map<String, dynamic> user) {
    setState(() {
      if (selectedUsers.any((selected) => selected['email'] == user['email'])) {
        selectedUsers.removeWhere(
          (selected) => selected['email'] == user['email'],
        );
      } else {
        selectedUsers.add(user);
      }
    });
  }

  // =========================================================
  // CONNECT TO interstore DATABASE (FIXED)
  // =========================================================
  final FirebaseFirestore db = FirebaseFirestore.instanceFor(
    databaseId: 'interstore',
    app: Firebase.app(),
  );

  // =========================================================
  // DESIGN SYSTEM
  // =========================================================
  static const Color primaryDark = Color(0xFF1E3A5F);
  static const Color primaryMedium = Color(0xFF2E5A8C);
  static const Color successColor = Color(0xFF10B981);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color dangerColor = Color(0xFFEF4444);
  static const Color backgroundColor = Color(0xFFF8FAFC);
  static const Color cardBackground = Colors.white;
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);

  final stations = [
    'NIGER STATION',
    'MAIN STORE',
    'FLAMMABLE STORE',
    'AIRCRAFT STORE',
  ];

  final roles = ['admin', 'user', 'driver'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryDark,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'Users',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
      ),
      body: Column(
        children: <Widget>[
          // =========================================================
          // HERO HEADER
          // =========================================================
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
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "User Management",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),

                // SEARCH BOX
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    onChanged: (value) =>
                        setState(() => searchQuery = value.toLowerCase()),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Search users...",
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                      ),
                      prefixIcon: const Icon(Icons.search, color: Colors.white),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // =========================================================
          // USER MANAGEMENT TABS
          // =========================================================
          Expanded(
            child: Column(
              children: [
                // TAB BAR
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TabBar(
                    controller: _tabController,
                    labelColor: textSecondary,
                    unselectedLabelColor: textSecondary,
                    indicatorColor: primaryDark,
                    indicatorWeight: 3,
                    tabs: const [
                      Tab(icon: Icon(Icons.people), text: 'Existing Users'),
                      Tab(icon: Icon(Icons.person_add), text: 'Import Users'),
                      Tab(
                        icon: Icon(Icons.manage_accounts),
                        text: 'Manage Roles',
                      ),
                    ],
                  ),
                ),

                // TAB CONTENT
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // EXISTING USERS TAB
                      _buildExistingUsersTab(),
                      // IMPORT USERS TAB
                      _buildImportUsersTab(),
                      // MANAGE ROLES TAB
                      _buildManageRolesTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
