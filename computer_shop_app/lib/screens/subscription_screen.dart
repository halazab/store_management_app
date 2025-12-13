import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:computer_shop_app/services/auth_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _loading = true;
  bool _loadingPayment = false;
  String? _selectedPlan;
  final TextEditingController _couponController = TextEditingController();
  bool _validatingCoupon = false;
  Map<String, dynamic>? _couponData;
  List<Map<String, dynamic>> _plans = [];
  
  @override
  void initState() {
    super.initState();
    _loadPricing();
  }
  
  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }
  
  Future<void> _loadPricing() async {
    setState(() => _loading = true);
    
    final authService = AuthService();
    final pricing = await authService.getSubscriptionPricing();
    
    if (mounted) {
      setState(() {
        _plans = pricing;
        _loading = false;
        
        // Auto-select first plan if available
        if (_plans.isNotEmpty) {
          _selectedPlan = _plans[0]['id'].toString();
        }
      });
    }
  }

  Future<void> _validateCoupon() async {
    final couponCode = _couponController.text.trim();
    if (couponCode.isEmpty) {
      setState(() => _couponData = null);
      return;
    }

    if (_selectedPlan == null) {
      _showError("Please select a plan first");
      return;
    }

    setState(() => _validatingCoupon = true);

    final selectedPlanData = _plans.firstWhere((plan) => plan['id'].toString() == _selectedPlan);
    final amount = selectedPlanData['price'] as int;

    final authService = AuthService();
    final result = await authService.validateCoupon(couponCode, amount);

    setState(() {
      _validatingCoupon = false;
      _couponData = result;
    });

    if (mounted) {
      if (result['valid'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Coupon applied!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Invalid coupon'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handlePayment() async {
    if (_selectedPlan == null) {
      _showError("Please select a plan");
      return;
    }

    final selectedPlanData = _plans.firstWhere((plan) => plan['id'].toString() == _selectedPlan);
    final amount = selectedPlanData['price'] as int;

    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString("email") ?? "";
    final couponCode = _couponController.text.trim();

    setState(() => _loadingPayment = true);

    final authService = AuthService();
    final paymentUrl = await authService.createChapaPayment(
      amount: amount,
      email: email,
      txRef: "TXN-${DateTime.now().millisecondsSinceEpoch}",
      couponCode: couponCode.isNotEmpty ? couponCode : null,
      frontendUrl: kIsWeb ? "${Uri.base.origin}/#" : null,
    );

    setState(() => _loadingPayment = false);

    if (paymentUrl != null) {
      final uri = Uri.parse(paymentUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment page opened. Please complete the payment and return to the app.'),
              duration: Duration(seconds: 5),
            ),
          );
        }
      } else {
        _showError("Could not open payment page.");
      }
    } else {
      _showError("Failed to initiate payment. Try again.");
    }
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  int _getFinalAmount() {
    if (_selectedPlan == null) return 0;
    final selectedPlanData = _plans.firstWhere((plan) => plan['id'].toString() == _selectedPlan);
    final amount = selectedPlanData['price'] as int;
    
    if (_couponData != null && _couponData!['valid'] == true) {
      return (_couponData!['final_amount'] as num).toInt();
    }
    return amount;
  }

  Widget _buildPlanCard(Map<String, dynamic> plan) {
    final isSelected = _selectedPlan == plan['id'].toString();

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPlan = plan['id'].toString();
          _couponData = null;
        });
        if (_couponController.text.isNotEmpty) {
          _validateCoupon();
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF003399).withOpacity(0.1) : Colors.white,
          border: Border.all(
            color: isSelected ? const Color(0xFF003399) : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan['name'],
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? const Color(0xFF003399) : Colors.black87,
                    ),
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle, color: Color(0xFF003399)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${plan['price']} ETB',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF003399),
              ),
            ),
            if (plan['description'] != null && plan['description'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                plan['description'],
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Your Plan'),
        backgroundColor: const Color(0xFF003399),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select a subscription plan',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF003399),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Plans
                  ..._plans.map((plan) => _buildPlanCard(plan)).toList(),
                  
                  const SizedBox(height: 24),
                  
                  // Coupon Code Section
                  const Text(
                    'Have a coupon code?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _couponController,
                          onChanged: (_) => setState(() => _couponData = null),
                          decoration: InputDecoration(
                            hintText: 'Enter coupon code',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _validatingCoupon ? null : _validateCoupon,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF003399),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                        ),
                        child: _validatingCoupon
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Apply',
                                style: TextStyle(color: Colors.white),
                              ),
                      ),
                    ],
                  ),
                  
                  // Coupon Success Message
                  if (_couponData != null && _couponData!['valid'] == true) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '✓ ${_couponData!['message']}',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Discount: ${_couponData!['discount_amount']} ETB',
                            style: const TextStyle(color: Colors.green),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 32),
                  
                  // Payment Summary
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Original Amount:',
                              style: TextStyle(fontSize: 16),
                            ),
                            Text(
                              '${_selectedPlan != null ? _plans.firstWhere((p) => p['id'].toString() == _selectedPlan)['price'] : 0} ETB',
                              style: TextStyle(
                                fontSize: 16,
                                decoration: _couponData != null && _couponData!['valid'] == true
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ],
                        ),
                        if (_couponData != null && _couponData!['valid'] == true) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Final Amount:',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF003399),
                                ),
                              ),
                              Text(
                                '${_getFinalAmount()} ETB',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF003399),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Continue Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: (_loadingPayment || _selectedPlan == null) ? null : _handlePayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF003399),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _loadingPayment
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Continue to Payment',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
