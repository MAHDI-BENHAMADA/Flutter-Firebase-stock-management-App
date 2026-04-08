import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:wa_inventory/NotificationScreen.dart';
import 'package:wa_inventory/SearchBar.dart';

const int kLowStockThreshold = 5;

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _HomeBody();
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody();

  static const Color _purple = Color.fromRGBO(107, 59, 225, 1);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F6FC),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user!.uid)
              .collection('products')
              .snapshots(),
          builder: (context, snapshot) {
            // ── Header (always shown) ──────────────────────────────────────
            final header = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top bar
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(20, 16, 12, 0),
                  child: Row(
                    children: [
                      const Text(
                        'Inventory',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const NotificationPage()),
                        ),
                        icon: const Icon(
                          Icons.notifications_none_outlined,
                          size: 28,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Search bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: const SearChBar(),
                ),
                const SizedBox(height: 16),
              ],
            );

            if (snapshot.connectionState == ConnectionState.waiting) {
              return Column(
                children: [
                  header,
                  const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(color: _purple),
                    ),
                  ),
                ],
              );
            }

            if (snapshot.hasError) {
              return Column(
                children: [
                  header,
                  Expanded(
                      child: Center(
                          child: Text('Error: ${snapshot.error}'))),
                ],
              );
            }

            final docs = snapshot.data?.docs ?? [];

            // Group products by category
            final Map<String, List<Map<String, dynamic>>> grouped = {};
            for (final doc in docs) {
              final data = doc.data() as Map<String, dynamic>;
              final cat =
                  (data['category'] as String?)?.trim() ?? 'Uncategorized';
              grouped
                  .putIfAbsent(cat, () => [])
                  .add({...data, '__docId': doc.id});
            }

            if (grouped.isEmpty) {
              return Column(
                children: [
                  header,
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inventory_2_outlined,
                              size: 80,
                              color: _purple.withOpacity(0.2)),
                          const SizedBox(height: 16),
                          const Text(
                            'No products yet',
                            style: TextStyle(
                                fontSize: 18, color: Colors.grey),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Add products from the Add Item tab',
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade400),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            // Sort categories alphabetically
            final categories = grouped.entries.toList()
              ..sort((a, b) => a.key.compareTo(b.key));

            // Stats
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

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: header),
                SliverToBoxAdapter(
                  child: _SummaryHeader(
                    totalSkus: totalSkus,
                    totalStock: totalStock,
                    lowCount: lowCount,
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final entry = categories[i];
                        final totalQty = entry.value.fold<int>(
                            0, (s, p) => s + (p['quantity'] as int? ?? 0));
                        return _CategoryCard(
                          categoryName: entry.key,
                          products: entry.value,
                          totalQuantity: totalQty,
                        );
                      },
                      childCount: categories.length,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── Summary header ─────────────────────────────────────────────────────────────

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
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color.fromRGBO(107, 59, 225, 1), Color(0xFF9B59B6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color.fromRGBO(107, 59, 225, 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatPill(
              label: 'Total SKUs',
              value: '$totalSkus',
              icon: Icons.inventory_2),
          _divider(),
          _StatPill(
              label: 'Total Units',
              value: '$totalStock',
              icon: Icons.layers),
          _divider(),
          _StatPill(
            label: 'Low Stock',
            value: '$lowCount',
            icon: Icons.warning_amber_rounded,
            valueColor:
                lowCount > 0 ? Colors.yellow.shade200 : Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        height: 36,
        width: 1,
        color: Colors.white.withOpacity(0.25),
      );
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
            style:
                const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}

// ── Category card ──────────────────────────────────────────────────────────────

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

class _CategoryCardState extends State<_CategoryCard> {
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _expanded
              ? _purple.withOpacity(0.35)
              : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: _expanded
                ? _purple.withOpacity(0.08)
                : Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header row
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Stock badge
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: _stockColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
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
                  // Category name + SKU count
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.categoryName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.products.length} product${widget.products.length != 1 ? 's' : ''}',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  // Stock badge + chevron
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
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

          // Expanded product list
          if (_expanded) ...[
            Divider(
                height: 1,
                color: Colors.grey.shade200,
                indent: 16,
                endIndent: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: widget.products.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: Colors.grey.shade100),
              itemBuilder: (context, i) {
                final p = widget.products[i];
                final qty = p['quantity'] as int? ?? 0;
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      p['imageUrl'] as String? ?? '',
                      width: 42,
                      height: 42,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: _purple.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.image_not_supported,
                            size: 18, color: Colors.grey),
                      ),
                    ),
                  ),
                  title: Text(
                    p['name'] as String? ?? '-',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'ID: ${p['pid'] ?? '-'}  ·  Exp: ${p['expiredate'] ?? '-'}',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: qty < kLowStockThreshold
                          ? Colors.red.withOpacity(0.1)
                          : Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$qty units',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: qty < kLowStockThreshold
                            ? Colors.red.shade600
                            : Colors.green.shade700,
                      ),
                    ),
                  ),
                  onTap: () {
                    // Navigate to product detail if available
                  },
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
