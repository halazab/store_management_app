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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Maintenance Hub', style: TextStyle(color: Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<MaintenanceJob>>(
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
              return Center(child: Text('No maintenance jobs', style: TextStyle(color: Colors.grey[600])));
            }
            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final job = items[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 15.0),
                  child: _buildMaintenanceListItem(context, job),
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
                title: const Text('Add Maintenance Job'),
                content: SingleChildScrollView(
                  child: Column(children: [
                    TextField(controller: _customer, decoration: const InputDecoration(labelText: 'Customer name')),
                    TextField(controller: _model, decoration: const InputDecoration(labelText: 'Computer model')),
                    TextField(controller: _issue, decoration: const InputDecoration(labelText: 'Reported issue')),
                  ]),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  TextButton(
                      onPressed: () async {
                        try {
                          final job = await _api.addMaintenanceJob(
                            // create minimal MaintenanceJob map
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
                      child: const Text('Add'))
                ],
              );
            },
          );

          if (result == true) _refresh();
        },
        label: const Text('Add Job'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildMaintenanceListItem(BuildContext context, MaintenanceJob job) {
    Color statusColor;
    switch (job.status.toString().split('.').last) {
      case 'Completed':
        statusColor = Colors.green;
        break;
      case 'InProgress':
        statusColor = Colors.orange;
        break;
      case 'Pending':
        statusColor = Colors.blue;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.grey[100],
                  ),
                  child: Center(child: Icon(Icons.computer, color: Colors.grey[400], size: 40)),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(job.computerModel, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 5),
                      Text('Entry Date: ${job.dateReported.toLocal().toString().split(' ')[0]}', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                      if (job.status == MaintenanceStatus.Completed && job.dateCompleted != null)
                        Text('Completion Date: ${job.dateCompleted!.toLocal().toString().split(' ')[0]}', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: statusColor.withOpacity(0.2), borderRadius: BorderRadius.circular(5)),
                      child: Text(job.status.toString().split('.').last, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
            if (job.notes != null) ...[
              const SizedBox(height: 10),
              Align(alignment: Alignment.bottomRight, child: Text('Notes: ${job.notes}', style: TextStyle(fontSize: 14, color: Colors.grey[700], fontStyle: FontStyle.italic))),
            ]
          ],
        ),
      ),
    );
  }
}