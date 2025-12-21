import 'package:flutter/material.dart';
import 'package:computer_shop_app/services/api_service.dart';
import 'package:computer_shop_app/models/maintenance_job.dart';

class MaintenanceListScreen extends StatefulWidget {
  const MaintenanceListScreen({Key? key}) : super(key: key);

  @override
  State<MaintenanceListScreen> createState() => _MaintenanceListScreenState();
}

class _MaintenanceListScreenState extends State<MaintenanceListScreen> {
  final ApiService _api = ApiService();
  late Future<List<MaintenanceJob>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.getMaintenanceJobs();
  }

  Future<void> _refresh() async {
    setState(() => _future = _api.getMaintenanceJobs());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: const Color(0xFF003399),
        child: FutureBuilder<List<MaintenanceJob>>(
          future: _future,
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
                      'Error: ${snapshot.error}',
                      style: TextStyle(color: Colors.grey[800]),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _refresh,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }
            final items = snapshot.data ?? [];
            if (items.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.build_circle_outlined, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No maintenance jobs',
                      style: TextStyle(color: Colors.grey[600], fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap + to add a new job',
                      style: TextStyle(color: Colors.grey[500], fontSize: 14),
                    ),
                  ],
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final job = items[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: _buildMaintenanceCard(context, job),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // Open add maintenance job dialog
          final result = await showDialog<bool>(
            context: context,
            builder: (ctx) {
              final _customer = TextEditingController();
              final _model = TextEditingController();
              final _issue = TextEditingController();
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: const Text(
                  'Add Maintenance Job',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: _customer,
                        decoration: const InputDecoration(
                          labelText: 'Customer name',
                          prefixIcon: Icon(Icons.person),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _model,
                        decoration: const InputDecoration(
                          labelText: 'Computer model',
                          prefixIcon: Icon(Icons.computer),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _issue,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Reported issue',
                          prefixIcon: Icon(Icons.report_problem),
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (_customer.text.isEmpty || _model.text.isEmpty || _issue.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please fill all fields')),
                        );
                        return;
                      }
                      try {
                        await _api.addMaintenanceJob(
                          MaintenanceJob(
                            id: null,
                            customerName: _customer.text,
                            computerModel: _model.text,
                            reportedIssue: _issue.text,
                            dateReported: DateTime.now(),
                            status: MaintenanceStatus.Pending,
                          ),
                        );
                        Navigator.pop(ctx, true);
                      } catch (e) {
                        Navigator.pop(ctx, false);
                      }
                    },
                    child: const Text('Add Job'),
                  ),
                ],
              );
            },
          );

          if (result == true) _refresh();
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Job'),
        elevation: 4,
      ),
    );
  }

  Widget _buildMaintenanceCard(BuildContext context, MaintenanceJob job) {
    Color statusColor;
    List<Color> statusGradient;
    IconData statusIcon;
    String statusText = job.status.toString().split('.').last;

    switch (statusText) {
      case 'Completed':
        statusColor = const Color(0xFF10B981);
        statusGradient = [const Color(0xFF10B981), const Color(0xFF059669)];
        statusIcon = Icons.check_circle;
        break;
      case 'InProgress':
        statusColor = const Color(0xFFF59E0B);
        statusGradient = [const Color(0xFFF59E0B), const Color(0xFFD97706)];
        statusIcon = Icons.autorenew;
        statusText = 'In Progress';
        break;
      case 'Pending':
        statusColor = const Color(0xFF3B82F6);
        statusGradient = [const Color(0xFF3B82F6), const Color(0xFF2563EB)];
        statusIcon = Icons.schedule;
        break;
      case 'Cancelled':
        statusColor = const Color(0xFFEF4444);
        statusGradient = [const Color(0xFFEF4444), const Color(0xFFDC2626)];
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.grey;
        statusGradient = [Colors.grey, Colors.grey.shade700];
        statusIcon = Icons.info;
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      shadowColor: Colors.black.withOpacity(0.1),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon with gradient background
            Container(
              width: 85,
              height: 85,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: statusGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.build_circle_rounded,
                color: Colors.white,
                size: 45,
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
                          job.computerModel,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
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
                              statusText.toUpperCase(),
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
                  Row(
                    children: [
                      const Icon(Icons.person, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        job.customerName,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        'Entry: ${job.dateReported.toLocal().toString().split(' ')[0]}',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  if (job.status == MaintenanceStatus.Completed && job.dateCompleted != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.check_circle, size: 14, color: Colors.green),
                        const SizedBox(width: 4),
                        Text(
                          'Done: ${job.dateCompleted!.toLocal().toString().split(' ')[0]}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (job.notes != null && job.notes!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.note, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              job.notes!,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}