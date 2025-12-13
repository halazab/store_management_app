import 'package:flutter/material.dart';
import 'package:computer_shop_app/services/auth_service.dart';

class PaymentSuccessScreen extends StatefulWidget {
  final String? transactionId;
  
  const PaymentSuccessScreen({Key? key, this.transactionId}) : super(key: key);

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen> {
  bool _verifying = true;
  bool _success = false;
  String _message = 'Verifying payment...';

  @override
  void initState() {
    super.initState();
    _verifyPayment();
  }

  Future<void> _verifyPayment() async {
    int retries = 0;
    const maxRetries = 5;
    bool hasSubscription = false;

    while (retries < maxRetries && !hasSubscription) {
      if (!mounted) return;
      
      setState(() {
        _message = 'Verifying payment... (Attempt ${retries + 1}/$maxRetries)';
      });

      // Wait before checking
      await Future.delayed(const Duration(seconds: 2));
      
      final authService = AuthService();
      hasSubscription = await authService.checkSubscription();
      
      if (hasSubscription) break;
      retries++;
    }
    
    if (mounted) {
      setState(() {
        _verifying = false;
        _success = hasSubscription;
        _message = hasSubscription 
            ? 'Payment successful! Your subscription is now active.'
            : 'Payment verification failed or timed out. Please contact support or try refreshing.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_verifying) ...[
                const CircularProgressIndicator(
                  color: Color(0xFF003399),
                  strokeWidth: 3,
                ),
                const SizedBox(height: 32),
                Text(
                  _message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.black87,
                  ),
                ),
              ] else ...[
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: _success ? Colors.green.shade50 : Colors.orange.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _success ? Icons.check_circle : Icons.schedule,
                    size: 60,
                    color: _success ? Colors.green : Colors.orange,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  _success ? 'Payment Successful!' : 'Payment Processing',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: _success ? Colors.green : Colors.orange,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                if (widget.transactionId != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Transaction ID',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.transactionId!,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/home',
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF003399),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Go to Dashboard',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
