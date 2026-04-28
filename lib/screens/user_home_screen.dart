import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';
import 'order_history_screen.dart';

class UserHomeScreen extends StatefulWidget {
  @override
  _UserHomeScreenState createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final ImagePicker _picker = ImagePicker();
  final User? _user = FirebaseAuth.instance.currentUser;

  List<Map<String, dynamic>> _cart = [];
  String? _selectedMenu;
  int _quantity = 1;
  double _totalPrice = 0;
  String? _paymentMethod;
  XFile? _paymentImage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _listenOrderUpdates();
  }

  void _listenOrderUpdates() {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    FirebaseService.firestoreInstance
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.modified) {
          final data = change.doc.data();
          final newStatus = data?['status'];

          if (newStatus == 'diproses') {
            NotificationService.showNotification(
              title: '✅ Pesanan Diproses!',
              body: 'Pesanan ${data?['menuName']} sedang diproses admin',
              context: context,
            );
          } else if (newStatus == 'ditolak') {
            NotificationService.showNotification(
              title: '❌ Pesanan Ditolak',
              body: 'Pesanan ${data?['menuName']} ditolak admin',
              context: context,
            );
          }
        }
      }
    });
  }

  Future<String> _getUserName() async {
    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final doc = await FirebaseService.firestoreInstance
          .collection('users')
          .doc(userId)
          .get();

      if (doc.exists && doc.data() != null) {
        return doc['name'] ?? 'User';
      }
    } catch (e) {
      print('Get userName error: $e');
    }

    return FirebaseAuth.instance.currentUser!.displayName ?? 'User';
  }

  Stream<List<Map<String, dynamic>>> _getMenuStream() {
    return FirebaseService.firestoreInstance
        .collection('menu')
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => {
      'name': doc['name'],
      'price': doc['price'],
    })
        .toList());
  }

  double _calculateTotalFromCart() {
    double total = 0;
    for (var item in _cart) {
      total += (item['price'] as int) * (item['quantity'] as int);
    }
    return total;
  }

  Future<void> _takePhoto() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      maxHeight: 1024,
    );

    if (photo != null) {
      setState(() {
        _paymentImage = photo;
      });
    }
  }

  Future<void> _submitOrder() async {
    if (_cart.isEmpty || _paymentMethod == null || _paymentImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lengkapi keranjang dan pembayaran!')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String base64Image =
      await _firebaseService.imageToBase64(_paymentImage!.path);
      String menuNames = _cart
          .map((item) => '${item['name']} x${item['quantity']}')
          .join(', ');
      String userName = await _getUserName();

      OrderModel order = OrderModel(
        userId: FirebaseAuth.instance.currentUser!.uid,
        userName: userName,
        menuName: menuNames,
        quantity:
        _cart.fold(0, (sum, item) => sum + (item['quantity'] as int)),
        totalPrice: _calculateTotalFromCart(),
        imageUrl: base64Image,
        status: 'pending',
        createdAt: DateTime.now(),
        paymentMethod: _paymentMethod!,
        paymentNumber: '087576897652',
      );

      await _firebaseService.createOrder(order);

      NotificationService.showNotification(
        title: 'Terkirim!',
        body: 'Pesanan ${menuNames} berhasil dikirim, tunggu konfirmasi admin',
        context: context,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pesanan berhasil dikirim!')),
      );

      setState(() {
        _cart = [];
        _totalPrice = 0;
        _paymentMethod = null;
        _paymentImage = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('MyKantin - User'),
        actions: [
          IconButton(
            icon: Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => OrderHistoryScreen()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Konfirmasi'),
                  content: Text('Yakin ingin logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Batal'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _firebaseService.signOut();
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: Text('Logout'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pesan Makanan/Minuman',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),

            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _getMenuStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return Center(child: CircularProgressIndicator());
                final menuItems = snapshot.data!;

                return Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedMenu,
                      decoration: InputDecoration(
                        labelText: 'Pilih Menu',
                        border: OutlineInputBorder(),
                      ),
                      items: menuItems.map<DropdownMenuItem<String>>((menu) {
                        return DropdownMenuItem<String>(
                          value: menu['name'] as String,
                          child:
                          Text('${menu['name']} - Rp ${menu['price']}'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedMenu = value;
                        });
                      },
                    ),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Text('Jumlah: ', style: TextStyle(fontSize: 16)),
                        IconButton(
                          icon: Icon(Icons.remove_circle_outline),
                          onPressed: _quantity > 1
                              ? () => setState(() => _quantity--)
                              : null,
                        ),
                        Text('$_quantity',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: Icon(Icons.add_circle_outline),
                          onPressed: () => setState(() => _quantity++),
                        ),
                        Spacer(),
                        ElevatedButton.icon(
                          icon: Icon(Icons.add_shopping_cart),
                          label: Text('Tambah'),
                          onPressed: () {
                            if (_selectedMenu == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Pilih menu dulu!')),
                              );
                              return;
                            }

                            final selectedMenuItem = menuItems.firstWhere(
                                  (m) => m['name'] == _selectedMenu,
                            );

                            setState(() {
                              int existingIndex = _cart.indexWhere(
                                      (item) => item['name'] == _selectedMenu);
                              if (existingIndex != -1) {
                                _cart[existingIndex]['quantity'] += _quantity;
                              } else {
                                _cart.add({
                                  'name': _selectedMenu,
                                  'quantity': _quantity,
                                  'price': selectedMenuItem['price'],
                                });
                              }
                            });

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      '$_selectedMenu ditambahkan ke keranjang')),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
            SizedBox(height: 20),

            if (_cart.isNotEmpty) ...[
              Text('🛒 Keranjang:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              ...List.generate(_cart.length, (index) {
                final item = _cart[index];
                return Card(
                  margin: EdgeInsets.only(bottom: 5),
                  child: ListTile(
                    title: Text(item['name']),
                    subtitle:
                    Text('${item['quantity']}x | Rp ${item['price']}'),
                    trailing: IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _cart.removeAt(index);
                        });
                      },
                    ),
                  ),
                );
              }),
              SizedBox(height: 10),
              Card(
                color: Colors.orange[50],
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total: ${_cart.length} menu',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        'Rp ${_calculateTotalFromCart().toInt()}',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.orange),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),
            ],

            if (_cart.isNotEmpty) ...[
              Text('Metode Pembayaran:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: Text('DANA'),
                      value: 'DANA',
                      groupValue: _paymentMethod,
                      onChanged: (v) => setState(() => _paymentMethod = v),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: Text('OVO'),
                      value: 'OVO',
                      groupValue: _paymentMethod,
                      onChanged: (v) => setState(() => _paymentMethod = v),
                    ),
                  ),
                ],
              ),
            ],

            if (_paymentMethod != null)
              Card(
                color: Colors.orange[50],
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Transfer ke:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('087576897652 ($_paymentMethod)'),
                      SizedBox(height: 10),
                      Text('Upload Bukti Pembayaran:'),
                      SizedBox(height: 10),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            icon: Icon(Icons.camera_alt),
                            label: Text('Ambil Foto'),
                            onPressed: _takePhoto,
                          ),
                          if (_paymentImage != null)
                            Padding(
                              padding: EdgeInsets.only(left: 10),
                              child: Icon(Icons.check_circle,
                                  color: Colors.green),
                            ),
                        ],
                      ),
                      if (_paymentImage != null) ...[
                        SizedBox(height: 10),
                        Image.file(File(_paymentImage!.path),
                            height: 200, fit: BoxFit.cover),
                      ],
                    ],
                  ),
                ),
              ),
            SizedBox(height: 20),

            if (_cart.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitOrder,
                  child: _isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text('Kirim Pesanan (${_cart.length} menu)',
                      style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.all(15),
                    backgroundColor: Colors.orange,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}