import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:wa_inventory/PurchaseDemandScreen.dart';
import 'package:wa_inventory/productDetail.dart';

/// Threshold below which a category is considered low-stock.
const int kLowStockThreshold = 5;

class CategoryOverviewScreen extends StatelessWidget {
  const CategoryOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _CategoryOverviewBody();
  }
}

class _CategoryOverviewBody extends StatelessWidget {
  const _CategoryOverviewBody();

  static const Color _purple = Color.fromRGBO(107, 59, 225, 1);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _purple,
        automaticallyImplyLeading: false,
        title: const Text(
          'Stock by Category',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_shopping_cart_outlined,
                color: Colors.white),
            tooltip: 'Create Purchase Demand',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const PurchaseDemandScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PurchaseDemandScreen()),
        ),
        backgroundColor: _purple,
        icon: const Icon(Icons.receipt_long, color: Colors.white),
        label: const Text('Purchase Demand',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
                child: CircularProgressIndicator(
                    color: _purple));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];

          // Group by category
          final Map<String, List<Map<String, dynamic>>> grouped = {};
          for (final doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final cat =
                (data['category'] as String?)?.trim() ?? 'Uncategorized';
            grouped.putIfAbsent(cat, () => []).add({...data, '__docId': doc.id});
          }

          if (grouped.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 80, color: _purple.withOpacity(0.25)),
                  const SizedBox(height: 16),
                  const Text('No products yet',
                      style: TextStyle(fontSize: 18, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Text('Add products to see category totals',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade400)),
                ],
              ),
            );
          }

          // Sort alphabetically
          final categories = grouped.entries.toList()
            ..sort((a, b) => a.key.compareTo(b.key));

          // Aggregate stats
          final totalSkus = docs.length;
          final totalStock = docs.fold<int>(
            0,
            (sum, doc) =>
                sum + ((doc.data() as Map)['quantity'] as int? ?? 0),
          );
          final lowCount = categories.where((e) {
            final qty = e.value
                .fold<int>(0, (s, p) => s + (p['quantity'] as int? ?? 0));
            return qty < kLowStockThreshold;
          }).length;

          return Column(
            children: [
              _SummaryHeader(
                totalSkus: totalSkus,
                totalStock: totalStock,
                lowCount: lowCount,
              ),
              Expanded(
                child: ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: categories.length,
                  itemBuilder: (context, i) {
                    final entry = categories[i];
                    final totalQty = entry.value.fold<int>(
                        0, (s, p) => s + (p['quantity'] as int? ?? 0));
                    return _CategoryCard(
                      categoryName: entry.key,
                      products: entry.value,
                      totalQuantity: totalQty,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Summary header ────────────────────────────────────────────────────────────

class _SummaryHeader extends StatelessWidget {
  final int totalSkus;
  final int totalStock;
  final int lowCount;

  const _SummaryHeader({
    required this.totalSkus,
    required this.totalStock,
    required this.lowCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color.fromRGBO(107, 59, 225, 1), Color(0xFF9B59B6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color.fromRGBO(107, 59, 225, 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatPill(label: 'Total SKUs', value: '$totalSkus', icon: Icons.inventory_2),
          _StatPill(label: 'Total Units', value: '$totalStock', icon: Icons.layers),
          _StatPill(
            label: 'Low Stock',
            value: '$lowCount',
            icon: Icons.warning_amber_rounded,
            valueColor: lowCount > 0 ? Colors.yellow.shade200 : Colors.white,
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  const _StatPill({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}

// ── Category card ─────────────────────────────────────────────────────────────

class _CategoryCard extends StatefulWidget {
  final String categoryName;
  final List<Map<String, dynamic>> products;
  final int totalQuantity;

  const _CategoryCard({
    required this.categoryName,
    required this.products,
    required this.totalQuantity,
  });

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  static const Color _purple = Color.fromRGBO(107, 59, 225, 1);

  Color get _stockColor {
    if (widget.totalQuantity < kLowStockThreshold) return Colors.red.shade400;
    if (widget.totalQuantity < 15) return Colors.orange.shade400;
    return Colors.green.shade500;
  }

  String get _stockLabel {
    if (widget.totalQuantity < kLowStockThreshold) return 'LOW';
    if (widget.totalQuantity < 15) return 'MED';
    return 'OK';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _expanded
              ? _purple.withOpacity(0.4)
              : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: _expanded
                ? _purple.withOpacity(0.08)
                : Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header row ──────────────────────────────────────────────────
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Stock badge
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _stockColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${widget.totalQuantity}',
                          style: TextStyle(
                            color: _stockColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          _stockLabel,
                          style: TextStyle(
                            color: _stockColor,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.categoryName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.products.length} SKU${widget.products.length != 1 ? 's' : ''}',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  // Stock level indicator bar
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _stockColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: _stockColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.totalQuantity < kLowStockThreshold
                                  ? 'Low Stock'
                                  : widget.totalQuantity < 15
                                      ? 'Medium'
                                      : 'In Stock',
                              style: TextStyle(
                                color: _stockColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: Colors.grey.shade400,
                        size: 18,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded products list ──────────────────────────────────────
          if (_expanded) ...[
            Divider(
                height: 1, color: Colors.grey.shade200, indent: 16, endIndent: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: widget.products.length,
              separatorBuilder: (_, __) => Divider(
                  height: 1, color: Colors.grey.shade100),
              itemBuilder: (context, i) {
                final p = widget.products[i];
                final qty = p['quantity'] as int? ?? 0;
                final numberOfSkus = p['numberOfSkus'] as int? ?? 0;
                final unitsPerSku = p['unitsPerSku'] as int? ?? 0;
                final docId = p['__docId'] as String?;
                return ListTile(
                  dense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      p['imageUrl'] as String? ?? '',
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 40,
                        height: 40,
                        color: _purple.withOpacity(0.1),
                        child: const Icon(Icons.image_not_supported,
                            size: 18, color: Colors.grey),
                      ),
                    ),
                  ),
                  title: Text(
                    p['name'] as String? ?? '-',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    'ID: ${p['pid'] ?? '-'}  ·  Exp: ${p['expiredate'] ?? '-'}',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle, color: Colors.red),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          if (docId == null) return;
                          int newSkus = numberOfSkus - 1;
                          if (newSkus < 0) return;
                          int newQty = newSkus * unitsPerSku;
                          FirebaseFirestore.instance
                              .collection('users')
                              .doc(FirebaseAuth.instance.currentUser!.uid)
                              .collection('products')
                              .doc(docId)
                              .update({
                            'numberOfSkus': newSkus,
                            'quantity': newQty,
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('$numberOfSkus Boxes',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 12)),
                          Text('$qty units',
                              style: TextStyle(
                                  color: Colors.grey.shade600, fontSize: 10)),
                        ],
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: Colors.green),
                         padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          if (docId == null) return;
                          int newSkus = numberOfSkus + 1;
                          int newQty = newSkus * unitsPerSku;
                          FirebaseFirestore.instance
                              .collection('users')
                              .doc(FirebaseAuth.instance.currentUser!.uid)
                              .collection('products')
                              .doc(docId)
                              .update({
                            'numberOfSkus': newSkus,
                            'quantity': newQty,
                          });
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
