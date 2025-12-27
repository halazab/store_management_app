import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../providers/subscription_provider.dart';
import '../../services/subscription_service.dart';
import '../../models/subscription_model.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class SubscriptionWallScreen extends StatefulWidget {
  const SubscriptionWallScreen({super.key});

  @override
  State<SubscriptionWallScreen> createState() => _SubscriptionWallScreenState();
}

class _SubscriptionWallScreenState extends State<SubscriptionWallScreen> {
  @override
  void initState() {
   super.initState();
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
    subscriptionProvider.loadPlans();
  }

  Future<void> _handleUpgrade(SubscriptionPlan plan) async {
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
    
    final result = await subscriptionProvider.initializePayment(plan.id);

    if (!mounted) return;

    if (result != null && result['success'] == true) {
      final checkoutUrl = result['checkout_url'];
      final txRef = result['tx_ref'];
      
      // Show WebView for Chapa payment
      final paymentResult = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PaymentWebView(
            checkoutUrl: checkoutUrl,
            txRef: txRef,
          ),
        ),
      );

      // Refresh subscription status after payment
      if (paymentResult == true && mounted) {
        await subscriptionProvider.refreshSubscription();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(subscriptionProvider.errorMessage ?? 'Failed to initiate payment'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context);
    final currencyFormatter = NumberFormat.currency(symbol: 'ETB ',decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Status
            if (subscriptionProvider.subscription != null) ...[
              Card(
                color: subscriptionProvider.hasActiveSubscription
                    ? Colors.green.shade50
                    : Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            subscriptionProvider.hasActiveSubscription
                                ? Icons.check_circle
                                : Icons.warning,
                            color: subscriptionProvider.hasActiveSubscription
                                ? Colors.green
                                : Colors.red,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            subscriptionProvider.hasActiveSubscription
                                ? 'Active Subscription'
                                : 'Subscription Expired',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (subscriptionProvider.hasActiveSubscription) ...[
                        Text(
                          subscriptionProvider.isTrial
                              ? 'Trial Period'
                              : 'Premium Plan',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${subscriptionProvider.daysRemaining} days remaining',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Plans
            Text(
              'Choose Your Plan',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

            if (subscriptionProvider.plans.isEmpty)
              const Center(child: CircularProgressIndicator())
            else
              ...subscriptionProvider.plans.map((plan) {
                final isPopular = plan.id == 'yearly';
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: isPopular
                        ? BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          )
                        : BorderSide.none,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isPopular)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'BEST VALUE',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        if (isPopular) const SizedBox(height: 12),
                        Text(
                          plan.name,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              currencyFormatter.format(plan.price),
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                            ),
                            const SizedBox(width: 4),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '/ ${plan.duration} days',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ...plan.features.map((feature) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(child: Text(feature)),
                                ],
                              ),
                            )),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: subscriptionProvider.isLoading
                                ? null
                                : () => _handleUpgrade(plan),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isPopular
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                            child: subscriptionProvider.isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Subscribe Now'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),

            const SizedBox(height: 24),

            // Payment Info
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700),
                        const SizedBox(width: 12),
                        Text(
                          'Payment Information',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '• Secure payment via Chapa\n'
                      '• Cancel anytime\n'
                      '• Instant activation\n'
                      '• Ethiopian Birr (ETB) only',
                      style: TextStyle(color: Colors.blue.shade800),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PaymentWebView extends StatefulWidget {
  final String checkoutUrl;
  final String txRef;

  const PaymentWebView({
    super.key,
    required this.checkoutUrl,
    required this.txRef,
  });

  @override
  State<PaymentWebView> createState() => _PaymentWebViewState();
}

class _PaymentWebViewState extends State<PaymentWebView> {
  late WebViewController _controller;
  bool _isLoading = true;
  bool _isVerifying = false;
  Timer? _pollingTimer;
  bool _hasStartedPolling = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (url) async {
            setState(() {
              _isLoading = false;
            });
            
            print('WebView URL: $url'); // Debug logging
            
            final lowerUrl = url.toLowerCase();
            
            // Check if payment completed based on Chapa success patterns
            // More aggressive detection for receipt page
            final isSuccess = url.contains('checkout.chapa.co/success') || 
                url.contains('/payment/success') ||
                url.contains('status=success') ||
                url.contains('/receipt') ||
                lowerUrl.contains('receipt') ||  // Case insensitive
                url.contains('tx_ref=') ||
                url.contains('reference=') ||
                lowerUrl.contains('paid') ||  // Detect "Paid" status
                url.contains('chapa.co') && lowerUrl.contains('success');
            
            if (isSuccess) {
              print('Payment success detected, verifying...'); // Debug logging
              await _verifyPayment();
            } 
            // Start automatic polling after user reaches checkout page
            else if (url.contains('checkout.chapa.co') && !_hasStartedPolling) {
              print('Starting automatic polling...'); // Debug logging
              _startAutomaticPolling();
            }
            // Handle failed payment
            else if (url.contains('payment/failed') || 
                     url.contains('status=failed') ||
                     url.contains('cancelled')) {
              _stopPolling();
              if (!mounted) return;
              Navigator.of(context).pop(false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Payment was cancelled or failed. Please try again.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  void _startAutomaticPolling() {
    if (_hasStartedPolling) return;
    
    _hasStartedPolling = true;
    
    // Wait only 5 seconds before starting to poll (faster detection)
    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted || _isVerifying) return;
      
      // Poll every 2 seconds (more frequent checks)
      _pollingTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
        if (!mounted || _isVerifying) {
          _stopPolling();
          return;
        }
        
        await _checkPaymentStatus();
      });
    });
  }

  Future<void> _checkPaymentStatus() async {
    if (_isVerifying) return;
    
    try {
      final subscriptionService = SubscriptionService();
      // Try to verify - if payment is successful, this will return true
      final success = await subscriptionService.verifyAndActivateSubscription(widget.txRef);
      
      if (success && mounted) {
        _stopPolling();
        setState(() {
          _isVerifying = true;
        });
        
        // Small delay to show the verifying UI
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (!mounted) return;
        
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment successful! Subscription activated.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Payment not yet completed or verification failed
      // Continue polling silently
    }
  }

  Future<void> _verifyPayment() async {
    if (_isVerifying) return;
    
    _stopPolling();
    
    setState(() {
      _isVerifying = true;
    });

    try {
      final subscriptionService = SubscriptionService();
      final success = await subscriptionService.verifyAndActivateSubscription(widget.txRef);
      
      if (!mounted) return;
      
      Navigator.of(context).pop(success);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success 
              ? 'Payment successful! Subscription activated.'
              : 'Payment not yet completed. Please complete your payment first.'),
          backgroundColor: success ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isVerifying = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification failed: ${e.toString()}'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 5),
        ),
      );
      
      // Restart polling if manual verification failed
      if (!_hasStartedPolling) {
        _startAutomaticPolling();
      }
    }
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Payment'),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
          if (_isVerifying)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Verifying payment...',
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
