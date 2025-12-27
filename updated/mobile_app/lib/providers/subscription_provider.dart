import 'package:flutter/material.dart';
import '../models/subscription_model.dart';
import '../services/subscription_service.dart';

class SubscriptionProvider with ChangeNotifier {
  final SubscriptionService _subscriptionService = SubscriptionService();
  
  Subscription? _subscription;
  List<SubscriptionPlan> _plans = [];
  bool _isLoading = false;
  String? _errorMessage;

  Subscription? get subscription => _subscription;
  List<SubscriptionPlan> get plans => _plans;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasActiveSubscription => _subscription?.isActive ?? false;
  bool get isTrial => _subscription?.isTrial ?? false;
  int get daysRemaining => _subscription?.daysRemaining ?? 0;

  SubscriptionProvider() {
    _subscriptionService.getUserSubscription().listen((subscription) {
      _subscription = subscription;
      notifyListeners();
    });
    loadPlans();
  }

  Future<void> loadPlans() async {
    try {
      _isLoading = true;
      notifyListeners();

      _plans = await _subscriptionService.getSubscriptionPlans();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> initializePayment(String planId) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final result = await _subscriptionService.initializePayment(planId);

      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<void> refreshSubscription() async {
    // The subscription updates automatically via the stream listener
    // This method is here for explicit refresh calls if needed
    // The stream listener in the constructor will handle the update
    notifyListeners();
  }

  Future<bool> cancelSubscription() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _subscriptionService.cancelSubscription();

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

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
