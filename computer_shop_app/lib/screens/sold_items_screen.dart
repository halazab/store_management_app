import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:computer_shop_app/services/api_service.dart';

class SoldItemsScreen extends StatefulWidget {
  const SoldItemsScreen({Key? key}) : super(key: key);

  @override
  State<SoldItemsScreen> createState() => _SoldItemsScreenState();
}

class _SoldItemsScreenState extends State<SoldItemsScreen> {
  final ApiService _api = ApiService();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.getSoldItems();
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: 'ETB ', decimalDigits: 2);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sold Items'),
        backgroundColor: const Color(0xFF003399),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return Center(child: Text('No sold items yet', style: TextStyle(color: Colors.grey[600])));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final it = items[i];
              final soldAt = it['sold_at'] != null ? DateTime.parse(it['sold_at']) : null;
              // Safely parse sold_price which may come as String or num
              final soldPriceRaw = it['sold_price'] ?? it['price'] ?? 0;
              double soldPriceValue;
              if (soldPriceRaw is String) {
                soldPriceValue = double.tryParse(soldPriceRaw) ?? 0.0;
              } else if (soldPriceRaw is num) {
                soldPriceValue = soldPriceRaw.toDouble();
              } else {
                soldPriceValue = 0.0;
              }

              return Card(
                child: ListTile(
                  leading: const Icon(Icons.receipt_long),
                  title: Text(it['model'] ?? 'Unknown'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (it['specs'] != null) Text(it['specs']),
                      if (soldAt != null) Text(DateFormat('yyyy-MM-dd HH:mm').format(soldAt)),
                    ],
                  ),
                  trailing: Text(currency.format(soldPriceValue)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
