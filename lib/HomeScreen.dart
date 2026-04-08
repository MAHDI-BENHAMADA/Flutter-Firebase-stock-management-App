import 'dart:async';
import 'dart:ui';
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

class _HomeBody extends StatefulWidget {
  const _HomeBody();

  @override
  State<_HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<_HomeBody> {
  static const Color _purple = Color.fromRGBO(107, 59, 225, 1);
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SearChBar(
            onQueryChanged: (query) {
              setState(() {
                _searchQuery = query;
              });
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF7F6FC),
      body: SafeArea(
        child: Column(
          children: [
            header,
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
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


            // If searching, render a flat list of matching products immediately under the header
            if (_searchQuery.isNotEmpty) {
              final queryLower = _searchQuery.toLowerCase();
              final searchResults = docs.where((doc) {
                final matchName = ((doc.data() as Map<String, dynamic>)['name'] as String?)
                        ?.toLowerCase()
                        .contains(queryLower) ?? false;
                return matchName;
              }).map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return {...data, '__docId': doc.id};
              }).toList();

              return CustomScrollView(
                slivers: [
                  if (searchResults.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Center(
                            child: Text('No results for "$_searchQuery"',
                                style: const TextStyle(color: Colors.grey))),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final p = searchResults[index];
                            final qty = p['quantity'] as int? ?? 0;
                            final docId = p['__docId'] as String;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.03),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    )
                                  ],
                                ),
                                child: _ProductTile(
                                  product: p,
                                  qty: qty,
                                  docId: docId,
                                ),
                              ),
                            );
                          },
                          childCount: searchResults.length,
                        ),
                      ),
                    ),
                ],
              );
            }

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
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inventory_2_outlined,
                        size: 80, color: _purple.withOpacity(0.2)),
                    const SizedBox(height: 16),
                    const Text('No products yet',
                        style: TextStyle(fontSize: 18, color: Colors.grey)),
                    const SizedBox(height: 6),
                    Text('Add products from the Add Item tab',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade400)),
                  ],
                ),
              );
            }

            final categories = grouped.entries.toList()
              ..sort((a, b) => a.key.compareTo(b.key));

            final totalSkus = docs.length;
            final totalStock = docs.fold<int>(
              0,
              (s, doc) =>
                  s + ((doc.data() as Map)['quantity'] as int? ?? 0),
            );
            final lowCount = categories.where((e) {
              final qty = e.value
                  .fold<int>(0, (s, p) => s + (p['quantity'] as int? ?? 0));
              return qty < kLowStockThreshold;
            }).length;

            return RefreshIndicator(
              color: _purple,
              onRefresh: () async {
                await Future.delayed(const Duration(milliseconds: 400));
              },
              child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _SummaryHeader(
                    totalSkus: totalSkus,
                    totalStock: totalStock,
                    lowCount: lowCount,
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.0,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final entry = categories[i];
                        final totalQty = entry.value.fold<int>(
                            0, (s, p) => s + (p['quantity'] as int? ?? 0));
                        return _CategoryGridTile(
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
            ),
          );
          },
        ),
      ),
     ],
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
        color: Colors.white.withValues(alpha: 0.25),
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
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}

// ── Category card ──────────────────────────────────────────────────────────────

// ── Category Grid Tile ─────────────────────────────────────────────────────────

class _CategoryGridTile extends StatelessWidget {
  final String categoryName;
  final List<Map<String, dynamic>> products;
  final int totalQuantity;

  const _CategoryGridTile({
    required this.categoryName,
    required this.products,
    required this.totalQuantity,
  });

  Color get _stockColor {
    if (totalQuantity < kLowStockThreshold) return Colors.red.shade400;
    if (totalQuantity < 15) return Colors.orange.shade400;
    return Colors.green.shade500;
  }

  String get _stockLabel {
    if (totalQuantity < kLowStockThreshold) return 'Low Stock';
    if (totalQuantity < 15) return 'Medium';
    return 'In Stock';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CategoryProductsScreen(
              categoryName: categoryName,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(107, 59, 225, 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.category_rounded,
                    color: Color.fromRGBO(107, 59, 225, 1),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _stockColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _stockLabel,
                    style: TextStyle(
                      color: _stockColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  categoryName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF1A1A2E),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${products.length} product${products.length != 1 ? 's' : ''}',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  '$totalQuantity total units',
                  style: TextStyle(color: _stockColor, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Category Products Screen (live stream) ────────────────────────────────────

class CategoryProductsScreen extends StatefulWidget {
  final String categoryName;

  const CategoryProductsScreen({
    super.key,
    required this.categoryName,
  });

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  static const Color _purple = Color.fromRGBO(107, 59, 225, 1);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryName),
        backgroundColor: _purple,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('products')
            .where('category', isEqualTo: widget.categoryName)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _purple));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(child: Text('No items in this category.'));
          }

          final products = docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {...data, '__docId': doc.id};
          }).toList();

          return RefreshIndicator(
            color: _purple,
            onRefresh: () async {
              await Future.delayed(const Duration(milliseconds: 300));
            },
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              itemCount: products.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: Colors.grey.shade200),
              itemBuilder: (context, i) {
                final p = products[i];
                final qty = p['quantity'] as int? ?? 0;
                final docId = p['__docId'] as String;
                return _ProductTile(
                  product: p,
                  qty: qty,
                  docId: docId,
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ── Product tile (Static layout opening Overlay) ──────────────────────────────

class _ProductTile extends StatelessWidget {
  final Map<String, dynamic> product;
  final int qty;
  final String docId;

  static const Color _purple = Color.fromRGBO(107, 59, 225, 1);

  const _ProductTile({
    required this.product,
    required this.qty,
    required this.docId,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        showGeneralDialog(
          context: context,
          barrierDismissible: true,
          barrierLabel: 'Dismiss',
          barrierColor: Colors.black.withOpacity(0.1),
          transitionDuration: const Duration(milliseconds: 200),
          pageBuilder: (context, animation, secondaryAnimation) {
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
              child: _ProductDetailsOverlay(
                product: product,
                docId: docId,
              ),
            );
          },
        );
      },
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            product['imageUrl'] as String? ?? '',
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
          product['name'] as String? ?? '-',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'ID: ${product['pid'] ?? '-'}  ·  Exp: ${product['expiredate'] ?? '-'}',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
      ),
    );
  }
}

// ── Product Details Overlay ──────────────────────────────────────────────────

class _ProductDetailsOverlay extends StatefulWidget {
  final Map<String, dynamic> product;
  final String docId;

  const _ProductDetailsOverlay({
    required this.product,
    required this.docId,
  });

  @override
  State<_ProductDetailsOverlay> createState() => _ProductDetailsOverlayState();
}

class _ProductDetailsOverlayState extends State<_ProductDetailsOverlay> {
  static const Color _purple = Color.fromRGBO(107, 59, 225, 1);

  late TextEditingController _skuController;
  Timer? _debounce;
  bool _saving = false;
  int? _pendingSkus;

  @override
  void initState() {
    super.initState();
    final currentSkus = widget.product['numberOfSkus'] as int? ?? 0;
    _skuController = TextEditingController(text: '$currentSkus');
  }

  @override
  void dispose() {
    if (_debounce != null && _debounce!.isActive) {
      _debounce!.cancel();
      if (_pendingSkus != null) {
        _writeToFirebase(_pendingSkus!);
      }
    }
    _skuController.dispose();
    super.dispose();
  }

  void _scheduleWrite(int newSkus) {
    _debounce?.cancel();
    setState(() {
      _saving = true;
      _pendingSkus = newSkus;
    });
    _debounce = Timer(const Duration(seconds: 3), () {
      _writeToFirebase(newSkus);
    });
  }

  Future<void> _writeToFirebase(int newSkus) async {
    final unitsPerSku = widget.product['unitsPerSku'] as int? ?? 0;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .collection('products')
          .doc(widget.docId)
          .update({
        'numberOfSkus': newSkus,
        'quantity': newSkus * unitsPerSku,
      });
    } catch (e) {
      // Ignore
    }
    _pendingSkus = null;
    if (mounted) setState(() => _saving = false);
  }

  void _onMinusTap() {
    final current = int.tryParse(_skuController.text) ?? 0;
    final newVal = (current - 1).clamp(0, 99999);
    _skuController.text = '$newVal';
    _scheduleWrite(newVal);
  }

  void _onPlusTap() {
    final current = int.tryParse(_skuController.text) ?? 0;
    final newVal = current + 1;
    _skuController.text = '$newVal';
    _scheduleWrite(newVal);
  }

  void _onTextChanged(String value) {
    final parsed = int.tryParse(value);
    if (parsed == null || parsed < 0) return;
    _scheduleWrite(parsed);
  }

  Future<void> _deleteProduct() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text(
            'Are you sure you want to delete ${widget.product['name']}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _debounce?.cancel();
      _pendingSkus = null;
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('products')
            .doc(widget.docId)
            .delete();

        if (mounted) {
          Navigator.pop(context); // Close the overlay
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${widget.product['name']} deleted')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final parsedSkus = int.tryParse(_skuController.text) ?? 0;
    final unitsPerSku = widget.product['unitsPerSku'] as int? ?? 0;
    final calculatedUnits = parsedSkus * unitsPerSku;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      widget.product['imageUrl'] as String? ?? '',
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey.shade100,
                        child: const Icon(Icons.inventory_2_outlined,
                            size: 24, color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.product['name'] as String? ?? 'Product Name',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.product['category'] ?? '-'}  ·  Price: \$${widget.product['price'] ?? 0}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(height: 1),
              const SizedBox(height: 24),

              // Stock Adjustments
              const Text(
                'Adjust SDKs (Boxes)',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _AdjustButton(
                    icon: Icons.remove,
                    color: Colors.red.shade400,
                    bgColor: Colors.red.shade50,
                    onTap: _onMinusTap,
                  ),
                  const SizedBox(width: 16),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 70,
                        height: 40,
                        child: TextField(
                          controller: _skuController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          onChanged: _onTextChanged,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 8),
                            filled: true,
                            fillColor: _saving
                                ? Colors.orange.shade50
                                : Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _saving ? 'saving...' : '$calculatedUnits total units',
                        style: TextStyle(
                          fontSize: 12,
                          color: _saving
                              ? Colors.orange.shade600
                              : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  _AdjustButton(
                    icon: Icons.add,
                    color: Colors.green.shade500,
                    bgColor: Colors.green.shade50,
                    onTap: _onPlusTap,
                  ),
                ],
              ),

              const SizedBox(height: 32),
              
              // Actions
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _deleteProduct,
                    icon: Icon(Icons.delete_outline,
                        size: 20, color: Colors.grey.shade400),
                    label: Text(
                      'Delete',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _purple,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Done',
                        style: TextStyle(color: Colors.white, fontSize: 15)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdjustButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _AdjustButton({
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Icon(icon, size: 24, color: color),
      ),
    );
  }
}

// ── Sell / Stock Adjust bottom sheet ──────────────────────────────────────────

class _SellStockSheet extends StatefulWidget {
  final String docId;
  final String productName;
  final int currentQty;

  const _SellStockSheet({
    required this.docId,
    required this.productName,
    required this.currentQty,
  });

  @override
  State<_SellStockSheet> createState() => _SellStockSheetState();
}

class _SellStockSheetState extends State<_SellStockSheet> {
  static const Color _purple = Color.fromRGBO(107, 59, 225, 1);

  /// 'sell' = decrease by amount sold, 'set' = set exact new value
  String _mode = 'sell';
  final _amountController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  int get _parsedAmount => int.tryParse(_amountController.text.trim()) ?? 0;

  int get _previewQty {
    if (_mode == 'sell') {
      return (widget.currentQty - _parsedAmount).clamp(0, 999999);
    } else {
      return _parsedAmount.clamp(0, 999999);
    }
  }

  Future<void> _confirm() async {
    final amount = _parsedAmount;
    if (amount <= 0 && _mode == 'sell') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid quantity sold')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('products')
          .doc(widget.docId);

      final newQty = _previewQty;

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) throw Exception('Product not found');
        tx.update(ref, {'quantity': newQty});
      });

      // Log the sale transaction if mode is 'sell'
      if (_mode == 'sell') {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('transactions')
            .add({
          'productId': widget.docId,
          'quantitySold': amount,
          'saleDate': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_mode == 'sell'
                ? 'Sold $amount units of ${widget.productName}'
                : 'Stock set to $newQty units'),
            backgroundColor: Colors.green.shade600,
          ),
        );
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
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
            const SizedBox(height: 18),

            // Title
            Text(
              widget.productName,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E)),
            ),
            const SizedBox(height: 4),
            Text(
              'Current stock: ${widget.currentQty} units',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 20),

            // Mode toggle
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  _ModeTab(
                    label: '🛒 Sell (decrease)',
                    selected: _mode == 'sell',
                    onTap: () => setState(() => _mode = 'sell'),
                  ),
                  _ModeTab(
                    label: '✏️ Set exact stock',
                    selected: _mode == 'set',
                    onTap: () => setState(() => _mode = 'set'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Input
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              autofocus: true,
              cursorColor: _purple,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: _mode == 'sell'
                    ? 'Units sold'
                    : 'New stock quantity',
                labelStyle: const TextStyle(color: _purple),
                hintText: _mode == 'sell' ? 'e.g. 3' : 'e.g. 50',
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: _purple, width: 2),
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey.shade300),
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                ),
              ),
            ),

            // Live preview
            if (_amountController.text.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _previewQty < kLowStockThreshold
                      ? Colors.red.shade50
                      : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _previewQty < kLowStockThreshold
                        ? Colors.red.shade200
                        : Colors.green.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _previewQty < kLowStockThreshold
                          ? Icons.warning_amber_rounded
                          : Icons.check_circle_outline,
                      size: 16,
                      color: _previewQty < kLowStockThreshold
                          ? Colors.red.shade500
                          : Colors.green.shade600,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'New stock will be: $_previewQty units',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _previewQty < kLowStockThreshold
                            ? Colors.red.shade600
                            : Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Confirm button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _confirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _purple,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(
                        _mode == 'sell' ? 'Confirm Sale' : 'Update Stock',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
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
              fontSize: 12,
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
