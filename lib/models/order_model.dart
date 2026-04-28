class OrderModel {
  final String? id;
  final String userId;
  final String userName;
  final String menuName;
  final int quantity;
  final double totalPrice;
  final String? imageUrl;
  final String status;
  final DateTime createdAt;
  final String paymentMethod;
  final String? paymentNumber;

  OrderModel({
    this.id,
    required this.userId,
    required this.userName,
    required this.menuName,
    required this.quantity,
    required this.totalPrice,
    this.imageUrl,
    this.status = 'pending',
    required this.createdAt,
    required this.paymentMethod,
    this.paymentNumber,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'menuName': menuName,
      'quantity': quantity,
      'totalPrice': totalPrice,
      'imageUrl': imageUrl,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'paymentMethod': paymentMethod,
      'paymentNumber': paymentNumber,
    };
  }

  factory OrderModel.fromMap(Map<String, dynamic> map, String id) {
    return OrderModel(
      id: id,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      menuName: map['menuName'] ?? '',
      quantity: map['quantity'] ?? 0,
      totalPrice: (map['totalPrice'] ?? 0).toDouble(),
      imageUrl: map['imageUrl'],
      status: map['status'] ?? 'pending',
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      paymentMethod: map['paymentMethod'] ?? '',
      paymentNumber: map['paymentNumber'],
    );
  }
}