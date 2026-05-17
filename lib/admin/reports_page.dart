// ignore_for_file: unnecessary_to_list_in_spreads, deprecated_member_use

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../services/pdf_service.dart';
import '../services/email_service.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  DateTimeRange? selectedDateRange;
  String selectedReportType = 'transfer_status';
  List<Map<String, dynamic>> reportData = [];
  bool isLoading = false;

  // Firestore database instance
  final FirebaseFirestore db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'interstore',
  );

  // Consistent color palette
  static const Color primaryDark = Color(0xFF1E3A5F);
  static const Color accentColor = Color(0xFF4A90D9);
  static const Color successColor = Color(0xFF10B981);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color dangerColor = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    // Set default date range to last 30 days
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    selectedDateRange = DateTimeRange(start: thirtyDaysAgo, end: now);

    debugPrint(
      'Initialized date range: ${selectedDateRange!.start} - ${selectedDateRange!.end}',
    );
    debugPrint(
      'Date range duration: ${selectedDateRange!.duration.inDays} days',
    );

    // Load initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadReportData();
    });
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
          'Reports',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          _buildReportControls(),
          Expanded(child: _buildReportContent()),
        ],
      ),
    );
  }

  Widget _buildReportControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Report Type Selection
          Row(
            children: [
              Icon(Icons.analytics_outlined, color: primaryDark, size: 20),
              const SizedBox(width: 8),
              Text(
                'Report Type',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: primaryDark,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              DropdownButton<String>(
                value: selectedReportType,
                items: const [
                  DropdownMenuItem(
                    value: 'transfer_status',
                    child: Text('Transfer Status'),
                  ),
                  DropdownMenuItem(
                    value: 'completion_rate',
                    child: Text('Completion Rate'),
                  ),
                  DropdownMenuItem(
                    value: 'daily_summary',
                    child: Text('Daily Summary'),
                  ),
                  DropdownMenuItem(
                    value: 'monthly_summary',
                    child: Text('Monthly Summary'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    selectedReportType = value!;
                  });
                  _loadReportData();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Date Range Selection
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.date_range, color: primaryDark, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Date Range',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: primaryDark,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _selectDateRange,
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(
                        selectedDateRange != null
                            ? '${DateFormat('MMM dd').format(selectedDateRange!.start)} - ${DateFormat('MMM dd').format(selectedDateRange!.end)}'
                            : 'Select Range',
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryDark,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _loadReportData,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh Data',
                    style: IconButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Generate PDF Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _generatePDFReport,
              icon: const Icon(Icons.picture_as_pdf, size: 20),
              label: const Text('Generate PDF Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: successColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportContent() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (reportData.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Select report type and date range to view data',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildReportSummary(),
          const SizedBox(height: 16),
          _buildReportTable(),
        ],
      ),
    );
  }

  Widget _buildReportSummary() {
    switch (selectedReportType) {
      case 'transfer_status':
        return _buildTransferStatusSummary();
      case 'completion_rate':
        return _buildCompletionRateSummary();
      case 'daily_summary':
        return _buildDailySummary();
      case 'monthly_summary':
        return _buildMonthlySummary();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTransferStatusSummary() {
    final total = reportData.length;
    final completed = reportData
        .where((t) => t['status'] == 'completed')
        .length;
    final pending = reportData.where((t) => t['status'] == 'pending').length;
    final inTransit = reportData
        .where((t) => t['status'] == 'in_transit')
        .length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Transfer Status Summary',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryDark,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Total Transfers',
                    total.toString(),
                    Icons.inventory_2,
                    primaryDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    'Completed',
                    completed.toString(),
                    Icons.check_circle,
                    successColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Pending',
                    pending.toString(),
                    Icons.pending,
                    warningColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    'In Transit',
                    inTransit.toString(),
                    Icons.local_shipping,
                    accentColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionRateSummary() {
    if (reportData.isEmpty) return const SizedBox.shrink();

    final completionRate =
        (reportData.where((t) => t['status'] == 'completed').length /
            reportData.length) *
        100;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Completion Rate Analysis',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryDark,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: primaryDark.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    '${completionRate.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: primaryDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Overall Completion Rate',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailySummary() {
    // Group data by date
    final Map<String, List<Map<String, dynamic>>> dailyData = {};
    for (var item in reportData) {
      final date = DateFormat(
        'yyyy-MM-dd',
      ).format((item['createdAt'] as Timestamp).toDate());
      if (!dailyData.containsKey(date)) {
        dailyData[date] = [];
      }
      dailyData[date]!.add(item);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.today, color: primaryDark),
                    const SizedBox(width: 8),
                    Text(
                      'Daily Transfer Summary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primaryDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        'Total Days',
                        dailyData.length.toString(),
                        Icons.calendar_today,
                        primaryDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        'Total Transfers',
                        reportData.length.toString(),
                        Icons.inventory_2,
                        accentColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Daily Transfers List
        ...dailyData.entries.map((entry) {
          return _buildDailyTransferCard(entry.key, entry.value);
        }),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyTransferCard(
    String dateKey,
    List<Map<String, dynamic>> transfers,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Header
            Row(
              children: [
                Icon(Icons.date_range, color: primaryDark, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    DateFormat(
                      'EEEE, MMM dd, yyyy',
                    ).format(DateTime.parse(dateKey)),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: primaryDark,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${transfers.length} transfers',
                    style: TextStyle(
                      fontSize: 12,
                      color: accentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Transfer List
            ...transfers
                .map((transfer) => _buildTransferItem(transfer))
                .toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildTransferItem(Map<String, dynamic> transfer) {
    final status = transfer['status']?.toString() ?? 'pending';
    final statusColor = _getStatusColor(status);
    final statusIcon = _getStatusIcon(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Transfer Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(statusIcon, color: statusColor, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  transfer['transferNo']?.toString() ?? 'N/A',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              Text(
                DateFormat(
                  'HH:mm',
                ).format((transfer['createdAt'] as Timestamp).toDate()),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Transfer Details
          Row(
            children: [
              Icon(Icons.store, color: primaryDark, size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${transfer['fromStore']?.toString() ?? 'N/A'} → ${transfer['toStore']?.toString() ?? 'N/A'}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),

          if (transfer['assignedToName'] != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.person, color: accentColor, size: 16),
                const SizedBox(width: 4),
                Text(
                  'Driver: ${transfer['assignedToName']}',
                  style: TextStyle(
                    fontSize: 12,
                    color: accentColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],

          // Receiver Email
          if (transfer['receiverEmail'] != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.email, color: primaryDark, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Receiver: ${transfer['receiverEmail']}',
                    style: TextStyle(fontSize: 12, color: primaryDark),
                  ),
                ),
              ],
            ),
          ],

          // Receiver Information
          if (transfer['receivedBy'] != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.person_outline, color: successColor, size: 16),
                const SizedBox(width: 4),
                Text(
                  'Received by: ${transfer['receivedBy']}',
                  style: TextStyle(
                    fontSize: 12,
                    color: successColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],

          // Signature
          if (transfer['signature'] != null) ...[
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.draw, color: primaryDark, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Signature:',
                      style: TextStyle(
                        fontSize: 12,
                        color: primaryDark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  margin: const EdgeInsets.only(left: 20),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Display signature image
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.memory(
                          const Base64Decoder().convert(transfer['signature']),
                          height: 60,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 60,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.broken_image,
                                      color: Colors.grey[400],
                                      size: 20,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Signature unavailable',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      // Receiver info with signature
                      if (transfer['receiverName'] != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.person, color: successColor, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              'Signed by: ${transfer['receiverName']}',
                              style: TextStyle(
                                fontSize: 10,
                                color: successColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (transfer['receivedAt'] != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              color: Colors.grey[600],
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Signed at: ${DateFormat('MMM dd, HH:mm').format((transfer['receivedAt'] as Timestamp).toDate())}',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],

          // Parts/Items Details with Images
          if (transfer['items'] != null &&
              (transfer['items'] as List).isNotEmpty) ...[
            const SizedBox(height: 4),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.inventory_2, color: primaryDark, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Parts (${(transfer['items'] as List).length}):',
                      style: TextStyle(
                        fontSize: 12,
                        color: primaryDark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ...((transfer['items'] as List).take(3).map((item) {
                  final partName = item['descr']?.toString() ?? 'Unknown Part';
                  final partCode = item['code']?.toString() ?? '';
                  final quantity = item['qty']?.toString() ?? '1';
                  final imageUrl = item['imageUrl']?.toString();

                  return Container(
                    margin: const EdgeInsets.only(top: 4, left: 20),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Item Image
                        if (imageUrl != null && imageUrl.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.network(
                              imageUrl,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Icon(
                                    Icons.image_not_supported,
                                    size: 20,
                                  ),
                                );
                              },
                            ),
                          )
                        else
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Icon(Icons.inventory, size: 20),
                          ),

                        const SizedBox(width: 8),

                        // Part Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                partName,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (partCode.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Code: $partCode',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 2),
                              Text(
                                'Qty: $quantity',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: accentColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList()),

                if ((transfer['items'] as List).length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 20),
                    child: Text(
                      '... and ${(transfer['items'] as List).length - 3} more items',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return successColor;
      case 'in_transit':
        return warningColor;
      case 'pending':
        return Colors.grey;
      default:
        return dangerColor;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Icons.check_circle;
      case 'in_transit':
        return Icons.local_shipping;
      case 'pending':
        return Icons.pending;
      default:
        return Icons.help_outline;
    }
  }

  Widget _buildMonthlySummary() {
    // Group data by month
    final Map<String, List<Map<String, dynamic>>> monthlyData = {};
    for (var item in reportData) {
      final date = (item['createdAt'] as Timestamp).toDate();
      final monthKey = DateFormat('yyyy-MM').format(date);
      if (!monthlyData.containsKey(monthKey)) {
        monthlyData[monthKey] = [];
      }
      monthlyData[monthKey]!.add(item);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_month, color: primaryDark),
                    const SizedBox(width: 8),
                    Text(
                      'Monthly Transfer Summary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primaryDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        'Total Months',
                        monthlyData.length.toString(),
                        Icons.calendar_month,
                        primaryDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        'Total Transfers',
                        reportData.length.toString(),
                        Icons.inventory_2,
                        accentColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        'Completed',
                        reportData
                            .where((t) => t['status'] == 'completed')
                            .length
                            .toString(),
                        Icons.check_circle,
                        successColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        'Pending',
                        reportData
                            .where((t) => t['status'] == 'pending')
                            .length
                            .toString(),
                        Icons.pending,
                        Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Monthly Transfers List
        ...monthlyData.entries.map((entry) {
          return _buildMonthlyTransferCard(entry.key, entry.value);
        }),
      ],
    );
  }

  Widget _buildMonthlyTransferCard(
    String monthKey,
    List<Map<String, dynamic>> transfers,
  ) {
    final monthDate = DateTime.parse('$monthKey-01');
    final completed = transfers.where((t) => t['status'] == 'completed').length;
    final completionRate = transfers.isNotEmpty
        ? (completed / transfers.length * 100)
        : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month Header
            Row(
              children: [
                Icon(Icons.calendar_month, color: primaryDark, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    DateFormat('MMMM yyyy').format(monthDate),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: primaryDark,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${transfers.length} transfers',
                    style: TextStyle(
                      fontSize: 12,
                      color: accentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Monthly Stats
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: successColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          completed.toString(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: successColor,
                          ),
                        ),
                        Text(
                          'Completed',
                          style: TextStyle(fontSize: 10, color: successColor),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryDark.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${completionRate.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryDark,
                          ),
                        ),
                        Text(
                          'Completion Rate',
                          style: TextStyle(fontSize: 10, color: primaryDark),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Transfer List (show first 5, with option to expand)
            ...transfers
                .take(5)
                .map((transfer) => _buildTransferItem(transfer))
                .toList(),

            if (transfers.length > 5) ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  '... and ${transfers.length - 5} more transfers',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReportTable() {
    switch (selectedReportType) {
      case 'transfer_status':
        return _buildTransferStatusTable();
      case 'completion_rate':
        return _buildCompletionRateTable();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTransferStatusTable() {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Transfer Details',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: primaryDark,
              ),
            ),
          ),
          DataTable(
            columns: const [
              DataColumn(label: Text('Transfer #')),
              DataColumn(label: Text('From')),
              DataColumn(label: Text('To')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Date')),
              DataColumn(label: Text('Driver')),
              DataColumn(label: Text('Receiver Email')),
            ],
            rows: reportData.map((transfer) {
              return DataRow(
                cells: [
                  DataCell(Text(transfer['transferNo']?.toString() ?? '-')),
                  DataCell(Text(transfer['fromStore']?.toString() ?? '-')),
                  DataCell(Text(transfer['toStore']?.toString() ?? '-')),
                  DataCell(
                    _buildStatusChip(
                      transfer['status']?.toString() ?? 'pending',
                    ),
                  ),
                  DataCell(
                    Text(
                      transfer['createdAt'] != null
                          ? DateFormat('MMM dd, yyyy').format(
                              (transfer['createdAt'] as Timestamp).toDate(),
                            )
                          : '-',
                    ),
                  ),
                  DataCell(
                    Text(
                      transfer['assignedToName']?.toString() ?? 'Unassigned',
                    ),
                  ),
                  DataCell(Text(transfer['receiverEmail']?.toString() ?? '-')),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionRateTable() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Completion rate table will appear here...'),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color chipColor;
    IconData chipIcon;

    switch (status.toLowerCase()) {
      case 'completed':
        chipColor = successColor;
        chipIcon = Icons.check_circle;
        break;
      case 'pending':
        chipColor = warningColor;
        chipIcon = Icons.pending;
        break;
      case 'in_transit':
        chipColor = accentColor;
        chipIcon = Icons.local_shipping;
        break;
      default:
        chipColor = Colors.grey;
        chipIcon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(chipIcon, color: chipColor, size: 16),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              color: chipColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: selectedDateRange,
    );

    if (picked != null) {
      setState(() {
        selectedDateRange = picked;
      });
      _loadReportData();
    }
  }

  Future<void> _generatePDFReport() async {
    // Check if data is available
    if (reportData.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white),
                SizedBox(width: 12),
                Text(
                  'No data available for the selected date range. Try selecting a different date range or refresh the data.',
                ),
              ],
            ),
            backgroundColor: warningColor,
            duration: Duration(seconds: 5),
          ),
        );
      }
      return;
    }

    // Show loading indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 12),
              Text('Generating PDF...'),
            ],
          ),
          backgroundColor: primaryDark,
          duration: Duration(seconds: 2),
        ),
      );
    }

    try {
      Uint8List? pdfBytes;
      String fileName = '';

      debugPrint('Generating PDF for report type: $selectedReportType');
      debugPrint('Report data count: ${reportData.length}');
      debugPrint(
        'Date range: ${selectedDateRange?.start} - ${selectedDateRange?.end}',
      );

      // Fetch logo for reports
      EmailService.clearLogoCache(); // Clear cache to ensure fresh logo with correct encoding
      final logoBase64 = await EmailService.getLogoBase64();
      debugPrint('Logo fetched: ${logoBase64 != null ? 'Yes' : 'No'}');

      // Generate PDF based on report type
      switch (selectedReportType) {
        case 'transfer_status':
          pdfBytes = await PDFService.generateTransferStatusReportBytes(
            reportData: reportData,
            dateRange: selectedDateRange!,
            companyName: '748 Store System',
            logoBase64: logoBase64,
          );
          fileName =
              'transfer_status_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
          break;
        case 'completion_rate':
          pdfBytes = await PDFService.generateCompletionRateReportBytes(
            reportData: reportData,
            dateRange: selectedDateRange!,
            companyName: '748 Store System',
            logoBase64: logoBase64,
          );
          fileName =
              'completion_rate_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
          break;
        case 'daily_summary':
          pdfBytes = await PDFService.generateDailySummaryReportBytes(
            reportData: reportData,
            dateRange: selectedDateRange!,
            companyName: '748 Store System',
            logoBase64: logoBase64,
          );
          fileName =
              'daily_summary_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
          break;
        case 'monthly_summary':
          pdfBytes = await PDFService.generateMonthlySummaryReportBytes(
            reportData: reportData,
            dateRange: selectedDateRange!,
            companyName: '748 Store System',
            logoBase64: logoBase64,
          );
          fileName =
              'monthly_summary_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
          break;
        default:
          throw Exception('Unknown report type: $selectedReportType');
      }

      debugPrint('PDF generated successfully, size: ${pdfBytes?.length} bytes');

      if (pdfBytes != null && mounted) {
        // Show options dialog
        _showPDFOptionsDialog(pdfBytes, fileName);
      } else {
        throw Exception('PDF generation returned null');
      }
    } catch (e) {
      debugPrint('Error generating PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Error generating PDF: $e',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
            backgroundColor: dangerColor,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _showPDFOptionsDialog(Uint8List pdfBytes, String fileName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('PDF Generated Successfully!'),
          content: const Text('What would you like to do with the PDF?'),
          actions: [
            if (!kIsWeb) ...[
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _printPDF(pdfBytes, fileName);
                },
                child: const Text('Print'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _savePDF(pdfBytes, fileName);
                },
                child: const Text('Save to Phone'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _sharePDF(pdfBytes, fileName);
                },
                child: const Text('Share'),
              ),
            ],
            if (kIsWeb) ...[
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _downloadPDF(pdfBytes, fileName);
                },
                child: const Text('Download to Computer'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _savePDFWeb(pdfBytes, fileName);
                },
                child: const Text('Save to Phone'),
              ),
            ],
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _printPDF(Uint8List pdfBytes, String fileName) async {
    try {
      await Printing.layoutPdf(
        name: fileName,
        onLayout: (PdfPageFormat format) async => pdfBytes,
      );
    } catch (e) {
      debugPrint('Print PDF error: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error printing PDF: $e'),
            backgroundColor: dangerColor,
          ),
        );
      }
    }
  }

  Future<void> _savePDF(Uint8List pdfBytes, String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();

      final file = File('${directory.path}/$fileName');

      await file.writeAsBytes(pdfBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF saved successfully:\n${file.path}'),
            backgroundColor: successColor,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint('Save PDF error: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving PDF: $e'),
            backgroundColor: dangerColor,
          ),
        );
      }
    }
  }

  Future<void> _sharePDF(Uint8List pdfBytes, String fileName) async {
    try {
      final directory = await getTemporaryDirectory();

      final file = File('${directory.path}/$fileName');

      await file.writeAsBytes(pdfBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: '748 Store System Report',
        subject: fileName,
      );
    } catch (e) {
      debugPrint('Share PDF error: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing PDF: $e'),
            backgroundColor: dangerColor,
          ),
        );
      }
    }
  }

  Future<void> _loadReportData() async {
    if (selectedDateRange == null) {
      debugPrint('No date range selected, skipping data load');
      return;
    }

    debugPrint(
      'Loading report data for range: ${selectedDateRange!.start} - ${selectedDateRange!.end}',
    );
    setState(() => isLoading = true);

    try {
      final start = selectedDateRange!.start;
      final end = selectedDateRange!.end;
      final List<Map<String, dynamic>> allTransfers = [];
      final Set<String> emailsToLookup = {};

      debugPrint('Querying Firestore for transfers between $start and $end');

      // Iterate through each day in the date range
      DateTime currentDate = start;
      while (currentDate.isBefore(end) || currentDate.isAtSameMomentAs(end)) {
        final year = currentDate.year.toString();
        final dayKey =
            "${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}";

        debugPrint('Querying year: $year, dayKey: $dayKey');

        try {
          final collectionRef = db
              .collection('transfers')
              .doc(year)
              .collection(dayKey);

          debugPrint('Collection path: transfers/$year/$dayKey');

          final daySnapshot = await collectionRef.get();

          debugPrint('Found ${daySnapshot.docs.length} transfers for $dayKey');

          for (final doc in daySnapshot.docs) {
            final data = doc.data() as Map<String, dynamic>?;
            debugPrint(
              'Processing transfer: ${doc.id} - ${data?['transferNo']}',
            );
            final receiverEmail = data?['receiverEmail']?.toString() ?? '';
            if (receiverEmail.isNotEmpty) {
              emailsToLookup.add(receiverEmail);
            }
            allTransfers.add({
              'id': doc.id,
              'transferNo': data?['transferNo'] ?? '',
              'fromStore': data?['fromStore'] ?? '',
              'toStore': data?['toStore'] ?? '',
              'status': data?['status'] ?? 'pending',
              'createdAt': data?['createdAt'],
              'assignedTo': data?['assignedTo'],
              'assignedToName': data?['assignedToName'],
              'assignedAt': data?['assignedAt'],
              'assignmentStatus': data?['assignmentStatus'],
              'receiverEmail': receiverEmail,
              'year': year,
              'dayKey': dayKey,
              'items': data?['items'] ?? [],
            });
          }

          if (daySnapshot.docs.isEmpty) {
            debugPrint(
              'No documents found in collection transfers/$year/$dayKey',
            );
          }
        } catch (e) {
          debugPrint('Error querying $year/$dayKey: $e');
          debugPrint('Collection path attempted: transfers/$year/$dayKey');
          // Continue to next day even if current day doesn't exist
        }

        currentDate = currentDate.add(const Duration(days: 1));
      }

      debugPrint('Total transfers loaded: ${allTransfers.length}');
      debugPrint('Unique emails to lookup: ${emailsToLookup.length}');

      // Fetch user names for all receiver emails
      final Map<String, String> emailToName = {};
      for (final email in emailsToLookup) {
        try {
          final userSnapshot = await db
              .collection('users')
              .where('email', isEqualTo: email)
              .limit(1)
              .get();

          if (userSnapshot.docs.isNotEmpty) {
            final userData = userSnapshot.docs.first.data();
            final name =
                userData['name']?.toString() ??
                userData['displayName']?.toString() ??
                '';
            if (name.isNotEmpty) {
              emailToName[email] = name;
              debugPrint('Found name for $email: $name');
            }
          }
        } catch (e) {
          debugPrint('Error fetching user for email $email: $e');
        }
      }

      // Update transfers with fetched user names
      for (final transfer in allTransfers) {
        final email = transfer['receiverEmail']?.toString() ?? '';
        if (email.isNotEmpty && emailToName.containsKey(email)) {
          transfer['receiverUserName'] = emailToName[email];
        }
      }

      setState(() {
        reportData = allTransfers;
        isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text('Loaded ${allTransfers.length} transfers'),
              ],
            ),
            backgroundColor: successColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error loading report data: $e');
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading report data: $e'),
            backgroundColor: dangerColor,
          ),
        );
      }
    }
  }

  Future<void> _downloadPDF(Uint8List pdfBytes, String fileName) async {
    try {
      if (kIsWeb) {
        // Use the PDF service download method for web
        await PDFService.downloadPDFWeb(pdfBytes, fileName);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.download, color: Colors.white),
                  SizedBox(width: 12),
                  Text('PDF downloaded successfully!'),
                ],
              ),
              backgroundColor: successColor,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error downloading PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Error downloading PDF: $e',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
            backgroundColor: dangerColor,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _savePDFWeb(Uint8List pdfBytes, String fileName) async {
    try {
      if (kIsWeb) {
        // For web, "Save to Phone" also uses download but with different messaging
        // In reality, both options do the same thing on web (download to device)
        await PDFService.downloadPDFWeb(pdfBytes, fileName);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.phone_android, color: Colors.white),
                  SizedBox(width: 12),
                  Text('PDF saved! Check your device downloads.'),
                ],
              ),
              backgroundColor: successColor,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error saving PDF on web: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Error saving PDF: $e',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
            backgroundColor: dangerColor,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}
