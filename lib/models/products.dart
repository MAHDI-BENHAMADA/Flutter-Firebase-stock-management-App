class Product {
  final String name;
  final String pid;
  final int quantity;
  final int numberOfSkus;
  final int unitsPerSku;
  final double price;
  final String category;
  final String imageUrl;
  final String expiredate;

  Product({
    required this.name,
    required this.quantity,
    required this.numberOfSkus,
    required this.unitsPerSku,
    required this.price,
    required this.category,
    required this.imageUrl,
    required this.pid,
    required this.expiredate,
  });
}
