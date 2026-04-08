import 'package:flutter/material.dart';
import "package:wa_inventory/ItemsCard.dart";
import 'package:wa_inventory/Services/database.dart';
import 'package:wa_inventory/models/products.dart';

class SearChBar extends StatefulWidget {
  const SearChBar({super.key});

  @override
  State<SearChBar> createState() => _SearChBarState();
}

class _SearChBarState extends State<SearChBar> {
  final TextEditingController _searchController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  List<Product> searchResults = [];

  List<Product> filteredResults = [];

  @override
  void initState() {
    super.initState();
  }

  Future<void> _fetchProducts() async {
    print("fetching&&&*(((((())))))");
    try {
      List<Product> products = await _firestoreService.getProducts();
      setState(() {
        filteredResults = products;
      });
    } catch (e) {
      print("Error fetching products: $e");
    }
  }

  void performSearch(String value) {
    _fetchProducts();
    setState(() {
      searchResults = filteredResults
          .where(
              (item) => item.name.toLowerCase().contains(value.toLowerCase()))
          .map((item) => Product(
              name: item.name,
              price: item.price,
              quantity: item.quantity,
              numberOfSkus: item.numberOfSkus,
              unitsPerSku: item.unitsPerSku,
              pid: item.pid,
              expiredate: item.expiredate,
              category: item.category,
              imageUrl: item.imageUrl))
          .toList();
      print("found products $searchResults");
    });
  }

  void _showSearchResults(BuildContext context) {
    showSearch(
      context: context,
      delegate: ProductSearchDelegate(searchResults),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04), // Note: using withOpacity is standard here
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextFormField(
        controller: _searchController,
        onChanged: (value) {
          performSearch(value);
          setState(() {}); // to optionally refresh suffix icon logic
        },
        onFieldSubmitted: (_) => _showSearchResults(context),
        cursorColor: const Color.fromRGBO(107, 59, 225, 1),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: "Search inventory...",
          hintStyle: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 15,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Colors.grey,
            size: 22,
          ),
          suffixIcon: GestureDetector(
            onTap: () => _showSearchResults(context),
            child: Container(
              margin: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color.fromRGBO(107, 59, 225, 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                color: Color.fromRGBO(107, 59, 225, 1),
                size: 20,
              ),
            ),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: Color.fromRGBO(107, 59, 225, 0.4),
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

class ProductSearchDelegate extends SearchDelegate<Product> {
  final List<Product> searchResults;

  ProductSearchDelegate(this.searchResults);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          searchResults.clear();
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final filteredResults = searchResults
        .where((item) => item.name.toLowerCase().contains(query.toLowerCase()))
        .toList();

    return ListView.builder(
      itemCount: filteredResults.length,
      itemBuilder: (context, index) {
        final item = filteredResults[index];
        return SizedBox(width: 200, child: ItmeCard(item));
      },
    );
  }

  bool isLoading = false;
  @override
  Widget buildSuggestions(BuildContext context) {
    final filteredResults = searchResults
        .where((item) => item.name.toLowerCase().contains(query.toLowerCase()))
        .toList();

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: isLoading
          ? Center(
              child: Container(
                alignment: Alignment.center,
                child: const CircularProgressIndicator(),
              ),
            )
          : SingleChildScrollView(
              child: SizedBox(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(
                      height: 12,
                    ),
                    filteredResults.isEmpty
                        ? const Center(
                            child: Text(" product is Empty"),
                          )
                        : Padding(
                            padding: const EdgeInsets.all(
                              12,
                            ),
                            child: ListView.builder(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                primary: false,
                                itemCount: filteredResults.length,
                                itemBuilder: (ctx, index) {
                                  Product singleProduct =
                                      filteredResults[index];
                                  return SizedBox(
                                      width: 200,
                                      child: ItmeCard(singleProduct));
                                }),
                          ),
                    const SizedBox(
                      height: 12.0,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
