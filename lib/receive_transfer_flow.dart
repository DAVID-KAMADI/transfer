// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inter_store/services/firebase_service.dart';
import 'package:signature/signature.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/otp_service.dart';
import '../services/transfer_selection_service.dart';
import '../services/transfer_completion_service.dart';
import '../services/email_service.dart';

class ReceiveTransferFlow extends StatefulWidget {
  final DocumentSnapshot doc;

  const ReceiveTransferFlow({super.key, required this.doc});

  @override
  State<ReceiveTransferFlow> createState() => _ReceiveTransferFlowState();
}

class _ReceiveTransferFlowState extends State<ReceiveTransferFlow> {
  int step = 0;
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;
  bool _isCompletingTransfer = false;

  late List items;
  Map<int, bool> selectedItems = {};

  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
  );

  final TextEditingController otpController = TextEditingController();
  final TextEditingController receiverEmailController = TextEditingController();

  // =========================================================
  // DESIGN SYSTEM — Matching TransferDetailsPage & DriverHomePage
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

  @override
  void initState() {
    super.initState();

    items = (widget.doc['items'] as List?) ?? [];

    for (int i = 0; i < items.length; i++) {
      selectedItems[i] = false;
    }
  }

  void nextStep() => setState(() => step++);

  // =========================================================
  // SELECT ALL / DESELECT ALL
  // =========================================================
  bool get _allSelected =>
      items.isNotEmpty && selectedItems.values.every((v) => v == true);

  bool get _someSelected =>
      selectedItems.values.any((v) => v == true) && !_allSelected;

  void _toggleSelectAll() {
    setState(() {
      final newValue = !_allSelected;
      for (int i = 0; i < items.length; i++) {
        selectedItems[i] = newValue;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryDark,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: Text(
          _stepTitle(),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: _buildProgressBar(),
        ),
      ),
      body: _buildStep(),
    );
  }

  String _stepTitle() {
    switch (step) {
      case 0:
        return "Select Items";
      case 1:
        return "Verify OTP";
      case 2:
        return "Sign & Complete";
      default:
        return "Receive Transfer";
    }
  }

  // =========================================================
  // PROGRESS BAR
  // =========================================================
  Widget _buildProgressBar() {
    return Container(
      height: 4,
      color: Colors.white.withOpacity(0.1),
      child: Row(
        children: [
          Expanded(
            flex: step >= 0 ? 1 : 0,
            child: Container(
              color: step >= 0 ? successColor : Colors.transparent,
            ),
          ),
          Expanded(
            flex: step >= 1 ? 1 : 0,
            child: Container(
              color: step >= 1 ? successColor : Colors.transparent,
            ),
          ),
          Expanded(
            flex: step >= 2 ? 1 : 0,
            child: Container(
              color: step >= 2 ? successColor : Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep() {
    switch (step) {
      case 0:
        return _buildItemSelection();
      case 1:
        return _buildOtpStep();
      case 2:
        return _buildSignatureStep();
      default:
        return const SizedBox();
    }
  }

  // =========================================================
  // STEP 1 — ITEM SELECTION (with Select All)
  // =========================================================
  Widget _buildItemSelection() {
    final selectedCount = selectedItems.values.where((v) => v).length;

    return Column(
      children: [
        // ── Transfer Info Header ──
        _buildTransferInfoHeader(),

        // ── Receiver Email ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: cardBackground,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: receiverEmailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: textPrimary, fontSize: 14),
              decoration: InputDecoration(
                labelText: "Receiver Email",
                labelStyle: const TextStyle(color: textSecondary, fontSize: 13),
                prefixIcon: const Icon(
                  Icons.email_outlined,
                  color: primaryMedium,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: cardBackground,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // ── Select All Bar ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: cardBackground,
              borderRadius: BorderRadius.circular(12),
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
                // Tri-state checkbox for Select All
                GestureDetector(
                  onTap: _toggleSelectAll,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: _allSelected
                          ? successColor
                          : _someSelected
                          ? successColor.withOpacity(0.5)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: _allSelected || _someSelected
                            ? successColor
                            : Colors.grey.shade400,
                        width: 2,
                      ),
                    ),
                    child: _allSelected
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : _someSelected
                        ? const Icon(
                            Icons.remove,
                            size: 14,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _allSelected ? "Deselect All" : "Select All Items",
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: selectedCount > 0
                        ? successColor.withOpacity(0.1)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "$selectedCount / ${items.length} selected",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: selectedCount > 0 ? successColor : textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // ── Items List ──
        Flexible(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final item = items[i];
              final isSelected = selectedItems[i] ?? false;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: cardBackground,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: isSelected
                          ? successColor.withOpacity(0.15)
                          : Colors.black.withOpacity(0.04),
                      blurRadius: isSelected ? 12 : 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                  border: Border.all(
                    color: isSelected
                        ? successColor.withOpacity(0.4)
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: InkWell(
                  onTap: () {
                    setState(() => selectedItems[i] = !isSelected);
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        // Checkbox
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? successColor
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSelected
                                  ? successColor
                                  : Colors.grey.shade400,
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  size: 16,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        const SizedBox(width: 14),
                        // Item info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['code'] ?? '-',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                item['descr'] ?? '-',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: textSecondary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                children: [
                                  if (item['qty'] != null)
                                    _itemBadge(
                                      "Qty: ${item['qty']}",
                                      accentColor,
                                    ),
                                  if (item['serialNo'] != null &&
                                      item['serialNo'].toString().isNotEmpty)
                                    _itemBadge(
                                      "S/N: ${item['serialNo']}",
                                      primaryMedium,
                                    ),
                                  if (item['batchNo'] != null &&
                                      item['batchNo'].toString().isNotEmpty)
                                    _itemBadge(
                                      "Batch: ${item['batchNo']}",
                                      warningColor,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // ── Bottom Action Bar ──
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBackground,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryDark,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isSendingOtp
                    ? null
                    : () async {
                        final selectedIndexes =
                            TransferSelectionService.getSelectedIndexes(
                              selectedItems,
                            );

                        if (!TransferSelectionService.isValidSelection(
                          selectedIndexes,
                        )) {
                          _showSnackBar(
                            "Please select at least one item",
                            warningColor,
                          );
                          return;
                        }

                        final receiverEmail = receiverEmailController.text
                            .trim();

                        if (receiverEmail.isEmpty) {
                          _showSnackBar(
                            "Please enter receiver email",
                            warningColor,
                          );
                          return;
                        }

                        setState(() => _isSendingOtp = true);

                        try {
                          final data =
                              widget.doc.data() as Map<String, dynamic>;

                          // ✅ SAVE EMAIL TO FIRESTORE (NEW FIX)
                          await FirebaseService.saveReceiverEmail(
                            data['year'],
                            data['dayKey'],
                            data['transferNo'],
                            receiverEmail,
                          );

                          await OtpService.sendOtp(
                            year: data['year'],
                            dayKey: data['dayKey'],
                            transferNo: data['transferNo'],
                            email: receiverEmail,
                            selectedIndexes: selectedIndexes,
                            sendEmail: EmailService.sendEmail,
                          );

                          _showSnackBar("OTP sent to email", successColor);
                          nextStep();
                        } catch (e) {
                          _showSnackBar("Failed: $e", dangerColor);
                        } finally {
                          if (mounted) {
                            setState(() => _isSendingOtp = false);
                          }
                        }
                      },
                child: _isSendingOtp
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            "Sending...",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Send OTP",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.send, size: 14),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================
  // TRANSFER INFO HEADER
  // =========================================================
  Widget _buildTransferInfoHeader() {
    final data = widget.doc.data() as Map<String, dynamic>;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(18),
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
          Text(
            "Transfer #${data['transferNo'] ?? '-'}",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "${data['fromStore'] ?? 'Unknown'} → ${data['toStore'] ?? 'Unknown'}",
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "${items.length} item${items.length != 1 ? 's' : ''}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================
  // ITEM BADGE
  // =========================================================
  Widget _itemBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  // =========================================================
  // STEP 2 — OTP VERIFICATION
  // =========================================================
  Widget _buildOtpStep() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Info Card ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accentColor.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.email_outlined,
                    color: accentColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Check your email",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: textPrimary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "An OTP has been sent to the receiver's email address. Enter it below to verify.",
                        style: TextStyle(
                          fontSize: 13,
                          color: textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── OTP Input ──
          Text(
            "Enter OTP Code",
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: textSecondary.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: cardBackground,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textPrimary,
                letterSpacing: 8,
              ),
              maxLength: 6,
              decoration: InputDecoration(
                hintText: "000000",
                hintStyle: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade300,
                  letterSpacing: 8,
                ),
                counterText: "",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: cardBackground,
                contentPadding: const EdgeInsets.symmetric(vertical: 20),
              ),
            ),
          ),

          const Spacer(),

          // ── Verify Button ──
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryDark,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isVerifyingOtp
                  ? null
                  : () async {
                      setState(() => _isVerifyingOtp = true);

                      try {
                        final data = widget.doc.data() as Map<String, dynamic>;

                        await OtpService.verifyOtp(
                          year: data['year'],
                          dayKey: data['dayKey'],
                          transferNo: data['transferNo'],
                          otp: otpController.text.trim(),
                        );

                        _showSnackBar(
                          "OTP Verified successfully",
                          successColor,
                        );
                        nextStep();
                      } catch (e) {
                        _showSnackBar(
                          e.toString().replaceAll("Exception: ", ""),
                          dangerColor,
                        );
                      } finally {
                        if (mounted) {
                          setState(() => _isVerifyingOtp = false);
                        }
                      }
                    },
              child: _isVerifyingOtp
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          "Verifying...",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Verify OTP",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.verified_user, size: 18),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // STEP 3 — SIGNATURE
  // =========================================================
  Widget _buildSignatureStep() {
    return Column(
      children: [
        // ── Info Banner ──
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: successColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: successColor.withOpacity(0.2)),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle, color: successColor),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  "OTP verified. Please sign below to complete the transfer.",
                  style: TextStyle(
                    color: successColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Signature Label ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                "Receiver Signature",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: textSecondary.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // ── Signature Pad ──
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: cardBackground,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Signature(
                controller: _signatureController,
                backgroundColor: Colors.white,
              ),
            ),
          ),
        ),

        // ── Clear Signature Button ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextButton.icon(
            onPressed: () => _signatureController.clear(),
            icon: const Icon(Icons.clear, size: 18, color: dangerColor),
            label: const Text(
              "Clear Signature",
              style: TextStyle(color: dangerColor, fontWeight: FontWeight.w600),
            ),
          ),
        ),

        // ── Complete Button ──
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBackground,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: successColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isCompletingTransfer
                    ? null
                    : () async {
                        if (_signatureController.isEmpty) {
                          _showSnackBar(
                            "Please provide a signature",
                            warningColor,
                          );
                          return;
                        }

                        setState(() => _isCompletingTransfer = true);

                        try {
                          final signatureBytes = await _signatureController
                              .toPngBytes();
                          final signatureBase64 = base64Encode(signatureBytes!);

                          final selectedIndexes =
                              TransferSelectionService.getSelectedIndexes(
                                selectedItems,
                              );

                          final data =
                              widget.doc.data() as Map<String, dynamic>;
                          final transferData = data;
                          final otpData = transferData['otpData'] ?? {};

                          await TransferCompletionService.completeTransfer(
                            year: data['year'],
                            dayKey: data['dayKey'],
                            transferNo: data['transferNo'],
                            selectedIndexes: selectedIndexes,
                            signatureBase64: signatureBase64,
                            receivedBy:
                                FirebaseAuth.instance.currentUser?.email ?? '',
                            receiverName: data['assignedToName'] ?? '',
                            receiverEmail: receiverEmailController.text.trim(),
                            otp: otpData['code'] ?? '',
                            otpCreatedAt: otpData['createdAt'],
                            otpVerifiedAt: otpData['verifiedAt'],
                          );

                          if (context.mounted) {
                            _showSnackBar(
                              "Transfer completed successfully!",
                              successColor,
                            );
                            Navigator.pop(context);
                            Navigator.pop(context);
                          }
                        } catch (e) {
                          _showSnackBar(
                            "Failed to complete transfer: $e",
                            dangerColor,
                          );
                        } finally {
                          if (mounted) {
                            setState(() => _isCompletingTransfer = false);
                          }
                        }
                      },
                child: _isCompletingTransfer
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            "Completing...",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Complete Transfer",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.check_circle, size: 18),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================
  // SNACKBAR HELPER
  // =========================================================
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == successColor
                  ? Icons.check_circle
                  : color == warningColor
                  ? Icons.warning_amber_rounded
                  : Icons.error_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
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
}
