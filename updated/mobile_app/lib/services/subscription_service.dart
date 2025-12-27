import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/subscription_model.dart';

class SubscriptionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Replace with your Chapa secret key (use environment variable in production)
  static const String _chapaSecretKey = 'CHASECK_TEST-nHCc5HHEQ15Wl7LhLRBkhGBDtL93hTEV';
  static const String _chapaBaseUrl = 'https://api.chapa.co/v1';

  // Get current user's subscription
  Stream<Subscription?> getUserSubscription() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return Stream.value(null);
    }

    return _firestore
        .collection('subscriptions')
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return Subscription.fromJson(doc.data()!);
    });
  }

  // Get subscription plans
  Future<List<SubscriptionPlan>> getSubscriptionPlans() async {
    try {
      final snapshot = await _firestore.collection('subscription_plans').get();
      return snapshot.docs
          .map((doc) => SubscriptionPlan.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      throw 'Failed to load subscription plans: $e';
    }
  }

  // Check if user has active subscription
  Future<bool> hasActiveSubscription() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      final doc = await _firestore.collection('subscriptions').doc(userId).get();
      if (!doc.exists) return false;

      final subscription = Subscription.fromJson(doc.data()!);
      return subscription.isActive;
    } catch (e) {
      return false;
    }
  }

  // Create trial subscription for new user
  Future<void> createTrialSubscription() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw 'User not authenticated';

      final now = DateTime.now();
      final trialEnd = now.add(const Duration(days: 7));

      await _firestore.collection('subscriptions').doc(userId).set({
        'userId': userId,
        'planId': 'trial',
        'status': 'trial',
        'startDate': Timestamp.fromDate(now),
        'endDate': Timestamp.fromDate(trialEnd),
        'autoRenew': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Failed to create trial: $e';
    }
  }

  // Initialize payment with Chapa (direct API call)
  Future<Map<String, dynamic>> initializePayment(String planId) async {
    try {
      final userId = _auth.currentUser?.uid;
      final userEmail = _auth.currentUser?.email;
      if (userId == null || userEmail == null) {
        throw 'User not authenticated';
      }

      // Get plan details
      final planDoc = await _firestore.collection('subscription_plans').doc(planId).get();
      if (!planDoc.exists) {
        throw 'Plan not found';
      }
      final plan = planDoc.data()!;

      final txRef = 'tx-$userId-${DateTime.now().millisecondsSinceEpoch}';

      // Call Chapa API directly
      final response = await http.post(
        Uri.parse('$_chapaBaseUrl/transaction/initialize'),
        headers: {
          'Authorization': 'Bearer $_chapaSecretKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'amount': plan['price'],
          'currency': 'ETB',
          'email': userEmail,
          'first_name': 'Customer',
          'last_name': 'User',
          'tx_ref': txRef,
          'customization': {
            'title': 'Subscription',
            'description': plan['name'],
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Store payment record
        await _firestore.collection('payments').add({
          'userId': userId,
          'txRef': txRef,
          'amount': plan['price'],
          'currency': 'ETB',
          'status': 'pending',
          'planId': planId,
          'chapaResponse': data,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        return {
          'success': true,
          'checkout_url': data['data']['checkout_url'],
          'tx_ref': txRef,
        };
      } else {
        throw 'Payment initialization failed: ${response.body}';
      }
    } catch (e) {
      throw 'Payment initialization failed: $e';
    }
  }

  // Verify payment and activate subscription
  Future<bool> verifyAndActivateSubscription(String txRef) async {
    try {
      // Verify with Chapa
      final response = await http.get(
        Uri.parse('$_chapaBaseUrl/transaction/verify/$txRef'),
        headers: {
          'Authorization': 'Bearer $_chapaSecretKey',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['data']['status'] == 'success') {
          // Get payment record
          final paymentsSnapshot = await _firestore
              .collection('payments')
              .where('txRef', isEqualTo: txRef)
              .limit(1)
              .get();

          if (paymentsSnapshot.docs.isEmpty) {
            throw 'Payment record not found';
          }

          final payment = paymentsSnapshot.docs.first.data();
          
          // Update payment status
          await paymentsSnapshot.docs.first.reference.update({
            'status': 'success',
            'chapaResponse': data,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          // Get plan details
        final planDoc = await _firestore
            .collection('subscription_plans')
            .doc(payment['planId'])
            .get();
        
        if (!planDoc.exists) {
          throw 'Subscription plan not found';
        }
        
        final plan = planDoc.data()!;
        
        // Validate and get duration
        if (!plan.containsKey('duration')) {
          throw 'Plan duration not configured';
        }
        
        int durationDays;
        try {
          // Handle both int and string duration values
          if (plan['duration'] is String) {
            durationDays = int.parse(plan['duration']);
          } else if (plan['duration'] is int) {
            durationDays = plan['duration'];
          } else {
            throw 'Invalid duration format: ${plan['duration']}';
          }
          
          // Validate duration is reasonable (between 1 day and 10 years)
          if (durationDays < 1 || durationDays > 3650) {
            throw 'Invalid duration value: $durationDays days';
          }
        } catch (e) {
          throw 'Failed to parse plan duration: $e';
        }

        // Activate subscription (merge to handle existing trial subscriptions)
        final now = DateTime.now();
        final endDate = now.add(Duration(days: durationDays));
        
        await _firestore.collection('subscriptions').doc(payment['userId']).set({
          'userId': payment['userId'],
          'planId': payment['planId'],
          'status': 'active',
          'startDate': Timestamp.fromDate(now),
          'endDate': Timestamp.fromDate(endDate),
          'autoRenew': false,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

          return true;
        }
      }
      
      return false;
    } catch (e) {
      throw 'Payment verification failed: $e';
    }
  }

  // Cancel subscription
  Future<void> cancelSubscription() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw 'User not authenticated';
      }

      await _firestore.collection('subscriptions').doc(userId).update({
        'status': 'cancelled',
        'autoRenew': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Failed to cancel subscription: $e';
    }
  }

  // Get payment history
  Future<List<Map<String, dynamic>>> getPaymentHistory() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return [];

      final snapshot = await _firestore
          .collection('payments')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      throw 'Failed to load payment history: $e';
    }
  }
}
