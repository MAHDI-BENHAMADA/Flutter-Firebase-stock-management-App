import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:wa_inventory/EditScreen.dart';
import 'package:wa_inventory/models/products.dart' as pmodel;

class ProductDetailPage extends StatefulWidget {
  final pmodel.Product cuproduct;

  const ProductDetailPage(this.cuproduct, {super.key});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  late pmodel.Product _product = widget.cuproduct;

  void _navigateToEditScreen() async {
    final existingProduct = _product;
    final updatedData = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditScreen(existingProduct),
      ),
    );

    if (updatedData != null) {
      setState(() {
        _product = updatedData;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = [
      StockData('Stock In', 123, Colors.green),
      StockData('Stock Out', 567, Colors.red),
      StockData('Running Out', 45678, Colors.yellow),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(107, 59, 225, 1),
        title: const Center(child: Text('Product Detail')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Center(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * .25,
                width: MediaQuery.of(context).size.width * .9,
                child: ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(5)),
                  child: Image.network(
                    _product.imageUrl,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    _product.name,
                    style: const TextStyle(
                        fontSize: 24.0, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: _navigateToEditScreen,
                  icon: const Icon(
                    Icons.edit_note,
                    size: 50,
                    color: Color.fromRGBO(107, 59, 225, 1),
                    semanticLabel: "Edit",
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25.0),
            Center(
              child: Container(
                height: MediaQuery.of(context).size.height * .35,
                width: MediaQuery.of(context).size.width * .85,
                decoration: BoxDecoration(
                    border: Border.all(
                        color: const Color.fromRGBO(107, 59, 225, 1), width: 2),
                    borderRadius: BorderRadius.circular(10)),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    const Text(
                      "Daily Activity",
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline),
                    ),
                    Flexible(
                      child: Row(
                        children: [
                          const SizedBox(width: 20),
                          Flexible(
                            child: SizedBox(
                              height: MediaQuery.of(context).size.height * .25,
                              width: MediaQuery.of(context).size.width * .4,
                              child: PieChart(
                                PieChartData(
                                  sectionsSpace: 2,
                                  centerSpaceRadius: 28,
                                  sections: data
                                      .map(
                                        (item) => PieChartSectionData(
                                          color: item.color,
                                          value: item.value,
                                          title: item.value.toInt().toString(),
                                          radius: 56,
                                          titleStyle: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                            ),
                          ),
                          Flexible(
                            child: _buildLegend(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16.0),
            Text(
              'Price: \$ ${_product.price.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 10.0),
            Text('Expiry Date: ${_product.expiredate}',
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: Colors.red)),
            const SizedBox(height: 10.0),
            Text('Boxes (SKUs): ${_product.numberOfSkus}',
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w500)),
            const SizedBox(height: 10.0),
            Text('Units per Box: ${_product.unitsPerSku}',
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w500)),
            const SizedBox(height: 10.0),
            Text('Available Units: ${_product.quantity}',
                style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w500,
                    color: Colors.green)),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLegendItem('Stock In', Colors.green),
        _buildLegendItem('Stock Out', Colors.red),
        _buildLegendItem('Running Out', Colors.yellow),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16.0,
          height: 16.0,
          color: color,
          margin: const EdgeInsets.only(top: 5.0),
        ),
        const SizedBox(width: 5),
        Text(label),
      ],
    );
  }
}

class StockData {
  final String label;
  final double value;
  final Color color;

  StockData(this.label, this.value, this.color);
}
