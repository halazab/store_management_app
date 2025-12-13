import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:computer_shop_app/services/auth_service.dart';
import 'package:computer_shop_app/screens/add_computer_screen.dart';
import 'package:computer_shop_app/screens/sold_items_screen.dart';
import 'package:computer_shop_app/screens/computer_detail_screen.dart';

class SalesListScreen extends StatefulWidget {
  const SalesListScreen({Key? key}) : super(key: key);

  @override
  State<SalesListScreen> createState() => _SalesListScreenState();
}

class _SalesListScreenState extends State<SalesListScreen> {
  final AuthService _authService = AuthService();
  late Future<List<Map<String, dynamic>>> _salesFuture;

  @override
  void initState() {
    super.initState();
    _refreshSales();
  }

  void _refreshSales() {
    setState(() {
      _salesFuture = _fetchSalesAndSoldItems();
    });
  }

  /// Fetch available computer sales and sold-item snapshots and merge them
  Future<List<Map<String, dynamic>>> _fetchSalesAndSoldItems() async {
    final List<Map<String, dynamic>> combined = [];

    try {
      final sales = await _authService.getComputerSales();
      combined.addAll(sales);
    } catch (e) {
      // ignore, will try to still fetch sold items
      print('Error loading computer sales: $e');
    }

    try {
      final token = await _authService.getToken();
      if (token != null) {
        final uri = Uri.parse('${_authService.baseUrl}/sold-items/');
        final response = await http.get(uri, headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        });

        if (response.statusCode == 200) {
          final List<dynamic> soldData = json.decode(response.body);
          // Convert sold item snapshots into the same shape used by the list
          final soldAsComputers = soldData.map<Map<String, dynamic>>((item) {
            return {
              'id': item['id'],
              'model': item['model'] ?? item['computer']?.toString() ?? 'Sold Item',
              'specs': item['specs'] ?? '',
              'price': item['sold_price'] ?? item['price'] ?? 0,
              'quantity': 1,
              'status': 'Sold',
              'sold_at': item['sold_at'],
              // mark it so detail screen can choose how to display
              'is_sold_snapshot': true,
            };
          }).toList();

          // Append sold items after current inventory
          combined.addAll(soldAsComputers);
        }
      }
    } catch (e) {
      print('Error fetching sold items: $e');
    }

    return combined;
  }

  Future<void> _navigateToAddScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddComputerScreen()),
    );

    if (result == true) {
      _refreshSales();
    }
  }

  Future<void> _navigateToDetailScreen(Map<String, dynamic> computer) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ComputerDetailScreen(computer: computer),
      ),
    );

    if (result == true) {
      _refreshSales();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Computers for Sale'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt, color: Colors.black),
            tooltip: 'Sold items',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SoldItemsScreen()),
              );
            },
          ),
        ],
        titleTextStyle: const TextStyle(
          color: Colors.black,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddScreen,
        backgroundColor: const Color(0xFF003399),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Computer', style: TextStyle(color: Colors.white)),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refreshSales(),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _salesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading sales',
                      style: TextStyle(color: Colors.grey[800], fontSize: 16),
                    ),
                    TextButton(
                      onPressed: _refreshSales,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            final sales = snapshot.data ?? [];

            if (sales.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No computers for sale yet',
                      style: TextStyle(color: Colors.grey[600], fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap details to add your first computer',
                      style: TextStyle(color: Colors.grey[500], fontSize: 14),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sales.length,
              itemBuilder: (context, index) {
                final computer = sales[index];
                return _buildComputerCard(computer);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildComputerCard(Map<String, dynamic> computer) {
    final currencyFormat = NumberFormat.currency(symbol: 'ETB ', decimalDigits: 2);
    // Ensure price is a numeric type before formatting (backend may send string)
    final priceRaw = computer['price'];
    final double priceValue = priceRaw is String
        ? double.tryParse(priceRaw) ?? 0.0
        : (priceRaw is num ? priceRaw.toDouble() : 0.0);

    final status = computer['status'] ?? 'available';
    final isAvailable = status.toLowerCase() == 'available';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToDetailScreen(computer),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.computer, size: 40, color: Color(0xFF003399)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            computer['model'] ?? 'Unknown Model',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isAvailable ? Colors.green[50] : Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isAvailable ? Colors.green : Colors.red,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: isAvailable ? Colors.green[700] : Colors.red[700],
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      computer['specs'] ?? 'No specs',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          currencyFormat.format(priceValue),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF003399),
                          ),
                        ),
                        Text(
                          'Qty: ${computer['quantity'] ?? 0}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}