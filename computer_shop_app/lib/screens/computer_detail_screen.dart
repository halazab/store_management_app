import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:computer_shop_app/services/auth_service.dart';
import 'package:computer_shop_app/screens/edit_computer_screen.dart';
import 'package:computer_shop_app/services/api_service.dart';
import 'package:computer_shop_app/models/computer_sale.dart';

class ComputerDetailScreen extends StatefulWidget {
  final Map<String, dynamic> computer;

  const ComputerDetailScreen({Key? key, required this.computer}) : super(key: key);

  @override
  State<ComputerDetailScreen> createState() => _ComputerDetailScreenState();
}

class _ComputerDetailScreenState extends State<ComputerDetailScreen> {
  late Map<String, dynamic> computer;
  final ApiService _api = ApiService();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    computer = Map<String, dynamic>.from(widget.computer);
  }

  Future<void> _deleteComputer(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Computer'),
        content: const Text('Are you sure you want to delete this computer?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    final authService = AuthService();
    final success = await authService.deleteComputerSale(computer['id']);

    if (!context.mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Computer deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true); // Return true to refresh list
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete computer'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _editComputer(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditComputerScreen(computer: computer),
      ),
    );

    if (result == true && context.mounted) {
      // When edit returns true the list refreshes; also close this detail to keep behavior
      Navigator.pop(context, true);
    }
  }

  Future<void> _sellN(BuildContext context, int n) async {
    if (n <= 0) return;
    final available = (computer['quantity'] ?? 0) as int;
    if (available < n) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Not enough stock. Available: $available'), backgroundColor: Colors.red),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sell $n Unit${n > 1 ? 's' : ''}'),
        content: Text('Are you sure you want to sell $n unit${n > 1 ? 's' : ''}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      final id = computer['id'].toString();
      final resp = await _api.sellUnits(id, n);
      final updatedComputer = resp['computer'] ?? resp;
      setState(() {
        computer = Map<String, dynamic>.from(updatedComputer);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sale recorded — inventory updated'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to sell units: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _sellOne(BuildContext context) async {
    await _sellN(context, 1);
  }

  Future<void> _sendToMaintenance(BuildContext context) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) {
        final _customerCtrl = TextEditingController();
        final _issueCtrl = TextEditingController();
        final _notesCtrl = TextEditingController();
        return AlertDialog(
          title: const Text('Send to Maintenance'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(controller: _customerCtrl, decoration: const InputDecoration(labelText: 'Customer name')),
                TextField(controller: _issueCtrl, decoration: const InputDecoration(labelText: 'Reported issue')),
                TextField(controller: _notesCtrl, decoration: const InputDecoration(labelText: 'Notes (optional)')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, {}), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, {
                'customer_name': _customerCtrl.text,
                'reported_issue': _issueCtrl.text,
                'notes': _notesCtrl.text,
              }),
              child: const Text('Send'),
            ),
          ],
        );
      },
    );

    if (result == null || result.isEmpty) return;

    setState(() => _loading = true);
    try {
      final id = computer['id'].toString();
      final resp = await _api.sendToMaintenance(id,
          customerName: result['customer_name'], reportedIssue: result['reported_issue'], notes: result['notes']);

      // Update local computer state using returned computer data (if present)
      final updatedComputer = resp['computer'] ?? resp;
      setState(() {
        computer = Map<String, dynamic>.from(updatedComputer);
        // store maintenance job id for quick return
        if (resp['maintenance_job'] != null && resp['maintenance_job']['id'] != null) {
          computer['maintenance_job_id'] = resp['maintenance_job']['id'];
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Computer sent to maintenance'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send to maintenance: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _returnFromMaintenance(BuildContext context) async {
    final jobId = computer['maintenance_job_id']?.toString();
    if (jobId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No maintenance job id available'), backgroundColor: Colors.orange),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Return from Maintenance'),
        content: const Text('Mark this maintenance job as completed and return the computer to inventory?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      final resp = await _api.returnFromMaintenance(jobId);
      final updatedComputer = resp['computer'] ?? computer;
      setState(() {
        computer = Map<String, dynamic>.from(updatedComputer);
        computer.remove('maintenance_job_id');
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Computer returned to inventory'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to return from maintenance: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: 'ETB ', decimalDigits: 2);
    // Ensure price is numeric before formatting (backend may return price as a string)
    final priceRaw = computer['price'];
    final double priceValue = priceRaw is String
        ? double.tryParse(priceRaw) ?? 0.0
        : (priceRaw is num ? priceRaw.toDouble() : 0.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Computer Details'),
        backgroundColor: const Color(0xFF003399),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _editComputer(context),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _deleteComputer(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _getStatusColor(computer['status']).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _getStatusColor(computer['status']),
                  width: 2,
                ),
              ),
              child: Text(
                (computer['status'] ?? 'available').toUpperCase(),
                style: TextStyle(
                  color: _getStatusColor(computer['status']),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Model
            const Text(
              'Model',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              computer['model'] ?? 'N/A',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF003399),
              ),
            ),
            const SizedBox(height: 24),
            
            // Specifications
            _buildDetailSection(
              'Specifications',
              computer['specs'] ?? 'N/A',
              Icons.description,
            ),
            const SizedBox(height: 20),
            
            // Price
            _buildDetailSection(
              'Price',
              currencyFormat.format(priceValue),
              Icons.attach_money,
            ),
            const SizedBox(height: 20),
            
            // Quantity
            _buildDetailSection(
              'Quantity',
              (computer['quantity'] ?? 1).toString(),
              Icons.inventory,
            ),
            const SizedBox(height: 12),
            if (_loading) const Center(child: CircularProgressIndicator()),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : () => _sellOne(context),
                    icon: const Icon(Icons.point_of_sale),
                    label: const Text('Sell 1'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loading
                        ? null
                        : () async {
                            // show dialog to input N
                            final result = await showDialog<int>(
                              context: context,
                              builder: (ctx) {
                                int qty = 1;
                                return AlertDialog(
                                  title: const Text('Sell N Units'),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextFormField(
                                        initialValue: '1',
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(labelText: 'Quantity to sell'),
                                        onChanged: (v) => qty = int.tryParse(v) ?? 1,
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, 0), child: const Text('Cancel')),
                                    TextButton(onPressed: () => Navigator.pop(ctx, qty), child: const Text('Sell')),
                                  ],
                                );
                              },
                            );
                            if (result != null && result > 0) {
                              await _sellN(context, result);
                            }
                          },
                    icon: const Icon(Icons.sell),
                    label: const Text('Sell N'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Maintenance actions
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loading
                        ? null
                        : () {
                            final status = (computer['status'] ?? '').toString().toLowerCase();
                            if (status == 'maintenance') {
                              _returnFromMaintenance(context);
                            } else {
                              _sendToMaintenance(context);
                            }
                          },
                    icon: Icon(Icons.build),
                    label: Text((computer['status'] ?? '').toString().toLowerCase() == 'maintenance' ? 'Return from Maintenance' : 'Send to Maintenance'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Sale Date
            if (computer['sale_date'] != null)
              _buildDetailSection(
                'Sale Date',
                DateFormat('MMM dd, yyyy').format(DateTime.parse(computer['sale_date'])),
                Icons.calendar_today,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF003399).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF003399)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'available':
        return Colors.green;
      case 'sold':
        return Colors.red;
      case 'maintenance':
        return Colors.orange;
      case 'reserved':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
