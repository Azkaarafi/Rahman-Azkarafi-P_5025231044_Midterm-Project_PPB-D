import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/order_model.dart';

class FirebaseService {
  static final FirebaseFirestore firestoreInstance = FirebaseFirestore.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<User?> signUp(String email, String password, String name) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await result.user!.updateDisplayName(name);

      await _firestore.collection('users').doc(result.user!.uid).set({
        'name': name,
        'email': email,
        'role': 'user',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return result.user;
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuth Error: ${e.code} - ${e.message}');
      return null;
    } catch (e) {
      print('Error signing up: $e');
      return null;
    }
  }
  Future<User?> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } catch (e) {
      print('Error signing in: $e');
      return null;
    }
  }
  Future<void> signOut() async {
    await _auth.signOut();
  }
  Future<String> imageToBase64(String imagePath) async {
    File imageFile = File(imagePath);
    List<int> imageBytes = await imageFile.readAsBytes();
    return base64Encode(imageBytes);
  }
  Future<void> createOrder(OrderModel order) async {
    await _firestore.collection('orders').add(order.toMap());
  }
  Stream<List<OrderModel>> getOrdersByUser(String userId) {
    return _firestore
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      var docs = snapshot.docs.toList()
        ..sort((a, b) {
          var aTime = DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime.now();
          var bTime = DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime.now();
          return bTime.compareTo(aTime);
        });

      return docs.map((doc) => OrderModel.fromMap(doc.data(), doc.id)).toList();
    });
  }
  Stream<List<OrderModel>> getAllOrders() {
    return _firestore
        .collection('orders')
        .snapshots()
        .map((snapshot) {
      var docs = snapshot.docs.toList()
        ..sort((a, b) {
          var aTime = DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime.now();
          var bTime = DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime.now();
          return bTime.compareTo(aTime);
        });

      return docs.map((doc) => OrderModel.fromMap(doc.data(), doc.id)).toList();
    });
  }
  Future<void> updateOrderStatus(String orderId, String status) async {
    await _firestore.collection('orders').doc(orderId).update({
      'status': status,
    });
  }

  Future<void> deleteOrder(String orderId) async {
    await _firestore.collection('orders').doc(orderId).delete();
  }
}