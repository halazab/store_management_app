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
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          // Header actions bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Computers for Sale',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.list_alt_rounded, color: Color(0xFF003399)),
                  tooltip: 'Sold items',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SoldItemsScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _refreshSales(),
              color: const Color(0xFF003399),
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
                            'Tap + to add your first computer',
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
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddScreen,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Computer'),
        elevation: 4,
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
    final isSold = status.toLowerCase() == 'sold';
    final isMaintenance = status.toLowerCase() == 'maintenance';

    // Status color and gradient
    Color statusColor;
    List<Color> statusGradient;
    IconData statusIcon;

    if (isAvailable) {
      statusColor = const Color(0xFF10B981);
      statusGradient = [const Color(0xFF10B981), const Color(0xFF059669)];
      statusIcon = Icons.check_circle;
    } else if (isSold) {
      statusColor = const Color(0xFFEF4444);
      statusGradient = [const Color(0xFFEF4444), const Color(0xFFDC2626)];
      statusIcon = Icons.shopping_bag;
    } else if (isMaintenance) {
      statusColor = const Color(0xFFF59E0B);
      statusGradient = [const Color(0xFFF59E0B), const Color(0xFFD97706)];
      statusIcon = Icons.build_circle;
    } else {
      statusColor = Colors.grey;
      statusGradient = [Colors.grey, Colors.grey.shade700];
      statusIcon = Icons.info;
    }

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      shadowColor: Colors.black.withOpacity(0.1),
      child: InkWell(
        onTap: () => _navigateToDetailScreen(computer),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Computer icon with gradient background
              Hero(
                tag: 'computer-${computer['id']}',
                child: Container(
                  width: 85,
                  height: 85,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF003399), Color(0xFF4169E1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF003399).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.computer_rounded,
                    size: 45,
                    color: Colors.white,
                  ),
                ),
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
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Enhanced status badge with gradient
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: statusGradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: statusColor.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                statusIcon,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                status.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      computer['specs'] ?? 'No specs',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF003399).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            currencyFormat.format(priceValue),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF003399),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 16,
                                color: Colors.grey[700],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${computer['quantity'] ?? 0}',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
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