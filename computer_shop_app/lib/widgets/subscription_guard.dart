import 'package:flutter/material.dart';
import 'package:computer_shop_app/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SubscriptionGuard extends StatefulWidget {
  final Widget child;
  
  const SubscriptionGuard({Key? key, required this.child}) : super(key: key);

  @override
  State<SubscriptionGuard> createState() => _SubscriptionGuardState();
}

class _SubscriptionGuardState extends State<SubscriptionGuard> {
  bool _isLoading = true;
  bool _hasSubscription = false;

  @override
  void initState() {
    super.initState();
    _checkSubscription();
  }

  Future<void> _checkSubscription() async {
    final authService = AuthService();
    final hasSubscription = await authService.checkSubscription();
    
    if (!mounted) return;
    
    setState(() {
      _hasSubscription = hasSubscription;
      _isLoading = false;
    });

    if (!hasSubscription) {
      // Redirect to subscription page
      Navigator.pushReplacementNamed(context, '/subscription');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_hasSubscription) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return widget.child;
  }
}
