import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/inventory_provider.dart';
import '../../models/computer_model.dart';

class ComputerFormScreen extends StatefulWidget {
  final Computer? computer;

  const ComputerFormScreen({super.key, this.computer});

  @override
  State<ComputerFormScreen> createState() => _ComputerFormScreenState();
}

class _ComputerFormScreenState extends State<ComputerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _processorController = TextEditingController();
  final _ramController = TextEditingController();
  final _storageController = TextEditingController();
  final _gpuController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedCategory = 'Desktop';
  final List<String> _categories = ['Desktop', 'Laptop', 'Server', 'Workstation'];

  @override
  void initState() {
    super.initState();
    if (widget.computer != null) {
      _nameController.text = widget.computer!.name;
      _brandController.text = widget.computer!.brand;
      _processorController.text = widget.computer!.processor;
      _ramController.text = widget.computer!.ram;
      _storageController.text = widget.computer!.storage;
      _gpuController.text = widget.computer!.gpu;
      _priceController.text = widget.computer!.price.toString();
      _quantityController.text = widget.computer!.quantity.toString();
      _descriptionController.text = widget.computer!.description;
      _selectedCategory = widget.computer!.category;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _processorController.dispose();
    _ramController.dispose();
    _storageController.dispose();
    _gpuController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }



  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final inventoryProvider = Provider.of<InventoryProvider>(context, listen: false);

    final computer = Computer(
      userId: '',
      name: _nameController.text.trim(),
      brand: _brandController.text.trim(),
      category: _selectedCategory,
      processor: _processorController.text.trim(),
      ram: _ramController.text.trim(),
      storage: _storageController.text.trim(),
      gpu: _gpuController.text.trim(),
      price: double.parse(_priceController.text),
      quantity: int.parse(_quantityController.text),
      description: _descriptionController.text.trim(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    bool success;
    if (widget.computer != null) {
      success = await inventoryProvider.updateComputer(
        widget.computer!.id!,
        computer,
      );
    } else {
      success = await inventoryProvider.addComputer(computer);
    }

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.computer != null
              ? 'Computer updated successfully'
              : 'Computer added successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(inventoryProvider.errorMessage ?? 'Failed to save computer'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Computer'),
        content: const Text('Are you sure you want to delete this computer?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final inventoryProvider = Provider.of<InventoryProvider>(context, listen: false);
    final success = await inventoryProvider.deleteComputer(widget.computer!.id!);

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Computer deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.computer != null ? 'Edit Computer' : 'Add Computer'),
        actions: widget.computer != null
            ? [
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: _handleDelete,
                ),
              ]
            : null,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Computer Name'),
              validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(labelText: 'Category'),
              items: _categories.map((cat) {
                return DropdownMenuItem(value: cat, child: Text(cat));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value!;
                });
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _brandController,
              decoration: const InputDecoration(labelText: 'Brand'),
              validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _processorController,
              decoration: const InputDecoration(labelText: 'Processor'),
              validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _ramController,
              decoration: const InputDecoration(labelText: 'RAM (e.g., 16GB)'),
              validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _storageController,
              decoration: const InputDecoration(labelText: 'Storage (e.g., 512GB SSD)'),
              validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _gpuController,
              decoration: const InputDecoration(labelText: 'GPU (Optional)'),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: 'Price (ETB)',
                prefixText: 'ETB ',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                if (v?.isEmpty ?? true) return 'Required';
                if (double.tryParse(v!) == null) return 'Invalid number';
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _quantityController,
              decoration: const InputDecoration(labelText: 'Quantity'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                if (v?.isEmpty ?? true) return 'Required';
                if (int.tryParse(v!) == null) return 'Invalid number';
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description (Optional)'),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _handleSave,
              child: Text(widget.computer != null ? 'Update Computer' : 'Add Computer'),
            ),
          ],
        ),
      ),
    );
  }
}
