import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/computer_model.dart';

class InventoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get all computers for current user
  Stream<List<Computer>> getUserComputers() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('computers')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Computer.fromJson(doc.data(), doc.id))
          .toList();
    });
  }

  // Get single computer by ID
  Future<Computer?> getComputer(String computerId) async {
    try {
      final doc = await _firestore.collection('computers').doc(computerId).get();
      if (!doc.exists) return null;
      return Computer.fromJson(doc.data()!, doc.id);
    } catch (e) {
      throw 'Failed to load computer: $e';
    }
  }

  // Add new computer
  Future<String> addComputer(Computer computer) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw 'User not authenticated';
      }

      final computerData = computer.copyWith(
        userId: userId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final doc = await _firestore.collection('computers').add(computerData.toJson());
      return doc.id;
    } catch (e) {
      throw 'Failed to add computer: $e';
    }
  }

  // Update computer
  Future<void> updateComputer(String computerId, Computer computer) async {
    try {
      final updatedData = computer.copyWith(
        updatedAt: DateTime.now(),
      );

      await _firestore.collection('computers').doc(computerId).update(updatedData.toJson());
    } catch (e) {
      throw 'Failed to update computer: $e';
    }
  }

  // Delete computer
  Future<void> deleteComputer(String computerId) async {
    try {
      await _firestore.collection('computers').doc(computerId).delete();
    } catch (e) {
      throw 'Failed to delete computer: $e';
    }
  }

  // Search computers
  Stream<List<Computer>> searchComputers(String query) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('computers')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final computers = snapshot.docs
          .map((doc) => Computer.fromJson(doc.data(), doc.id))
          .toList();

      if (query.isEmpty) return computers;

      // Filter by name, brand, or category
      return computers.where((computer) {
        final lowerQuery = query.toLowerCase();
        return computer.name.toLowerCase().contains(lowerQuery) ||
            computer.brand.toLowerCase().contains(lowerQuery) ||
            computer.category.toLowerCase().contains(lowerQuery);
      }).toList();
    });
  }

  // Get computers by category
  Stream<List<Computer>> getComputersByCategory(String category) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('computers')
        .where('userId', isEqualTo: userId)
        .where('category', isEqualTo: category)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Computer.fromJson(doc.data(), doc.id))
          .toList();
    });
  }

  // Get low stock computers (quantity <= 5)
  Stream<List<Computer>> getLowStockComputers() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return Stream.value([]);
    }

    return getUserComputers().map((computers) {
      return computers.where((computer) => computer.quantity <= 5).toList();
    });
  }

  // Update stock quantity
  Future<void> updateStock(String computerId, int quantity) async {
    try {
      await _firestore.collection('computers').doc(computerId).update({
        'quantity': quantity,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Failed to update stock: $e';
    }
  }



  // Get inventory statistics
  Future<Map<String, dynamic>> getInventoryStats() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return {};

      final snapshot = await _firestore
          .collection('computers')
          .where('userId', isEqualTo: userId)
          .get();

      final computers = snapshot.docs
          .map((doc) => Computer.fromJson(doc.data(), doc.id))
          .toList();

      int totalItems = computers.length;
      int totalQuantity = computers.fold(0, (sum, c) => sum + c.quantity);
      double totalValue = computers.fold(0.0, (sum, c) => sum + (c.price * c.quantity));
      int lowStock = computers.where((c) => c.quantity <= 5).length;

      return {
        'totalItems': totalItems,
        'totalQuantity': totalQuantity,
        'totalValue': totalValue,
        'lowStockCount': lowStock,
      };
    } catch (e) {
      return {};
    }
  }
}
