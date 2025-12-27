import 'package:cloud_firestore/cloud_firestore.dart';

class SubscriptionPlan {
  final String id;
  final String name;
  final double price;
  final String currency;
  final int duration; // in days
  final List<String> features;

  SubscriptionPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.currency,
    required this.duration,
    required this.features,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'ETB',
      duration: json['duration'] ?? 0,
      features: List<String>.from(json['features'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'currency': currency,
      'duration': duration,
      'features': features,
    };
  }
}

class Subscription {
  final String userId;
  final String planId;
  final String status; // trial, active, expired, cancelled
  final DateTime startDate;
  final DateTime endDate;
  final bool autoRenew;
  final DateTime createdAt;
  final DateTime updatedAt;

  Subscription({
    required this.userId,
    required this.planId,
    required this.status,
    required this.startDate,
    required this.endDate,
    this.autoRenew = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      userId: json['userId'] ?? '',
      planId: json['planId'] ?? '',
      status: json['status'] ?? '',
      startDate: (json['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (json['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      autoRenew: json['autoRenew'] ?? false,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'planId': planId,
      'status': status,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'autoRenew': autoRenew,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  bool get isActive {
    return (status == 'active' || status == 'trial') && endDate.isAfter(DateTime.now());
  }

  int get daysRemaining {
    if (!isActive) return 0;
    return endDate.difference(DateTime.now()).inDays;
  }

  bool get isTrial {
    return status == 'trial';
  }
}
