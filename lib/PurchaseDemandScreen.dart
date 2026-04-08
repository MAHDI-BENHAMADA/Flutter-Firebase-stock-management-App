import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Threshold below which a product is considered low-stock.
const int kLowStockThreshold = 5;

// ── Data model ────────────────────────────────────────────────────────────────

class _ProductRow {
  final String docId;
  final String name;
  final String category;
  final int currentStock;

  _ProductRow({
    required this.docId,
    required this.name,
    required this.category,
    required this.currentStock,
  });
}

// ── Screen ────────────────────────────────────────────────────────────────────

class PurchaseDemandScreen extends StatefulWidget {
  const PurchaseDemandScreen({super.key});

  @override
  State<PurchaseDemandScreen> createState() => _PurchaseDemandScreenState();
}

class _PurchaseDemandScreenState extends State<PurchaseDemandScreen> {
  static const Color _purple = Color.fromRGBO(107, 59, 225, 1);

  /// Per-product state keyed by docId
  final Map<String, bool> _checked = {};
  final Map<String, TextEditingController> _qtyControllers = {};

  @override
  void dispose() {
    for (final c in _qtyControllers.values) c.dispose();
    super.dispose();
  }

  // ── PDF generation ───────────────────────────────────────────────────────

  Future<void> _printDemand(List<_ProductRow> products) async {
    final selected = products.where((p) => _checked[p.docId] == true).toList();

    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Select at least one product to print')),
      );
      return;
    }

    await Printing.layoutPdf(
      onLayout: (format) => _buildPdf(format, selected),
    );
  }

  Future<Uint8List> _buildPdf(
    PdfPageFormat format,
    List<_ProductRow> selected,
  ) async {
    final pdf = pw.Document();
    final dateStr = DateFormat('dd / MM / yyyy').format(DateTime.now());

    final rows = selected.map((p) {
      final reqQty = _qtyControllers[p.docId]?.text.trim() ?? '';
      return [p.name, p.category, '${p.currentStock}', reqQty.isEmpty ? '-' : reqQty];
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
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.5),
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#6B3BE1')),
                  children: [
                    _pdfCell('Product', bold: true, textColor: PdfColors.white),
                    _pdfCell('Category', bold: true, textColor: PdfColors.white),
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
                  final currentStock = int.tryParse(row[2]) ?? 0;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: isEven ? PdfColors.white : PdfColors.grey100,
                    ),
                    children: [
                      _pdfCell(row[0]),
                      _pdfCell(row[1]),
                      _pdfCell(
                        row[2],
                        textColor: currentStock < kLowStockThreshold
                            ? PdfColors.red700
                            : PdfColors.black,
                      ),
                      _pdfCell(row[3]),
                    ],
                  );
                }),
              ],
            ),

            pw.SizedBox(height: 24),

            // Note
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius:
                    const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Text(
                'Note: Products marked in red are below the minimum stock threshold '
                '(< $kLowStockThreshold units). Please process this request as soon as possible.',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
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

  pw.Widget _pdfCell(String text,
      {bool bold = false, PdfColor? textColor}) {
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
      backgroundColor: const Color(0xFFF7F6FC),
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

          // Build a flat product list
          final List<_ProductRow> products = docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return _ProductRow(
              docId: doc.id,
              name: (data['name'] as String?)?.trim() ?? 'Unnamed',
              category:
                  (data['category'] as String?)?.trim() ?? 'Uncategorized',
              currentStock: data['quantity'] as int? ?? 0,
            );
          }).toList();

          // Sort: category first, then product name
          products.sort((a, b) {
            final catCmp = a.category.compareTo(b.category);
            return catCmp != 0 ? catCmp : a.name.compareTo(b.name);
          });

          // Auto-init checkboxes and controllers
          for (final p in products) {
            _checked.putIfAbsent(
                p.docId, () => p.currentStock < kLowStockThreshold);
            _qtyControllers.putIfAbsent(
                p.docId, () => TextEditingController());
          }

          if (products.isEmpty) {
            return const Center(
              child: Text('No products found.',
                  style: TextStyle(fontSize: 16, color: Colors.grey)),
            );
          }

          // Group into category sections
          final Map<String, List<_ProductRow>> grouped = {};
          for (final p in products) {
            grouped.putIfAbsent(p.category, () => []).add(p);
          }
          final categoryKeys = grouped.keys.toList()..sort();

          return Column(
            children: [
              // Info banner
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
                        'Products with stock below $kLowStockThreshold are auto-selected. '
                        'Enter desired quantities and tap Print.',
                        style: TextStyle(
                            color: _purple.withOpacity(0.85), fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

              // Product list grouped by category
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  itemCount: categoryKeys.length,
                  itemBuilder: (context, ci) {
                    final cat = categoryKeys[ci];
                    final catProducts = grouped[cat]!;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category section header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 12, 0, 6),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: _purple,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                cat,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color.fromRGBO(107, 59, 225, 1),
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Divider(
                                    color: _purple.withOpacity(0.2),
                                    thickness: 1),
                              ),
                            ],
                          ),
                        ),

                        // Products in this category
                        ...catProducts.map((p) => _ProductDemandTile(
                              product: p,
                              isChecked: _checked[p.docId] ?? false,
                              controller: _qtyControllers[p.docId]!,
                              onChecked: (v) =>
                                  setState(() => _checked[p.docId] = v ?? false),
                            )),
                      ],
                    );
                  },
                ),
              ),

              // Print button
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _printDemand(products),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _purple,
                        padding:
                            const EdgeInsets.symmetric(vertical: 16),
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

// ── Product demand tile ────────────────────────────────────────────────────────

class _ProductDemandTile extends StatelessWidget {
  final _ProductRow product;
  final bool isChecked;
  final TextEditingController controller;
  final ValueChanged<bool?> onChecked;

  static const Color _purple = Color.fromRGBO(107, 59, 225, 1);

  const _ProductDemandTile({
    required this.product,
    required this.isChecked,
    required this.controller,
    required this.onChecked,
  });

  @override
  Widget build(BuildContext context) {
    final isLow = product.currentStock < kLowStockThreshold;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isChecked ? _purple.withOpacity(0.05) : Colors.white,
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
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            Checkbox(
              value: isChecked,
              activeColor: _purple,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
              onChanged: onChecked,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                      ),
                      if (isLow)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border:
                                Border.all(color: Colors.red.shade200),
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
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Current stock: ${product.currentStock} units',
                    style: TextStyle(
                      color: isLow
                          ? Colors.red.shade500
                          : Colors.grey.shade500,
                      fontSize: 12,
                      fontWeight:
                          isLow ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Qty field
            SizedBox(
              width: 78,
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                enabled: isChecked,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Qty',
                  hintStyle: TextStyle(
                      color: Colors.grey.shade400, fontSize: 12),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 8),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        BorderSide(color: _purple.withOpacity(0.4)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _purple),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        BorderSide(color: Colors.grey.shade200),
                  ),
                  filled: true,
                  fillColor:
                      isChecked ? Colors.white : Colors.grey.shade50,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
