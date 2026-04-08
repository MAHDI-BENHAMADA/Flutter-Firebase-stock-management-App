import 'dart:io';

import 'package:wa_inventory/Services/cloudinary_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import "package:wa_inventory/Services/database.dart";
import "package:wa_inventory/models/products.dart";

class EditScreen extends StatefulWidget {
  final Product cuProduct;
  const EditScreen(this.cuProduct, {super.key});
  @override
  _EditScreenState createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _numberOfSkusController;
  late TextEditingController _unitsPerSkuController;
  late TextEditingController _priceController;
  late TextEditingController _categoryController;
  late TextEditingController _pidController;
  late TextEditingController _expiredateController;
  late File _pickedImage;
  final FirestoreService _firestoreService = FirestoreService();

  late ImagePicker _imagePicker;
  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.cuProduct.name);
    _numberOfSkusController =
        TextEditingController(text: widget.cuProduct.numberOfSkus.toString());
    _unitsPerSkuController =
        TextEditingController(text: widget.cuProduct.unitsPerSku.toString());
    _priceController =
        TextEditingController(text: widget.cuProduct.price.toString());
    _categoryController =
        TextEditingController(text: widget.cuProduct.category.toString());
    _pidController =
        TextEditingController(text: widget.cuProduct.pid.toString());
    _expiredateController =
        TextEditingController(text: widget.cuProduct.expiredate.toString());

    _imagePicker = ImagePicker();
    _pickedImage = File(widget.cuProduct.imageUrl);
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

  @override
  void dispose() {
    _nameController.dispose();
    _numberOfSkusController.dispose();
    _unitsPerSkuController.dispose();
    _priceController.dispose();
    _pidController.dispose();
    _categoryController.dispose();
    _expiredateController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(107, 59, 225, 1),
        title: Row(
          children: [
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.23,
            ),
            const Text(
              "Edit Item",
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
          ],
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
              TextFormField(
                controller: _nameController,
                cursorColor: const Color.fromRGBO(107, 59, 225, 1),
                decoration: const InputDecoration(
                    labelText: "Name",
                    labelStyle:
                        TextStyle(color: Color.fromRGBO(107, 59, 225, 1)),
                    focusedBorder: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: Color.fromRGBO(107, 59, 225, 1))),
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
                        borderSide:
                            BorderSide(color: Color.fromRGBO(107, 59, 225, 1))),
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
                        borderSide:
                            BorderSide(color: Color.fromRGBO(107, 59, 225, 1))),
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
                controller: _numberOfSkusController,
                decoration: const InputDecoration(
                    labelText: "Number of Boxes (SKUs)",
                    labelStyle:
                        TextStyle(color: Color.fromRGBO(107, 59, 225, 1)),
                    focusedBorder: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: Color.fromRGBO(107, 59, 225, 1))),
                    enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                            color: Color.fromRGBO(107, 59, 225, 1)))),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter number of boxes';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _unitsPerSkuController,
                decoration: const InputDecoration(
                    labelText: "Units per Box",
                    labelStyle:
                        TextStyle(color: Color.fromRGBO(107, 59, 225, 1)),
                    focusedBorder: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: Color.fromRGBO(107, 59, 225, 1))),
                    enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                            color: Color.fromRGBO(107, 59, 225, 1)))),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter units per box';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                    labelText: "Price",
                    labelStyle:
                        TextStyle(color: Color.fromRGBO(107, 59, 225, 1)),
                    focusedBorder: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: Color.fromRGBO(107, 59, 225, 1))),
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
                controller: _categoryController,
                decoration: const InputDecoration(
                    labelText: "Category",
                    labelStyle:
                        TextStyle(color: Color.fromRGBO(107, 59, 225, 1)),
                    focusedBorder: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: Color.fromRGBO(107, 59, 225, 1))),
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
              const SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    Map<String, dynamic> updatedProductData = {};
                    // {
                    //   'name': _nameController.text,
                    //   'quantity': int.parse(_quantityController.text),
                    //   'price': double.parse(_priceController.text),
                    //   'distributor': _distributorController.text,
                    //   'category': _categoryController.text,
                    //   'expiredate': _expiredateController.text,
                    //   'pid': _pidController.text,
                    // };
                    if (_nameController.text != widget.cuProduct.name) {
                      updatedProductData['name'] = _nameController.text;
                    }
                    if (_numberOfSkusController.text !=
                        widget.cuProduct.numberOfSkus.toString()) {
                      updatedProductData['numberOfSkus'] =
                          int.parse(_numberOfSkusController.text);
                    }
                    if (_unitsPerSkuController.text !=
                        widget.cuProduct.unitsPerSku.toString()) {
                      updatedProductData['unitsPerSku'] =
                          int.parse(_unitsPerSkuController.text);
                    }
                    
                    int newSkus = int.parse(_numberOfSkusController.text);
                    int newUnitsPerSku = int.parse(_unitsPerSkuController.text);
                    updatedProductData['quantity'] = newSkus * newUnitsPerSku;

                    if (_priceController.text !=
                        widget.cuProduct.price.toString()) {
                      updatedProductData['price'] =
                          double.parse(_priceController.text);
                    }
                    if (_categoryController.text != widget.cuProduct.category) {
                      updatedProductData['category'] = _categoryController.text;
                    }
                    if (_expiredateController.text !=
                        widget.cuProduct.expiredate) {
                      updatedProductData['expiredate'] =
                          _expiredateController.text;
                    }
                    if (_pidController.text != widget.cuProduct.pid) {
                      updatedProductData['pid'] = _pidController.text;
                    }

                    // Upload the new image if selected
                    if (_pickedImage.path != widget.cuProduct.imageUrl &&
                        _pickedImage.existsSync()) {
                      final String imageUrl =
                          await CloudinaryService.uploadImage(_pickedImage);
                      updatedProductData['imageUrl'] = imageUrl;
                    }

                    try {
                      await _firestoreService.updateProduct(
                          widget.cuProduct.pid, updatedProductData);
                      Product updatedProduct = Product(
                        name: _nameController.text,
                        quantity: int.parse(_numberOfSkusController.text) * int.parse(_unitsPerSkuController.text),
                        numberOfSkus: int.parse(_numberOfSkusController.text),
                        unitsPerSku: int.parse(_unitsPerSkuController.text),
                        price: double.parse(_priceController.text),
                        category: _categoryController.text,
                        imageUrl: _pickedImage.path,
                        expiredate: _expiredateController.text,
                        pid: _pidController.text,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Product updated successfully'),
                        ),
                      );
                      Navigator.pop(context, updatedProduct);
                    } catch (error) {
                      print('Error updating product: $error');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Error updating product'),
                        ),
                      );
                    }

                    _nameController.clear();
                    _numberOfSkusController.clear();
                    _unitsPerSkuController.clear();
                    _priceController.clear();
                    _categoryController.clear();
                    setState(() {
                      _pickedImage = File(''); // Clear the picked image
                    });
                  }
                },
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all<Color>(
                    const Color.fromRGBO(107, 59, 225, 1),
                  ),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(10.0),
                  child: Text(
                    'Update',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
