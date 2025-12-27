import 'package:cloud_firestore/cloud_firestore.dart';

class Computer {
  final String? id;
  final String userId;
  final String name;
  final String category; // Desktop, Laptop, Server, Workstation
  final String brand;
  final String processor;
  final String ram;
  final String storage;
  final String gpu;
  final double price;
  final int quantity;
  final List<String> serialNumbers;
  final String description;
  final String? imageUrl;
  final String status; // available, maintenance, sold, repair
  final DateTime createdAt;
  final DateTime updatedAt;

  Computer({
    this.id,
    required this.userId,
    required this.name,
    required this.category,
    required this.brand,
    required this.processor,
    required this.ram,
    required this.storage,
    this.gpu = '',
    required this.price,
    required this.quantity,
    this.serialNumbers = const [],
    this.description = '',
    this.imageUrl,
    this.status = 'available',
    required this.createdAt,
    required this.updatedAt,
  });

  factory Computer.fromJson(Map<String, dynamic> json, String id) {
    return Computer(
      id: id,
      userId: json['userId'] ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? '',
      brand: json['brand'] ?? '',
      processor: json['processor'] ?? '',
      ram: json['ram'] ?? '',
      storage: json['storage'] ?? '',
      gpu: json['gpu'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      quantity: json['quantity'] ?? 0,
      serialNumbers: List<String>.from(json['serialNumbers'] ?? []),
      description: json['description'] ?? '',
      imageUrl: json['imageUrl'],
      status: json['status'] ?? 'available',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'name': name,
      'category': category,
      'brand': brand,
      'processor': processor,
      'ram': ram,
      'storage': storage,
      'gpu': gpu,
      'price': price,
      'quantity': quantity,
      'serialNumbers': serialNumbers,
      'description': description,
      'imageUrl': imageUrl,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Computer copyWith({
    String? id,
    String? userId,
    String? name,
    String? category,
    String? brand,
    String? processor,
    String? ram,
    String? storage,
    String? gpu,
    double? price,
    int? quantity,
    List<String>? serialNumbers,
    String? description,
    String? imageUrl,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Computer(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      category: category ?? this.category,
      brand: brand ?? this.brand,
      processor: processor ?? this.processor,
      ram: ram ?? this.ram,
      storage: storage ?? this.storage,
      gpu: gpu ?? this.gpu,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      serialNumbers: serialNumbers ?? this.serialNumbers,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
