// ignore_for_file: deprecated_member_use, unnecessary_to_list_in_spreads

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
// ignore: depend_on_referenced_packages
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:cloud_firestore/cloud_firestore.dart';

/// Professional PDF Service for 748 Store System
/// Generates modern, enterprise-grade reports with consistent styling
class PDFService {
  // =====================================================
  // MODERN COLOR PALETTE
  // =====================================================
  static const Color primaryDark = Color(0xFF0F172A); // Slate 900
  static const Color primaryColor = Color(0xFF1E3A5F); // Deep Navy
  static const Color accentColor = Color(0xFF3B82F6); // Blue 500
  static const Color successColor = Color(0xFF10B981); // Emerald 500
  static const Color warningColor = Color(0xFFF59E0B); // Amber 500
  static const Color dangerColor = Color(0xFFEF4444); // Red 500
  static const Color infoColor = Color(0xFF06B6D4); // Cyan 500
  static const Color surfaceColor = Color(0xFFF8FAFC); // Slate 50
  static const Color textPrimary = Color(0xFF1E293B); // Slate 800
  static const Color textSecondary = Color(0xFF64748B); // Slate 500

  // PDF Color helpers
  static PdfColor get _pdfPrimary => PdfColor.fromInt(primaryDark.value);
  static PdfColor get _pdfAccent => PdfColor.fromInt(accentColor.value);
  static PdfColor get _pdfSuccess => PdfColor.fromInt(successColor.value);
  static PdfColor get _pdfWarning => PdfColor.fromInt(warningColor.value);
  static PdfColor get _pdfDanger => PdfColor.fromInt(dangerColor.value);
  static PdfColor get _pdfInfo => PdfColor.fromInt(infoColor.value);
  static PdfColor get _pdfSurface => PdfColor.fromInt(surfaceColor.value);
  static PdfColor get _pdfTextPrimary => PdfColor.fromInt(textPrimary.value);
  static PdfColor get _pdfTextSecondary =>
      PdfColor.fromInt(textSecondary.value);

  // Helper to create PdfColor with opacity from Flutter Color
  static PdfColor _pdfColorWithOpacity(Color color, double opacity) {
    return PdfColor(
      color.red / 255,
      color.green / 255,
      color.blue / 255,
      opacity,
    );
  }

  // =====================================================
  // FONT MANAGEMENT
  // =====================================================

  static pw.Font? _cachedFont;

  static Future<pw.Font> get _customFont async {
    if (_cachedFont != null) return _cachedFont!;
    try {
      _cachedFont = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
      );
      return _cachedFont!;
    } catch (e) {
      debugPrint('Font loading failed, using fallback: $e');
      // Fallback to built-in Helvetica if custom font fails
      _cachedFont = pw.Font.helvetica();
      return _cachedFont!;
    }
  }

  // =====================================================
  // STATUS COLOR MAPPING
  // =====================================================

  static PdfColor _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'complete':
      case 'done':
        return _pdfSuccess;
      case 'pending':
      case 'waiting':
      case 'on_hold':
        return _pdfWarning;
      case 'in_transit':
      case 'intransit':
      case 'shipping':
      case 'shipped':
        return _pdfInfo;
      case 'cancelled':
      case 'canceled':
      case 'failed':
      case 'rejected':
        return _pdfDanger;
      default:
        return PdfColors.grey600;
    }
  }

  static String _formatStatus(String status) {
    return status
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (word) => word.isNotEmpty
              ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
              : '',
        )
        .join(' ');
  }

  static PdfColor _applyOpacity(PdfColor color, double opacity) {
    return PdfColor(
      color.red * opacity,
      color.green * opacity,
      color.blue * opacity,
    );
  }

  // =====================================================
  // LOGO HANDLING
  // =====================================================

  static pw.Widget? _buildLogo(String? logoBase64) {
    if (logoBase64 == null || logoBase64.isEmpty) return null;

    try {
      final base64Data = logoBase64.contains(',')
          ? logoBase64.split(',').last
          : logoBase64;

      // Validate base64
      if (base64Data.isEmpty) return null;
      base64Decode(base64Data); // Will throw if invalid

      return pw.Container(
        height: 50,
        width: 50,
        child: pw.Image(
          pw.MemoryImage(base64Decode(base64Data)),
          fit: pw.BoxFit.contain,
        ),
      );
    } catch (e) {
      debugPrint('Logo decode error: $e');
      return null;
    }
  }

  // =====================================================
  // MODERN HEADER BUILDER
  // =====================================================

  static pw.Widget _buildModernHeader(
    pw.Font font,
    String companyName,
    String title,
    DateTimeRange dateRange,
    String? logoBase64, {
    String? subtitle,
  }) {
    final logo = _buildLogo(logoBase64);

    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 16),
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _pdfAccent, width: 2)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Top row: Logo + Company + Meta
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (logo != null) ...[logo, pw.SizedBox(width: 16)],
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      companyName,
                      style: pw.TextStyle(
                        font: font,
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: _pdfPrimary,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      title,
                      style: pw.TextStyle(
                        font: font,
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: _pdfAccent,
                      ),
                    ),
                    if (subtitle != null) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        subtitle,
                        style: pw.TextStyle(
                          font: font,
                          fontSize: 11,
                          color: _pdfTextSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: pw.BoxDecoration(
                      color: _pdfSurface,
                      borderRadius: pw.BorderRadius.circular(6),
                      border: pw.Border.all(color: PdfColors.grey300),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Period',
                          style: pw.TextStyle(
                            font: font,
                            fontSize: 9,
                            color: _pdfTextSecondary,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          '${DateFormat('MMM dd, yyyy').format(dateRange.start)} - ${DateFormat('MMM dd, yyyy').format(dateRange.end)}',
                          style: pw.TextStyle(
                            font: font,
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: _pdfTextPrimary,
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text(
                          'Generated',
                          style: pw.TextStyle(
                            font: font,
                            fontSize: 9,
                            color: _pdfTextSecondary,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          DateFormat(
                            'MMM dd, yyyy • HH:mm',
                          ).format(DateTime.now()),
                          style: pw.TextStyle(
                            font: font,
                            fontSize: 10,
                            color: _pdfTextPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =====================================================
  // MODERN STATISTICS CARDS
  // =====================================================

  static pw.Widget _buildStatisticsRow(
    pw.Font font,
    List<Map<String, dynamic>> reportData,
  ) {
    final total = reportData.length;
    final completed = reportData
        .where((e) => e['status']?.toString().toLowerCase() == 'completed')
        .length;
    final pending = reportData
        .where((e) => e['status']?.toString().toLowerCase() == 'pending')
        .length;
    final inTransit = reportData
        .where((e) => e['status']?.toString().toLowerCase() == 'in_transit')
        .length;
    final cancelled = reportData.where((e) {
      final s = e['status']?.toString().toLowerCase() ?? '';
      return s == 'cancelled' || s == 'canceled' || s == 'failed';
    }).length;

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 20),
      child: pw.Row(
        children: [
          _buildStatCard(
            font,
            'Total',
            total.toString(),
            _pdfPrimary,
            icon: '∑',
          ),
          pw.SizedBox(width: 8),
          _buildStatCard(
            font,
            'Completed',
            completed.toString(),
            _pdfSuccess,
            icon: '✓',
          ),
          pw.SizedBox(width: 8),
          _buildStatCard(
            font,
            'Pending',
            pending.toString(),
            _pdfWarning,
            icon: '◷',
          ),
          pw.SizedBox(width: 8),
          _buildStatCard(
            font,
            'In Transit',
            inTransit.toString(),
            _pdfInfo,
            icon: '➤',
          ),
          if (cancelled > 0) ...[
            pw.SizedBox(width: 8),
            _buildStatCard(
              font,
              'Cancelled',
              cancelled.toString(),
              _pdfDanger,
              icon: '✕',
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _buildStatCard(
    pw.Font font,
    String label,
    String value,
    PdfColor color, {
    String icon = '',
  }) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: PdfColors.grey200),
          boxShadow: [
            pw.BoxShadow(
              color: PdfColors.grey100,
              blurRadius: 4,
              offset: const PdfPoint(0, 2),
            ),
          ],
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              children: [
                pw.Container(
                  width: 8,
                  height: 8,
                  decoration: pw.BoxDecoration(
                    color: color,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                ),
                pw.SizedBox(width: 6),
                pw.Text(
                  label,
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 9,
                    color: _pdfTextSecondary,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              value,
              style: pw.TextStyle(
                font: font,
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // COMPLETION RATE BANNER
  // =====================================================

  static pw.Widget _buildCompletionRateBanner(
    pw.Font font,
    List<Map<String, dynamic>> reportData,
  ) {
    final total = reportData.length;
    final completed = reportData
        .where((e) => e['status']?.toString().toLowerCase() == 'completed')
        .length;
    final rate = total > 0 ? (completed / total * 100) : 0.0;

    PdfColor bannerColor;
    if (rate >= 80) {
      bannerColor = _pdfSuccess;
    } else if (rate >= 50) {
      bannerColor = _pdfWarning;
    } else {
      bannerColor = _pdfDanger;
    }

    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 20),
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: bannerColor,
        borderRadius: pw.BorderRadius.circular(12),
        gradient: pw.LinearGradient(
          colors: [bannerColor, bannerColor.shade(.8)],
          begin: pw.Alignment.topLeft,
          end: pw.Alignment.bottomRight,
        ),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Overall Completion Rate',
                  style: pw.TextStyle(
                    font: font,
                    color: PdfColors.white,
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  '$completed of $total transfers completed',
                  style: pw.TextStyle(
                    font: font,
                    color: _applyOpacity(PdfColors.white, .8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          pw.Text(
            '${rate.toStringAsFixed(1)}%',
            style: pw.TextStyle(
              font: font,
              color: PdfColors.white,
              fontSize: 36,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // MODERN DATA TABLE
  // =====================================================

  static pw.Widget _buildTransferTable(
    pw.Font font,
    List<Map<String, dynamic>> transfers,
  ) {
    return pw.Table(
      columnWidths: {
        0: const pw.FlexColumnWidth(1.5), // Transfer No
        1: const pw.FlexColumnWidth(2.2), // Route
        2: const pw.FlexColumnWidth(1.4), // Driver
        3: const pw.FlexColumnWidth(1.2), // Status
        4: const pw.FlexColumnWidth(2.8), // Products
        5: const pw.FlexColumnWidth(0.8), // Qty
        6: const pw.FlexColumnWidth(2), // Received By
        7: const pw.FlexColumnWidth(1.5), // Date
      },
      border: pw.TableBorder(
        horizontalInside: pw.BorderSide(color: PdfColors.grey100, width: .5),
      ),
      children: [
        // Header Row
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: _pdfPrimary,
            borderRadius: const pw.BorderRadius.vertical(
              top: pw.Radius.circular(8),
            ),
          ),
          children: [
            _buildTableHeaderCell(font, 'Transfer #'),
            _buildTableHeaderCell(font, 'Route'),
            _buildTableHeaderCell(font, 'Assigned To'),
            _buildTableHeaderCell(font, 'Status'),
            _buildTableHeaderCell(font, 'Products'),
            _buildTableHeaderCell(font, 'Qty', align: pw.TextAlign.right),
            _buildTableHeaderCell(font, 'Received By'),
            _buildTableHeaderCell(font, 'Date', align: pw.TextAlign.right),
          ],
        ),
        // Data Rows
        ...transfers.asMap().entries.map((entry) {
          final index = entry.key;
          final transfer = entry.value;
          final isEven = index % 2 == 0;
          final createdAt = transfer['createdAt'] is Timestamp
              ? (transfer['createdAt'] as Timestamp).toDate()
              : null;
          final status = transfer['status']?.toString() ?? 'pending';
          final items = transfer['items'] as List? ?? [];

          // Group items by description and sum quantities
          final groupedItems = <String, int>{};
          for (final item in items) {
            final name = item['descr']?.toString() ?? '';
            final qty = item['qty'] as int? ?? 0;
            if (name.isNotEmpty) {
              groupedItems[name] = (groupedItems[name] ?? 0) + qty;
            }
          }

          final productSummary = groupedItems.entries
              .map((e) => '${e.key} (${e.value})')
              .take(2)
              .join(', ');
          final totalQty = groupedItems.values.fold<int>(
            0,
            // ignore: avoid_types_as_parameter_names
            (sum, qty) => sum + qty,
          );

          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: isEven ? PdfColors.white : _pdfSurface,
            ),
            children: [
              _buildTableCell(
                font,
                transfer['transferNo']?.toString() ?? 'N/A',
                bold: true,
              ),
              _buildTableCell(
                font,
                '${transfer['fromStore'] ?? '-'} - ${transfer['toStore'] ?? '-'}',
              ),
              _buildTableCell(
                font,
                transfer['assignedToName']?.toString() ?? 'Unassigned',
              ),
              _buildStatusCell(font, status),
              _buildTableCell(
                font,
                productSummary.isEmpty
                    ? '-'
                    : '$productSummary${groupedItems.length > 2 ? '...' : ''}',
              ),
              _buildTableCell(
                font,
                totalQty.toString(),
                align: pw.TextAlign.right,
                bold: true,
              ),
              _buildTableCell(font, () {
                final userName = transfer['receiverUserName']?.toString() ?? '';
                final email =
                    transfer['receiverEmail']?.toString() ??
                    transfer['receivedBy']?.toString() ??
                    '';
                if (userName.isNotEmpty && email.isNotEmpty) {
                  return '$userName\n$email';
                } else if (userName.isNotEmpty) {
                  return userName;
                } else if (email.isNotEmpty) {
                  return email;
                } else {
                  return '-';
                }
              }()),
              _buildTableCell(
                font,
                createdAt != null
                    ? DateFormat('MMM dd, yyyy').format(createdAt)
                    : '-',
                align: pw.TextAlign.right,
                color: _pdfTextSecondary,
              ),
            ],
          );
        }).toList(),
      ],
    );
  }

  static pw.Widget _buildTableHeaderCell(
    pw.Font font,
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
        textAlign: align,
      ),
    );
  }

  static pw.Widget _buildTableCell(
    pw.Font font,
    String text, {
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.left,
    PdfColor? color,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? _pdfTextPrimary,
        ),
        textAlign: align,
      ),
    );
  }

  static pw.Widget _buildStatusCell(pw.Font font, String status) {
    final color = _getStatusColor(status);
    final formattedStatus = _formatStatus(status);

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: pw.Text(
        formattedStatus,
        style: pw.TextStyle(
          font: font,
          fontSize: 8,
          color: color,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  // =====================================================
  // DETAILED TRANSFER CARD (for expanded views)
  // =====================================================

  static pw.Widget _buildDetailedTransferCard(
    pw.Font font,
    Map<String, dynamic> transfer,
  ) {
    final createdAt = transfer['createdAt'] is Timestamp
        ? (transfer['createdAt'] as Timestamp).toDate()
        : null;
    final status = transfer['status']?.toString() ?? 'pending';
    final items = transfer['items'] as List? ?? [];

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: PdfColors.grey200),
        boxShadow: [
          pw.BoxShadow(
            color: PdfColors.grey100,
            blurRadius: 4,
            offset: const PdfPoint(0, 2),
          ),
        ],
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header row
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    transfer['transferNo']?.toString() ?? 'N/A',
                    style: pw.TextStyle(
                      font: font,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 13,
                      color: _pdfPrimary,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    '${transfer['fromStore'] ?? '-'} - ${transfer['toStore'] ?? '-'}',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 11,
                      color: _pdfTextSecondary,
                    ),
                  ),
                ],
              ),
              _buildModernStatusBadge(font, status),
            ],
          ),

          pw.Divider(color: PdfColors.grey100, height: 16),

          // Details grid
          pw.Row(
            children: [
              _buildDetailItem(
                font,
                'Driver',
                transfer['assignedToName']?.toString() ?? 'Unassigned',
              ),
              pw.SizedBox(width: 40),
              if (transfer['receiverEmail'] != null)
                _buildDetailItem(
                  font,
                  'Receiver',
                  transfer['receiverEmail'].toString(),
                ),
              pw.SizedBox(width: 40),
              if (createdAt != null)
                _buildDetailItem(
                  font,
                  'Date',
                  DateFormat(
                    '"'
                    "'MMM dd, yyyy HH:mm'"
                    '"',
                  ).format(createdAt),
                ),
            ],
          ),

          // Items section
          if (items.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: _pdfSurface,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Items (${items.length})',
                    style: pw.TextStyle(
                      font: font,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 10,
                      color: _pdfTextPrimary,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  ...items.take(15).map((item) {
                    return pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 3),
                      child: pw.Row(
                        children: [
                          pw.Container(
                            width: 4,
                            height: 4,
                            margin: const pw.EdgeInsets.only(right: 8),
                            decoration: pw.BoxDecoration(
                              color: _pdfAccent,
                              borderRadius: pw.BorderRadius.circular(2),
                            ),
                          ),
                          pw.Expanded(
                            child: pw.Text(
                              item['descr']?.toString() ?? 'Unknown Item',
                              style: pw.TextStyle(
                                font: font,
                                fontSize: 9,
                                color: _pdfTextSecondary,
                              ),
                            ),
                          ),
                          if (item['quantity'] != null)
                            pw.Text(
                              'Qty: ${item['quantity']}',
                              style: pw.TextStyle(
                                font: font,
                                fontSize: 9,
                                color: _pdfTextSecondary,
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                  if (items.length > 15)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 4),
                      child: pw.Text(
                        '+ ${items.length - 15} more items...',
                        style: pw.TextStyle(
                          font: font,
                          fontSize: 9,
                          color: _pdfTextSecondary,
                          fontStyle: pw.FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _buildDetailItem(pw.Font font, String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            font: font,
            fontSize: 8,
            color: _pdfTextSecondary,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(
            font: font,
            fontSize: 10,
            color: _pdfTextPrimary,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildModernStatusBadge(pw.Font font, String status) {
    final color = _getStatusColor(status);
    final formattedStatus = _formatStatus(status);

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: pw.BoxDecoration(
        color: _applyOpacity(color, .15),
        borderRadius: pw.BorderRadius.circular(20),
      ),
      child: pw.Text(
        formattedStatus,
        style: pw.TextStyle(
          font: font,
          fontSize: 9,
          color: color,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  // =====================================================
  // EMPTY STATE
  // =====================================================

  static pw.Widget _buildModernEmptyState(pw.Font font) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(30),
      decoration: pw.BoxDecoration(
        color: _pdfSurface,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: PdfColors.grey200),
      ),
      child: pw.Column(
        children: [
          pw.Text('📊', style: pw.TextStyle(font: font, fontSize: 32)),
          pw.SizedBox(height: 12),
          pw.Text(
            'No Data Available',
            style: pw.TextStyle(
              font: font,
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: _pdfTextPrimary,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'No transfer records found for the selected period.',
            style: pw.TextStyle(
              font: font,
              fontSize: 11,
              color: _pdfTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // FOOTER WITH PAGE NUMBERS
  // =====================================================

  static pw.Widget _buildModernFooter(pw.Font font, {int? page, int? total}) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey300, width: 1),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            '748 Store System • Confidential Report',
            style: pw.TextStyle(
              font: font,
              fontSize: 9,
              color: _pdfTextSecondary,
            ),
          ),
          if (page != null && total != null)
            pw.Text(
              'Page $page of $total',
              style: pw.TextStyle(
                font: font,
                fontSize: 9,
                color: _pdfTextSecondary,
              ),
            ),
        ],
      ),
    );
  }

  // =====================================================
  // DATA GROUPING HELPERS
  // =====================================================

  static Map<String, List<Map<String, dynamic>>> _groupByMonth(
    List<Map<String, dynamic>> data,
  ) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final transfer in data) {
      final createdAt = transfer['createdAt'];
      if (createdAt == null || createdAt is! Timestamp) continue;
      final date = createdAt.toDate();
      final monthKey = DateFormat('yyyy-MM').format(date);
      grouped.putIfAbsent(monthKey, () => []);
      grouped[monthKey]!.add(transfer);
    }
    // Sort by month key descending
    return Map.fromEntries(
      grouped.entries.toList()..sort((a, b) => b.key.compareTo(a.key)),
    );
  }

  static Map<String, List<Map<String, dynamic>>> _groupByDay(
    List<Map<String, dynamic>> data,
  ) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final transfer in data) {
      final createdAt = transfer['createdAt'];
      if (createdAt == null || createdAt is! Timestamp) continue;
      final date = createdAt.toDate();
      final dayKey = DateFormat('yyyy-MM-dd').format(date);
      grouped.putIfAbsent(dayKey, () => []);
      grouped[dayKey]!.add(transfer);
    }
    // Sort by day key descending
    return Map.fromEntries(
      grouped.entries.toList()..sort((a, b) => b.key.compareTo(a.key)),
    );
  }

  // =====================================================
  // MONTHLY SUMMARY REPORT
  // =====================================================

  static Future<Uint8List?> generateMonthlySummaryReportBytes({
    required List<Map<String, dynamic>> reportData,
    required DateTimeRange dateRange,
    String? companyName,
    String? logoBase64,
  }) async {
    try {
      debugPrint('📄 Starting Monthly Summary Report...');
      debugPrint('   Records: ${reportData.length}');

      final pdf = pw.Document();
      final font = await _customFont;
      final groupedData = _groupByMonth(reportData);

      debugPrint('   Grouped into ${groupedData.length} months');

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(28),
          header: (context) => _buildModernHeader(
            font,
            companyName ?? '748 Store System',
            'Monthly Summary Report',
            dateRange,
            logoBase64,
            subtitle: 'Transfer activity grouped by month',
          ),
          footer: (context) => _buildModernFooter(
            font,
            page: context.pageNumber,
            total: context.pagesCount,
          ),
          build: (context) {
            return [
              pw.SizedBox(height: 16),

              if (reportData.isEmpty)
                _buildModernEmptyState(font)
              else ...[
                _buildStatisticsRow(font, reportData),

                pw.SizedBox(height: 8),

                ...groupedData.entries.expand((entry) {
                  return [
                    _buildTransferTable(font, entry.value),
                    pw.SizedBox(height: 16),
                  ];
                }).toList(),
              ],
            ];
          },
        ),
      );

      final bytes = await pdf.save();
      debugPrint('✅ Monthly Report generated: ${bytes.length} bytes');
      return bytes;
    } catch (e, stackTrace) {
      debugPrint('❌ Monthly Report Error: $e');
      debugPrint(stackTrace.toString());
      return null;
    }
  }

  // =====================================================
  // DAILY SUMMARY REPORT
  // =====================================================

  static Future<Uint8List?> generateDailySummaryReportBytes({
    required List<Map<String, dynamic>> reportData,
    required DateTimeRange dateRange,
    required String companyName,
    String? logoBase64,
  }) async {
    try {
      debugPrint('📄 Starting Daily Summary Report...');

      final pdf = pw.Document();
      final font = await _customFont;
      final groupedData = _groupByDay(reportData);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(28),
          header: (context) => _buildModernHeader(
            font,
            companyName,
            'Daily Summary Report',
            dateRange,
            logoBase64,
            subtitle: 'Transfer activity grouped by day',
          ),
          footer: (context) => _buildModernFooter(
            font,
            page: context.pageNumber,
            total: context.pagesCount,
          ),
          build: (context) {
            return [
              pw.SizedBox(height: 16),

              if (reportData.isEmpty)
                _buildModernEmptyState(font)
              else ...[
                _buildStatisticsRow(font, reportData),

                pw.SizedBox(height: 8),

                ...groupedData.entries.expand((entry) {
                  return [
                    _buildTransferTable(font, entry.value),
                    pw.SizedBox(height: 16),
                  ];
                }).toList(),
              ],
            ];
          },
        ),
      );

      final bytes = await pdf.save();
      debugPrint('✅ Daily Report generated: ${bytes.length} bytes');
      return bytes;
    } catch (e, stackTrace) {
      debugPrint('❌ Daily Report Error: $e');
      debugPrint(stackTrace.toString());
      return null;
    }
  }

  // =====================================================
  // TRANSFER STATUS REPORT
  // =====================================================

  static Future<Uint8List?> generateTransferStatusReportBytes({
    required List<Map<String, dynamic>> reportData,
    required DateTimeRange dateRange,
    required String companyName,
    String? logoBase64,
  }) async {
    try {
      debugPrint('📄 Starting Transfer Status Report...');

      final pdf = pw.Document();
      final font = await _customFont;
      final groupedData = _groupByMonth(reportData);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(28),
          header: (context) => _buildModernHeader(
            font,
            companyName,
            'Transfer Status Report',
            dateRange,
            logoBase64,
            subtitle: 'Detailed transfer status tracking',
          ),
          footer: (context) => _buildModernFooter(
            font,
            page: context.pageNumber,
            total: context.pagesCount,
          ),
          build: (context) {
            return [
              pw.SizedBox(height: 16),

              if (reportData.isEmpty)
                _buildModernEmptyState(font)
              else ...[
                _buildStatisticsRow(font, reportData),

                pw.SizedBox(height: 8),

                ...groupedData.entries.expand((entry) {
                  return [
                    ...entry.value.map(
                      (transfer) => _buildDetailedTransferCard(font, transfer),
                    ),
                    pw.SizedBox(height: 8),
                  ];
                }).toList(),
              ],
            ];
          },
        ),
      );

      final bytes = await pdf.save();
      debugPrint('✅ Status Report generated: ${bytes.length} bytes');
      return bytes;
    } catch (e, stackTrace) {
      debugPrint('❌ Status Report Error: $e');
      debugPrint(stackTrace.toString());
      return null;
    }
  }

  // =====================================================
  // COMPLETION RATE REPORT
  // =====================================================

  static Future<Uint8List?> generateCompletionRateReportBytes({
    required List<Map<String, dynamic>> reportData,
    required DateTimeRange dateRange,
    required String companyName,
    String? logoBase64,
  }) async {
    try {
      debugPrint('📄 Starting Completion Rate Report...');

      final pdf = pw.Document();
      final font = await _customFont;
      final groupedData = _groupByMonth(reportData);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(28),
          header: (context) => _buildModernHeader(
            font,
            companyName,
            'Completion Rate Report',
            dateRange,
            logoBase64,
            subtitle: 'Performance analysis and completion metrics',
          ),
          footer: (context) => _buildModernFooter(
            font,
            page: context.pageNumber,
            total: context.pagesCount,
          ),
          build: (context) {
            return [
              pw.SizedBox(height: 16),

              if (reportData.isEmpty)
                _buildModernEmptyState(font)
              else ...[
                _buildCompletionRateBanner(font, reportData),
                _buildStatisticsRow(font, reportData),

                pw.SizedBox(height: 8),

                ...groupedData.entries.expand((entry) {
                  final date = DateTime.parse('${entry.key}-01');
                  final monthTotal = entry.value.length;
                  final monthCompleted = entry.value
                      .where(
                        (e) =>
                            e['status']?.toString().toLowerCase() ==
                            'completed',
                      )
                      .length;
                  final monthRate = monthTotal > 0
                      ? (monthCompleted / monthTotal * 100).toStringAsFixed(1)
                      : '0.0';
                  final rateValue = double.parse(monthRate);

                  return [
                    pw.Container(
                      width: double.infinity,
                      margin: const pw.EdgeInsets.only(bottom: 12, top: 4),
                      padding: const pw.EdgeInsets.all(14),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        borderRadius: pw.BorderRadius.circular(10),
                        border: pw.Border.all(color: PdfColors.grey200),
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                DateFormat(
                                  '"'
                                  "'MMMM yyyy'"
                                  '"',
                                ).format(date),
                                style: pw.TextStyle(
                                  font: font,
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 14,
                                  color: _pdfPrimary,
                                ),
                              ),
                              pw.SizedBox(height: 4),
                              pw.Text(
                                '$monthCompleted of $monthTotal completed',
                                style: pw.TextStyle(
                                  font: font,
                                  fontSize: 10,
                                  color: _pdfTextSecondary,
                                ),
                              ),
                            ],
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: pw.BoxDecoration(
                              color: rateValue >= 80
                                  ? _pdfColorWithOpacity(successColor, 0.15)
                                  : rateValue >= 50
                                  ? _pdfColorWithOpacity(warningColor, 0.15)
                                  : _pdfColorWithOpacity(dangerColor, 0.15),
                              borderRadius: pw.BorderRadius.circular(20),
                            ),
                            child: pw.Text(
                              '$monthRate%',
                              style: pw.TextStyle(
                                font: font,
                                fontSize: 18,
                                fontWeight: pw.FontWeight.bold,
                                color: rateValue >= 80
                                    ? _pdfSuccess
                                    : rateValue >= 50
                                    ? _pdfWarning
                                    : _pdfDanger,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildTransferTable(font, entry.value),
                    pw.SizedBox(height: 16),
                  ];
                }).toList(),
              ],
            ];
          },
        ),
      );

      final bytes = await pdf.save();
      debugPrint('✅ Completion Rate Report generated: ${bytes.length} bytes');
      return bytes;
    } catch (e, stackTrace) {
      debugPrint('❌ Completion Rate Report Error: $e');
      debugPrint(stackTrace.toString());
      return null;
    }
  }

  // =====================================================
  // PDF DOWNLOAD (Platform Agnostic)
  // =====================================================

  static Future<void> downloadPDFWeb(
    Uint8List pdfBytes,
    String fileName,
  ) async {
    try {
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: fileName.endsWith('.pdf') ? fileName : '$fileName.pdf',
      );
      debugPrint('✅ PDF downloaded: $fileName');
    } catch (e, stackTrace) {
      debugPrint('❌ PDF Download Error: $e');
      debugPrint(stackTrace.toString());
      rethrow;
    }
  }
}

extension on PdfColor {}
