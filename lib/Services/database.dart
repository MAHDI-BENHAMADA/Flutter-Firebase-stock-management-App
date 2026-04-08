import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import "package:wa_inventory/models/products.dart";

class DatabaseService {
  final CollectionReference products =
      FirebaseFirestore.instance.collection("products");
}

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? user = FirebaseAuth.instance.currentUser;

  Future<void> _CheckUser() async {}

  Future<List<Product>> getProducts() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(user!.uid)
          .collection('products')
          .get();
      List<Product> products = snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return Product(
            name: data['name'],
            quantity: data['quantity'] ?? 0,
            numberOfSkus: data['numberOfSkus'] ?? 0,
            unitsPerSku: data['unitsPerSku'] ?? 0,
            price: (data['price'] ?? 0).toDouble(),
            category: data['category'],
            imageUrl: data['imageUrl'],
            pid: data['pid'],
            expiredate: data['expiredate']);
      }).toList();
      return products;
    } catch (e) {
      print('Error fetching products: $e');
      return [];
    }
  }

  Future<void> updateProduct(
      String pid, Map<String, dynamic> updatedData) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('users')
          .doc(user!.uid)
          .collection('products')
          .where('pid', isEqualTo: pid)
          .get();
      if (querySnapshot.docs.isNotEmpty) {
        await querySnapshot.docs.first.reference.update(updatedData);
      }
    } catch (error) {
      print("not update");
      rethrow;
    }
  }

  Future<void> deleteProduct(String pid) async {
    try {
      final productsCollection =
          _firestore.collection('users').doc(user!.uid).collection('products');
      final snapshot =
          await productsCollection.where('pid', isEqualTo: pid).get();

      if (snapshot.docs.isNotEmpty) {
        final productDoc = snapshot.docs.first;
        await productDoc.reference.delete();
        print("Product deleted successfully");
      } else {
        print("Product not found");
      }
    } catch (e) {
      print("Error deleting product: $e");
      throw Exception("Error deleting product");
    }
  }

  Future<Product> getProductByPid(String pid) async {
    try {
      print("searching ****************** $pid");
      final querySnapshot = await _firestore
          .collection('users')
          .doc(user!.uid)
          .collection('products')
          .where('pid', isEqualTo: pid)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final documentSnapshot = querySnapshot.docs[0];
        Map<String, dynamic> data = documentSnapshot.data();
        return Product(
          pid: data['pid'] as String,
          name: data['name'] as String,
          quantity: data['quantity'] as int? ?? 0,
          numberOfSkus: data['numberOfSkus'] as int? ?? 0,
          unitsPerSku: data['unitsPerSku'] as int? ?? 0,
          price: (data['price'] as num?)?.toDouble() ?? 0.0,
          category: data['category'] as String,
          imageUrl: data['imageUrl'] as String,
          expiredate: data['expiredate'] as String,
        );
      } else {
        throw Exception("Product with PID $pid not found");
      }
    } catch (e) {
      throw Exception("Error fetching product: $e");
    }
  }

  Future<void> registerTransaction(String productId, int quantitySold) async {
    final transactionsRef = _firestore
        .collection('users')
        .doc(user!.uid)
        .collection('transactions');

    await transactionsRef.add({
      'productId': productId,
      'quantitySold': quantitySold,
      'saleDate': FieldValue.serverTimestamp(),
    });

    // Update product status or other necessary actions
  }

  // ── Category management ────────────────────────────────────────────────

  /// Streams the list of category names for the current user.
  Stream<List<String>> getCategoriesStream() {
    return _firestore
        .collection('users')
        .doc(user!.uid)
        .collection('categories')
        .orderBy('createdAt')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => d['name'] as String).toList());
  }

  /// Adds a new category (ignores duplicates).
  Future<void> addCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    // prevent duplicates (case-insensitive check)
    final existing = await _firestore
        .collection('users')
        .doc(user!.uid)
        .collection('categories')
        .where('name', isEqualTo: trimmed)
        .get();
    if (existing.docs.isNotEmpty) return;
    await _firestore
        .collection('users')
        .doc(user!.uid)
        .collection('categories')
        .add({'name': trimmed, 'createdAt': FieldValue.serverTimestamp()});
  }

  /// Deletes a category by name.
  Future<void> deleteCategory(String name) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(user!.uid)
        .collection('categories')
        .where('name', isEqualTo: name)
        .get();
    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }
}
