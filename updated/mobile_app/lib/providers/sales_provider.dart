import 'package:flutter/material.dart';
import '../models/sale_model.dart';
import '../services/sales_service.dart';

class SalesProvider with ChangeNotifier {
  final SalesService _salesService = SalesService();
  
  List<Sale> _sales = [];
  List<Customer> _customers = [];
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic> _stats = {};

  List<Sale> get sales => _sales;
  List<Customer> get customers => _customers;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic> get stats => _stats;

  SalesProvider() {
    _salesService.getUserSales().listen((sales) {
      _sales = sales;
      notifyListeners();
    });
    _salesService.getCustomers().listen((customers) {
      _customers = customers;
      notifyListeners();
    });
    loadStats();
  }

  Future<void> loadStats() async {
    _stats = await _salesService.getSalesStats();
    notifyListeners();
  }

  Future<bool> createSale(Sale sale) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _salesService.createSale(sale);
      await loadStats();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> cancelSale(String saleId) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _salesService.cancelSale(saleId);
      await loadStats();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> addCustomer(Customer customer) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _salesService.addCustomer(customer);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  String generateSaleNumber() {
    return _salesService.generateSaleNumber();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
