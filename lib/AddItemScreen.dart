import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:wa_inventory/CategoriesManagementScreen.dart';
import 'package:wa_inventory/models/products.dart';
import 'package:wa_inventory/Services/cloudinary_service.dart';
import 'package:wa_inventory/Services/database.dart';

class AddProductForm extends StatefulWidget {
  const AddProductForm({super.key});

  @override
  _AddProductFormState createState() => _AddProductFormState();
}

class _AddProductFormState extends State<AddProductForm> {
  static const Color _purple = Color.fromRGBO(107, 59, 225, 1);

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _distributorController = TextEditingController();
  final _pidController = TextEditingController();

  String? _selectedCategory;
  DateTime? _selectedExpireDate;
  File _pickedImage = File('');

  final ImagePicker _imagePicker = ImagePicker();
  late FirebaseFirestore _firestore;
  final FirestoreService _db = FirestoreService();
  User? user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _firestore = FirebaseFirestore.instance;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _distributorController.dispose();
    _pidController.dispose();
    super.dispose();
  }

  // ── Image picking ─────────────────────────────────────────────────────────

  Future<void> _showImageSourceActionSheet() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () {
                _pickImage(ImageSource.gallery);
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Camera'),
              onTap: () {
                _pickImage(ImageSource.camera);
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _imagePicker.pickImage(source: source);
    if (picked != null) {
      setState(() => _pickedImage = File(picked.path));
    }
  }

  // ── Date picker ───────────────────────────────────────────────────────────

  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedExpireDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 20),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _purple,
            onPrimary: Colors.white,
            onSurface: Colors.black87,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedExpireDate = picked);
    }
  }

  String get _formattedExpiry => _selectedExpireDate == null
      ? ''
      : DateFormat('dd / MM / yyyy').format(_selectedExpireDate!);

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _addProductToFirestore(Product newProduct) async {
    try {
      final String imageUrl =
          await CloudinaryService.uploadImage(_pickedImage);

      await _firestore
          .collection('users')
          .doc(user!.uid)
          .collection('products')
          .add({
        'name': newProduct.name,
        'pid': newProduct.pid,
        'quantity': newProduct.quantity,
        'price': newProduct.price,
        'distributor': newProduct.distributor,
        'category': newProduct.category,
        'expiredate': newProduct.expiredate,
        'imageUrl': imageUrl,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product added successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding product: $e')),
      );
    }
  }

  void _clearForm() {
    _nameController.clear();
    _quantityController.clear();
    _priceController.clear();
    _distributorController.clear();
    _pidController.clear();
    setState(() {
      _selectedCategory = null;
      _selectedExpireDate = null;
      _pickedImage = File('');
    });
  }

  // ── UI helpers ────────────────────────────────────────────────────────────

  InputDecoration _fieldDecoration(String label, {Widget? suffix}) =>
      InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _purple),
        suffixIcon: suffix,
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: _purple),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: _purple.withOpacity(0.5)),
        ),
        errorBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.red),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _purple,
        title: const Text(
          'Add Item',
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const SizedBox(height: 20),

              // ── Image picker ──────────────────────────────────────────────
              Center(
                child: InkWell(
                  onTap: _showImageSourceActionSheet,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 150,
                    width: 150,
                    decoration: BoxDecoration(
                      border: Border.all(color: _purple),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _pickedImage.path.isEmpty
                        ? const Icon(Icons.camera_alt,
                            size: 60, color: _purple)
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              _pickedImage,
                              fit: BoxFit.cover,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // ── Name ──────────────────────────────────────────────────────
              TextFormField(
                controller: _nameController,
                cursorColor: _purple,
                decoration: _fieldDecoration('Product Name'),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Please enter a name' : null,
              ),
              const SizedBox(height: 16),

              // ── Product ID ────────────────────────────────────────────────
              TextFormField(
                controller: _pidController,
                cursorColor: _purple,
                decoration: _fieldDecoration('Product ID'),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Please enter a product ID' : null,
              ),
              const SizedBox(height: 16),

              // ── Expiry date (date picker) ──────────────────────────────────
              GestureDetector(
                onTap: _pickExpiryDate,
                child: AbsorbPointer(
                  child: TextFormField(
                    cursorColor: _purple,
                    decoration: _fieldDecoration(
                      'Expiry Date',
                      suffix: const Icon(Icons.calendar_today, color: _purple),
                    ),
                    controller: TextEditingController(text: _formattedExpiry),
                    validator: (_) => _selectedExpireDate == null
                        ? 'Please select an expiry date'
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Quantity ──────────────────────────────────────────────────
              TextFormField(
                controller: _quantityController,
                cursorColor: _purple,
                keyboardType: TextInputType.number,
                decoration: _fieldDecoration('Quantity'),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Please enter a quantity' : null,
              ),
              const SizedBox(height: 16),

              // ── Price ─────────────────────────────────────────────────────
              TextFormField(
                controller: _priceController,
                cursorColor: _purple,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: _fieldDecoration('Price'),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Please enter a price' : null,
              ),
              const SizedBox(height: 16),

              // ── Distributor ───────────────────────────────────────────────
              TextFormField(
                controller: _distributorController,
                cursorColor: _purple,
                decoration: _fieldDecoration('Distributor'),
                validator: (v) => (v == null || v.isEmpty)
                    ? 'Please enter a distributor'
                    : null,
              ),
              const SizedBox(height: 16),

              // ── Category dropdown ─────────────────────────────────────────
              StreamBuilder<List<String>>(
                stream: _db.getCategoriesStream(),
                builder: (context, snapshot) {
                  final categories = snapshot.data ?? [];

                  if (categories.isEmpty) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: _purple.withOpacity(0.5)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'No categories yet — create one first',
                                  style: TextStyle(
                                      color: Colors.grey.shade600),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const CategoriesManagementScreen(),
                                  ),
                                ),
                                icon: const Icon(Icons.add, color: _purple),
                                label: const Text('Add',
                                    style: TextStyle(color: _purple)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }

                  return DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: _fieldDecoration('Category').copyWith(
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.settings, color: _purple, size: 20),
                        tooltip: 'Manage categories',
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const CategoriesManagementScreen(),
                          ),
                        ),
                      ),
                    ),
                    hint: const Text('Select a category'),
                    items: categories
                        .map((c) =>
                            DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (val) =>
                        setState(() => _selectedCategory = val),
                    validator: (v) =>
                        v == null ? 'Please select a category' : null,
                    dropdownColor: Colors.white,
                    iconEnabledColor: _purple,
                  );
                },
              ),
              const SizedBox(height: 28),

              // ── Submit button ─────────────────────────────────────────────
              ElevatedButton(
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;
                  if (_pickedImage.path.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Please select a product image')),
                    );
                    return;
                  }

                  final newProduct = Product(
                    name: _nameController.text.trim(),
                    pid: _pidController.text.trim(),
                    quantity: int.parse(_quantityController.text),
                    price: double.parse(_priceController.text),
                    distributor: _distributorController.text.trim(),
                    category: _selectedCategory!,
                    expiredate: _formattedExpiry,
                    imageUrl: _pickedImage.path,
                  );

                  await _addProductToFirestore(newProduct);
                  _clearForm();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _purple,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Add Product',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
