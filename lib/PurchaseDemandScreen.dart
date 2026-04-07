import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:wa_inventory/CategoryOverviewScreen.dart' show kLowStockThreshold;

class PurchaseDemandScreen extends StatefulWidget {
  const PurchaseDemandScreen({super.key});

  @override
  State<PurchaseDemandScreen> createState() => _PurchaseDemandScreenState();
}

class _PurchaseDemandScreenState extends State<PurchaseDemandScreen> {
  static const Color _purple = Color.fromRGBO(107, 59, 225, 1);

  /// per-category state: checked + requested-qty controller
  final Map<String, bool> _checked = {};
  final Map<String, TextEditingController> _qtyControllers = {};

  @override
  void dispose() {
    for (final c in _qtyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ── PDF generation ────────────────────────────────────────────────────────

  Future<void> _printDemand(
      List<MapEntry<String, int>> categories) async {
    final selected = categories
        .where((e) => _checked[e.key] == true)
        .toList();

    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one category to print')),
      );
      return;
    }

    await Printing.layoutPdf(
      onLayout: (format) => _buildPdf(format, selected),
    );
  }

  Future<Uint8List> _buildPdf(
    PdfPageFormat format,
    List<MapEntry<String, int>> selected,
  ) async {
    final pdf = pw.Document();
    final dateStr =
        DateFormat('dd / MM / yyyy').format(DateTime.now());

    // Collect rows
    final rows = selected.map((e) {
      final reqQty = _qtyControllers[e.key]?.text.trim() ?? '';
      return [e.key, '${e.value}', reqQty.isEmpty ? '-' : reqQty];
    }).toList();

    pdf.addPage(
      pw.Page(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(36),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'PURCHASE DEMAND',
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#6B3BE1'),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Inventory Restock Request',
                      style: pw.TextStyle(
                          fontSize: 12, color: PdfColors.grey600),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Date: $dateStr',
                        style: const pw.TextStyle(fontSize: 11)),
                    pw.Text('Status: Pending',
                        style: pw.TextStyle(
                            fontSize: 11, color: PdfColors.orange)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Divider(color: PdfColor.fromHex('#6B3BE1'), thickness: 2),
            pw.SizedBox(height: 16),

            // Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(2),
              },
              children: [
                // Table header
                pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#6B3BE1'),
                  ),
                  children: [
                    _pdfCell('Category',
                        bold: true, textColor: PdfColors.white),
                    _pdfCell('Current Stock',
                        bold: true, textColor: PdfColors.white),
                    _pdfCell('Requested Qty',
                        bold: true, textColor: PdfColors.white),
                  ],
                ),
                // Data rows
                ...rows.asMap().entries.map((entry) {
                  final isEven = entry.key % 2 == 0;
                  final row = entry.value;
                  final currentStock = int.tryParse(row[1]) ?? 0;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color:
                          isEven ? PdfColors.white : PdfColors.grey100,
                    ),
                    children: [
                      _pdfCell(row[0]),
                      _pdfCell(
                        row[1],
                        textColor: currentStock < kLowStockThreshold
                            ? PdfColors.red700
                            : PdfColors.black,
                      ),
                      _pdfCell(row[2]),
                    ],
                  );
                }),
              ],
            ),

            pw.SizedBox(height: 24),

            // Footer note
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius:
                    const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Text(
                'Note: Categories marked in red are below the minimum stock threshold (< $kLowStockThreshold units). '
                'Please process this request as soon as possible.',
                style: pw.TextStyle(
                    fontSize: 10, color: PdfColors.grey700),
              ),
            ),

            pw.Spacer(),
            pw.Divider(color: PdfColors.grey300),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Prepared by: ___________________',
                    style: const pw.TextStyle(fontSize: 10)),
                pw.Text('Approved by: ___________________',
                    style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  pw.Widget _pdfCell(
    String text, {
    bool bold = false,
    PdfColor? textColor,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: 11,
          color: textColor ?? PdfColors.black,
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _purple,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Purchase Demand',
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('products')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _purple));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];

          // Aggregate totals per category
          final Map<String, int> totals = {};
          for (final doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final cat =
                (data['category'] as String?)?.trim() ?? 'Uncategorized';
            final qty = data['quantity'] as int? ?? 0;
            totals[cat] = (totals[cat] ?? 0) + qty;
          }

          final categories = totals.entries.toList()
            ..sort((a, b) => a.key.compareTo(b.key));

          // Auto-init checkboxes and controllers on first load
          for (final e in categories) {
            _checked.putIfAbsent(e.key, () => e.value < kLowStockThreshold);
            _qtyControllers.putIfAbsent(e.key, () => TextEditingController());
          }

          if (categories.isEmpty) {
            return const Center(
                child: Text('No products found.',
                    style: TextStyle(fontSize: 16, color: Colors.grey)));
          }

          return Column(
            children: [
              // ── Instruction banner ──────────────────────────────────────
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _purple.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _purple.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: _purple, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Categories with stock below $kLowStockThreshold are auto-selected. '
                        'Enter desired quantities and tap Print.',
                        style: TextStyle(
                            color: _purple.withOpacity(0.85),
                            fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Category rows ───────────────────────────────────────────
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  itemCount: categories.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final e = categories[i];
                    final isLow = e.value < kLowStockThreshold;
                    final isChecked = _checked[e.key] ?? false;

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isChecked
                            ? _purple.withOpacity(0.05)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isChecked
                              ? _purple.withOpacity(0.3)
                              : Colors.grey.shade200,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            // Checkbox
                            Checkbox(
                              value: isChecked,
                              activeColor: _purple,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4)),
                              onChanged: (v) => setState(
                                  () => _checked[e.key] = v ?? false),
                            ),
                            const SizedBox(width: 4),

                            // Category info
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          e.key,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                      if (isLow)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade50,
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                                color: Colors.red.shade200),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.warning_rounded,
                                                  size: 11,
                                                  color: Colors.red.shade600),
                                              const SizedBox(width: 3),
                                              Text(
                                                'Low',
                                                style: TextStyle(
                                                  color: Colors.red.shade600,
                                                  fontSize: 10,
                                                  fontWeight:
                                                      FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Current stock: ${e.value} units',
                                    style: TextStyle(
                                      color: isLow
                                          ? Colors.red.shade500
                                          : Colors.grey.shade500,
                                      fontSize: 12,
                                      fontWeight: isLow
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 12),

                            // Requested qty field
                            SizedBox(
                              width: 80,
                              child: TextField(
                                controller: _qtyControllers[e.key],
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                enabled: isChecked,
                                style: const TextStyle(fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'Qty',
                                  hintStyle: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 12),
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 8),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide:
                                        BorderSide(color: _purple.withOpacity(0.4)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide:
                                        const BorderSide(color: _purple),
                                  ),
                                  disabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                        color: Colors.grey.shade200),
                                  ),
                                  filled: true,
                                  fillColor: isChecked
                                      ? Colors.white
                                      : Colors.grey.shade50,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // ── Bottom print button ─────────────────────────────────────
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _printDemand(categories),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _purple,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                        shadowColor: _purple.withOpacity(0.4),
                      ),
                      icon: const Icon(Icons.print_outlined,
                          color: Colors.white),
                      label: const Text(
                        'Preview & Print Demand Sheet',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
