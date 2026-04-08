import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:wa_inventory/Services/database.dart';

class CategoriesManagementScreen extends StatefulWidget {
  const CategoriesManagementScreen({super.key});

  @override
  State<CategoriesManagementScreen> createState() =>
      _CategoriesManagementScreenState();
}

class _CategoriesManagementScreenState
    extends State<CategoriesManagementScreen> {
  final FirestoreService _db = FirestoreService();
  final TextEditingController _nameController = TextEditingController();
  final Color _purple = const Color.fromRGBO(107, 59, 225, 1);

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _showAddSheet() {
    _nameController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'New Category',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _purple,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              autofocus: true,
              cursorColor: _purple,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Category name',
                labelStyle: TextStyle(color: _purple),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: _purple),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: _purple.withOpacity(0.5)),
                ),
              ),
              onSubmitted: (_) => _submitCategory(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitCategory,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _purple,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Add Category',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitCategory() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    await _db.addCategory(name);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _confirmDelete(String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text(
            'Delete "$name"? Products already tagged with this category will keep the label.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _db.deleteCategory(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _purple,
        centerTitle: true,
        title: const Text(
          'Manage Categories',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSheet,
        backgroundColor: _purple,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Category',
            style: TextStyle(color: Colors.white)),
      ),
      body: StreamBuilder<List<String>>(
        stream: _db.getCategoriesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: _purple),
            );
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final categories = snapshot.data ?? [];

          if (categories.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.category_outlined,
                      size: 72, color: _purple.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  Text(
                    'No categories yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the button below to add your first category',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final cat = categories[index];
              return Slidable(
                key: ValueKey(cat),
                endActionPane: ActionPane(
                  motion: const DrawerMotion(),
                  children: [
                    SlidableAction(
                      onPressed: (_) => _confirmDelete(cat),
                      backgroundColor: Colors.red.shade400,
                      foregroundColor: Colors.white,
                      icon: Icons.delete_outline,
                      label: 'Delete',
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(12),
                      ),
                    ),
                  ],
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _purple.withOpacity(0.2)),
                    boxShadow: [
                      BoxShadow(
                        color: _purple.withOpacity(0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _purple.withOpacity(0.12),
                      child: Text(
                        cat[0].toUpperCase(),
                        style: TextStyle(
                          color: _purple,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      cat,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    trailing: Icon(
                      Icons.swipe_left,
                      color: Colors.grey.shade400,
                      size: 18,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
