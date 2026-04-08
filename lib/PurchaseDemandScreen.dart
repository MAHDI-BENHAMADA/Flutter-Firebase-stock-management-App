import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

const int kLowStockThreshold = 5;

// ── Demand line item model ────────────────────────────────────────────────────

class _DemandItem {
  /// null = manually typed new item (not in inventory)
  final String? docId;
  final String name;
  final String category;
  final int? currentStock; // null if new item
  final TextEditingController qtyController;

  _DemandItem({
    this.docId,
    required this.name,
    required this.category,
    this.currentStock,
  }) : qtyController = TextEditingController();

  void dispose() => qtyController.dispose();
}

// ── Screen ────────────────────────────────────────────────────────────────────

class PurchaseDemandScreen extends StatefulWidget {
  const PurchaseDemandScreen({super.key});

  @override
  State<PurchaseDemandScreen> createState() => _PurchaseDemandScreenState();
}

class _PurchaseDemandScreenState extends State<PurchaseDemandScreen> {
  static const Color _purple = Color.fromRGBO(107, 59, 225, 1);

  final List<_DemandItem> _items = [];

  @override
  void initState() {
    super.initState();
    _fetchZeroSkuItems();
  }

  Future<void> _fetchZeroSkuItems() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('products')
        .get();

    if (!mounted) return;

    setState(() {
      for (var doc in snap.docs) {
        final data = doc.data();
        final skus = data['numberOfSkus'] as int?;
        if (skus == 0 || skus == null) {
          // Avoid adding duplicates if already present
          if (!_items.any((i) => i.docId == doc.id)) {
            _items.add(_DemandItem(
              docId: doc.id,
              name: (data['name'] as String?)?.trim() ?? 'Unnamed',
              category: (data['category'] as String?)?.trim() ?? 'Uncategorized',
              currentStock: skus ?? 0,
            ));
          }
        }
      }
    });
  }

  @override
  void dispose() {
    for (final item in _items) item.dispose();
    super.dispose();
  }

  void _removeItem(int index) {
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

  // ── Add item bottom sheet ─────────────────────────────────────────────────

  Future<void> _showAddItemSheet() async {
    final user = FirebaseAuth.instance.currentUser!;

    // Fetch all existing products once
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('products')
        .get();

    final existingProducts = snap.docs.map((doc) {
      final data = doc.data();
      return {
        'docId': doc.id,
        'name': (data['name'] as String?)?.trim() ?? 'Unnamed',
        'category': (data['category'] as String?)?.trim() ?? 'Uncategorized',
        'currentStock': data['numberOfSkus'] as int? ?? 0,
      };
    }).toList();

    existingProducts
        .sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddItemSheet(
        existingProducts: existingProducts,
        onAdd: (item) {
          // Prevent duplicate inventory products
          final alreadyAdded = _items.any((i) => i.docId == item.docId && item.docId != null);
          if (alreadyAdded) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('This product is already in the list')),
            );
            return;
          }
          setState(() => _items.add(item));
        },
      ),
    );
  }

  // ── PDF generation ────────────────────────────────────────────────────────

  Future<void> _printDemand() async {
    final withQty = _items
        .where((i) => i.qtyController.text.trim().isNotEmpty)
        .toList();

    if (withQty.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Fill in at least one quantity before printing')),
      );
      return;
    }

    await Printing.layoutPdf(
      onLayout: (format) => _buildPdf(format, withQty),
    );
  }

  Future<Uint8List> _buildPdf(
      PdfPageFormat format, List<_DemandItem> items) async {
    final pdf = pw.Document();
    final dateStr = DateFormat('dd / MM / yyyy').format(DateTime.now());

    pdf.addPage(
      pw.Page(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(36),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('PURCHASE DEMAND',
                        style: pw.TextStyle(
                            fontSize: 22,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#6B3BE1'))),
                    pw.SizedBox(height: 4),
                    pw.Text('Inventory Restock Request',
                        style: pw.TextStyle(
                            fontSize: 12, color: PdfColors.grey600)),
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
            pw.Divider(
                color: PdfColor.fromHex('#6B3BE1'), thickness: 2),
            pw.SizedBox(height: 16),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(
                  decoration:
                      pw.BoxDecoration(color: PdfColor.fromHex('#6B3BE1')),
                  children: [
                    _pdfCell('Product',
                        bold: true, textColor: PdfColors.white),
                    _pdfCell('Category',
                        bold: true, textColor: PdfColors.white),
                    _pdfCell('Current Stock',
                        bold: true, textColor: PdfColors.white),
                    _pdfCell('Requested Qty',
                        bold: true, textColor: PdfColors.white),
                  ],
                ),
                ...items.asMap().entries.map((entry) {
                  final isEven = entry.key % 2 == 0;
                  final item = entry.value;
                  final stock = item.currentStock;
                  final stockStr =
                      stock != null ? '$stock' : 'New Item';
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                        color: isEven
                            ? PdfColors.white
                            : PdfColors.grey100),
                    children: [
                      _pdfCell(item.name),
                      _pdfCell(item.category),
                      _pdfCell(
                        stockStr,
                        textColor: (stock != null &&
                                stock < kLowStockThreshold)
                            ? PdfColors.red700
                            : PdfColors.black,
                      ),
                      _pdfCell(item.qtyController.text.trim()),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 24),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius:
                    const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Text(
                'Note: Products in red are below minimum stock threshold '
                '(< $kLowStockThreshold units). Process as soon as possible.',
                style:
                    pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
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
          fontWeight:
              bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: 11,
          color: textColor ?? PdfColors.black,
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F6FC),
      appBar: AppBar(
        backgroundColor: _purple,
        iconTheme: const IconThemeData(color: Colors.white),
        automaticallyImplyLeading: false,
        title: const Text(
          'Purchase Demand',
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20),
        ),
        actions: [
          if (_items.isNotEmpty)
            TextButton.icon(
              onPressed: _printDemand,
              icon: const Icon(Icons.print_outlined,
                  color: Colors.white, size: 18),
              label: const Text('Print',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: _items.isEmpty
          ? _EmptyState(onAddItem: _showAddItemSheet)
          : _ItemList(
              items: _items,
              onRemove: _removeItem,
              onAddMore: _showAddItemSheet,
              onPrint: _printDemand,
            ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAddItem;
  static const Color _purple = Color.fromRGBO(107, 59, 225, 1);

  const _EmptyState({required this.onAddItem});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: _purple.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long_outlined,
                size: 42, color: _purple),
          ),
          const SizedBox(height: 20),
          const Text(
            'No items yet',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E)),
          ),
          const SizedBox(height: 8),
          Text(
            'Add products you want to purchase\nor restock.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: onAddItem,
            style: ElevatedButton.styleFrom(
              backgroundColor: _purple,
              padding: const EdgeInsets.symmetric(
                  horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 3,
              shadowColor: _purple.withValues(alpha: 0.4),
            ),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'Add Item',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Item list ─────────────────────────────────────────────────────────────────

class _ItemList extends StatefulWidget {
  final List<_DemandItem> items;
  final void Function(int) onRemove;
  final VoidCallback onAddMore;
  final VoidCallback onPrint;

  const _ItemList({
    required this.items,
    required this.onRemove,
    required this.onAddMore,
    required this.onPrint,
  });

  @override
  State<_ItemList> createState() => _ItemListState();
}

class _ItemListState extends State<_ItemList> {
  static const Color _purple = Color.fromRGBO(107, 59, 225, 1);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            itemCount: widget.items.length + 1, // +1 for "add more" row
            itemBuilder: (context, i) {
              if (i == widget.items.length) {
                // Add more button at bottom of list
                return Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 16),
                  child: OutlinedButton.icon(
                    onPressed: widget.onAddMore,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _purple,
                      side: BorderSide(
                          color: _purple.withValues(alpha: 0.5),
                          width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Another Item',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                );
              }

              final item = widget.items[i];
              final isLow = item.currentStock != null &&
                  item.currentStock! < kLowStockThreshold;
              final isNew = item.docId == null;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Row(
                  children: [
                    // Left info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: Color(0xFF1A1A2E),
                                  ),
                                ),
                              ),
                              if (isNew)
                                _Badge('NEW', Colors.blue.shade400),
                              if (!isNew && isLow)
                                _Badge('LOW', Colors.red.shade400),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Icon(Icons.label_outline,
                                  size: 12,
                                  color: Colors.grey.shade400),
                              const SizedBox(width: 4),
                              Text(
                                item.category,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500),
                              ),
                              if (!isNew && item.currentStock != null) ...[
                                const SizedBox(width: 8),
                                Text('·',
                                    style: TextStyle(
                                        color: Colors.grey.shade300)),
                                const SizedBox(width: 8),
                                Text(
                                  'Stock: ${item.currentStock}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isLow
                                        ? Colors.red.shade400
                                        : Colors.grey.shade500,
                                    fontWeight: isLow
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 10),

                    // Qty field
                    SizedBox(
                      width: 72,
                      child: TextField(
                        controller: item.qtyController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          hintText: 'Qty',
                          hintStyle: TextStyle(
                              color: Colors.grey.shade400, fontSize: 12),
                          contentPadding:
                              const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 8),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                                color: _purple.withValues(alpha: 0.35)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: _purple),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                    ),

                    const SizedBox(width: 6),

                    // Delete
                    IconButton(
                      onPressed: () => widget.onRemove(i),
                      icon: Icon(Icons.close_rounded,
                          size: 18, color: Colors.grey.shade400),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Remove',
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        // Bottom print bar (only shows when at least one qty is filled)
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.onPrint,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _purple,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 3,
                  shadowColor: _purple.withValues(alpha: 0.4),
                ),
                icon: const Icon(Icons.print_outlined,
                    color: Colors.white),
                label: Text(
                  'Generate PDF (${widget.items.length} item${widget.items.length != 1 ? 's' : ''})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;

  const _Badge(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

// ── Add Item bottom sheet ─────────────────────────────────────────────────────

class _AddItemSheet extends StatefulWidget {
  final List<Map<String, dynamic>> existingProducts;
  final void Function(_DemandItem) onAdd;

  const _AddItemSheet({
    required this.existingProducts,
    required this.onAdd,
  });

  @override
  State<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<_AddItemSheet> {
  static const Color _purple = Color.fromRGBO(107, 59, 225, 1);

  /// 'existing' or 'new'
  String _tab = 'existing';
  String _search = '';

  // For new item
  final _newNameController = TextEditingController();
  final _newCategoryController = TextEditingController();

  @override
  void dispose() {
    _newNameController.dispose();
    _newCategoryController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtered {
    if (_search.trim().isEmpty) return widget.existingProducts;
    return widget.existingProducts
        .where((p) =>
            (p['name'] as String)
                .toLowerCase()
                .contains(_search.toLowerCase()) ||
            (p['category'] as String)
                .toLowerCase()
                .contains(_search.toLowerCase()))
        .toList();
  }

  void _addExisting(Map<String, dynamic> product) {
    final item = _DemandItem(
      docId: product['docId'] as String,
      name: product['name'] as String,
      category: product['category'] as String,
      currentStock: product['currentStock'] as int?,
    );
    widget.onAdd(item);
    Navigator.pop(context);
  }

  void _addNew() {
    final name = _newNameController.text.trim();
    final category = _newCategoryController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter a product name')));
      return;
    }
    final item = _DemandItem(
      docId: null,
      name: name,
      category: category.isEmpty ? 'Uncategorized' : category,
      currentStock: null,
    );
    widget.onAdd(item);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Text('Add Item to Demand',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Tab switcher
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    _SheetTab(
                      label: 'From Inventory',
                      selected: _tab == 'existing',
                      onTap: () => setState(() => _tab = 'existing'),
                    ),
                    _SheetTab(
                      label: 'New Item',
                      selected: _tab == 'new',
                      onTap: () => setState(() => _tab = 'new'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Content
            if (_tab == 'existing') ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  cursorColor: _purple,
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: 'Search products or categories...',
                    hintStyle:
                        TextStyle(color: Colors.grey.shade400, fontSize: 13),
                    prefixIcon: const Icon(Icons.search,
                        color: Colors.grey, size: 20),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 10),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _purple),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _filtered.isEmpty
                    ? Center(
                        child: Text('No products found',
                            style: TextStyle(
                                color: Colors.grey.shade400)))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 4),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => Divider(
                            height: 1, color: Colors.grey.shade100),
                        itemBuilder: (context, i) {
                          final p = _filtered[i];
                          final stock = p['currentStock'] as int;
                          final isLow = stock < kLowStockThreshold;
                          return ListTile(
                            dense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(
                                    horizontal: 0, vertical: 4),
                            title: Text(
                              p['name'] as String,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14),
                            ),
                            subtitle: Text(
                              '${p['category']}  ·  Stock: $stock',
                              style: TextStyle(
                                fontSize: 12,
                                color: isLow
                                    ? Colors.red.shade400
                                    : Colors.grey.shade500,
                              ),
                            ),
                            trailing: isLow
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius:
                                          BorderRadius.circular(6),
                                    ),
                                    child: Text('LOW',
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.red.shade600,
                                            fontWeight:
                                                FontWeight.bold)),
                                  )
                                : null,
                            onTap: () => _addExisting(p),
                          );
                        },
                      ),
              ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    TextField(
                      controller: _newNameController,
                      cursorColor: _purple,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Product name *',
                        labelStyle: const TextStyle(color: _purple),
                        focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: _purple),
                            borderRadius:
                                BorderRadius.all(Radius.circular(10))),
                        enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                                color: Colors.grey.shade300),
                            borderRadius: const BorderRadius.all(
                                Radius.circular(10))),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _newCategoryController,
                      cursorColor: _purple,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Category (optional)',
                        labelStyle: const TextStyle(color: _purple),
                        focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: _purple),
                            borderRadius:
                                BorderRadius.all(Radius.circular(10))),
                        enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                                color: Colors.grey.shade300),
                            borderRadius: const BorderRadius.all(
                                Radius.circular(10))),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _addNew,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _purple,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text('Add to Demand List',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SheetTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SheetTab(
      {required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight:
                  selected ? FontWeight.w600 : FontWeight.normal,
              color: selected
                  ? const Color.fromRGBO(107, 59, 225, 1)
                  : Colors.grey.shade500,
            ),
          ),
        ),
      ),
    );
  }
}
