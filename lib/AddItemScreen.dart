import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wa_inventory/models/products.dart';
import 'package:wa_inventory/Services/cloudinary_service.dart';

class AddProductForm extends StatefulWidget {
  const AddProductForm({super.key});

  @override
  _AddProductFormState createState() => _AddProductFormState();
}

class _AddProductFormState extends State<AddProductForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _distributorController = TextEditingController();
  final _categoryController = TextEditingController();
  final _pidController = TextEditingController();
  final _expiredateController = TextEditingController();
  late File _pickedImage; // Use File for selected image

  late ImagePicker _imagePicker;
  late FirebaseFirestore _firestore;
  User? user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _imagePicker = ImagePicker();
    _pickedImage = File('');
    _firestore = FirebaseFirestore.instance;
  }

  Future<void> _showImageSourceActionSheet(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
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
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedImage =
        await _imagePicker.pickImage(source: source);

    if (pickedImage != null) {
      setState(() {
        _pickedImage = File(pickedImage.path);
      });
    }
  }

  Future<void> _addProductToFirestore(Product newProduct) async {
    try {
      // Upload image to Cloudinary
      final String imageUrl = await CloudinaryService.uploadImage(_pickedImage);

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
      print('Error adding product: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding product: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(107, 59, 225, 1),
        title: const Text(
          "Add Items",
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const SizedBox(
                height: 30,
              ),
              Center(
                child: InkWell(
                  onTap: () => _showImageSourceActionSheet(context),
                  child: Container(
                    alignment: Alignment.center,
                    height: 150.0,
                    width: 150.0,
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: const Color.fromRGBO(107, 59, 225, 1)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: _pickedImage.path.isEmpty
                        ? const Icon(Icons.camera_alt,
                            size: 60.0, color: Color.fromRGBO(107, 59, 225, 1))
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(
                              _pickedImage, // Use the File object here
                              width: 150.0,
                              height: 150.0,
                              fit: BoxFit.cover,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 30.0),
              SingleChildScrollView(
                  child: Column(children: [
                TextFormField(
                  controller: _nameController,
                  cursorColor: const Color.fromRGBO(107, 59, 225, 1),
                  decoration: const InputDecoration(
                      labelText: "Name",
                      labelStyle:
                          TextStyle(color: Color.fromRGBO(107, 59, 225, 1)),
                      focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: Color.fromRGBO(107, 59, 225, 1))),
                      enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: Color.fromRGBO(107, 59, 225, 1)))),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16.0),
                TextFormField(
                  controller: _pidController,
                  cursorColor: const Color.fromRGBO(107, 59, 225, 1),
                  decoration: const InputDecoration(
                      labelText: "Product Id",
                      labelStyle:
                          TextStyle(color: Color.fromRGBO(107, 59, 225, 1)),
                      focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: Color.fromRGBO(107, 59, 225, 1))),
                      enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: Color.fromRGBO(107, 59, 225, 1)))),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter product Id';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16.0),
                TextFormField(
                  controller: _expiredateController,
                  cursorColor: const Color.fromRGBO(107, 59, 225, 1),
                  decoration: const InputDecoration(
                      labelText: "Expire Date",
                      labelStyle:
                          TextStyle(color: Color.fromRGBO(107, 59, 225, 1)),
                      focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: Color.fromRGBO(107, 59, 225, 1))),
                      enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: Color.fromRGBO(107, 59, 225, 1)))),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter expire date';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16.0),
                TextFormField(
                  controller: _quantityController,
                  cursorColor: const Color.fromRGBO(107, 59, 225, 1),
                  decoration: const InputDecoration(
                      labelText: "Quantity",
                      labelStyle:
                          TextStyle(color: Color.fromRGBO(107, 59, 225, 1)),
                      focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: Color.fromRGBO(107, 59, 225, 1))),
                      enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: Color.fromRGBO(107, 59, 225, 1)))),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a quantity';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16.0),
                TextFormField(
                  controller: _priceController,
                  cursorColor: const Color.fromRGBO(107, 59, 225, 1),
                  decoration: const InputDecoration(
                      labelText: "Price",
                      labelStyle:
                          TextStyle(color: Color.fromRGBO(107, 59, 225, 1)),
                      focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: Color.fromRGBO(107, 59, 225, 1))),
                      enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: Color.fromRGBO(107, 59, 225, 1)))),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a price';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16.0),
                TextFormField(
                  controller: _distributorController,
                  cursorColor: const Color.fromRGBO(107, 59, 225, 1),
                  decoration: const InputDecoration(
                      labelText: "Distributer",
                      labelStyle:
                          TextStyle(color: Color.fromRGBO(107, 59, 225, 1)),
                      focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: Color.fromRGBO(107, 59, 225, 1))),
                      enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: Color.fromRGBO(107, 59, 225, 1)))),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a distributor';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16.0),
                TextFormField(
                  controller: _categoryController,
                  cursorColor: const Color.fromRGBO(107, 59, 225, 1),
                  decoration: const InputDecoration(
                      labelText: "Category",
                      labelStyle:
                          TextStyle(color: Color.fromRGBO(107, 59, 225, 1)),
                      focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: Color.fromRGBO(107, 59, 225, 1))),
                      enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: Color.fromRGBO(107, 59, 225, 1)))),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a category';
                    }
                    return null;
                  },
                ),
              ])),
              const SizedBox(height: 16.0),
              ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      if (_pickedImage.path.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select an image'),
                          ),
                        );
                        return;
                      }

                      Product newProduct = Product(
                        name: _nameController.text,
                        pid: _pidController.text,
                        quantity: int.parse(_quantityController.text),
                        price: double.parse(_priceController.text),
                        distributor: _distributorController.text,
                        category: _categoryController.text,
                        expiredate: _expiredateController.text,
                        imageUrl: _pickedImage.path, // Use _pickedImage path
                      );

                      await _addProductToFirestore(newProduct);

                      // Only clear fields after successful upload
                      _nameController.clear();
                      _quantityController.clear();
                      _priceController.clear();
                      _distributorController.clear();
                      _categoryController.clear();
                      _pidController.clear();
                      _expiredateController.clear();
                      setState(() {
                        _pickedImage = File(''); // Clear the picked image
                      });
                    }
                  },
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.all<Color>(
                        const Color.fromRGBO(107, 59, 225, 1)),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(10.0),
                    child: Text(
                      'Add',
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.white,
                      ),
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
