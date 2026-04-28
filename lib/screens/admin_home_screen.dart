import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';

class AdminHomeScreen extends StatefulWidget {
  @override
  _AdminHomeScreenState createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('MyKantin - Admin'),
        actions: [
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
      body: Column(
        children: [
          Container(
            color: Colors.orange,
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = 0),
                    child: Container(
                      padding: EdgeInsets.all(16),
                      color: _selectedTab == 0 ? Colors.white : Colors.orange,
                      child: Text(
                        '📋 Pesanan',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _selectedTab == 0 ? Colors.orange : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = 1),
                    child: Container(
                      padding: EdgeInsets.all(16),
                      color: _selectedTab == 1 ? Colors.white : Colors.orange,
                      child: Text(
                        '🍽️ Menu',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _selectedTab == 1 ? Colors.orange : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _selectedTab == 0 ? OrdersTab() : MenuTab(),
          ),
        ],
      ),
    );
  }
}

class OrdersTab extends StatelessWidget {
  final FirebaseService _firebaseService = FirebaseService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<OrderModel>>(
      stream: _firebaseService.getAllOrders(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long, size: 80, color: Colors.grey),
                Text('Belum ada pesanan'),
              ],
            ),
          );
        }

        final orders = snapshot.data!;
        return ListView.builder(
          padding: EdgeInsets.all(8),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            return _buildOrderCard(context, orders[index]);
          },
        );
      },
    );
  }

  Widget _buildOrderCard(BuildContext context, OrderModel order) {
    return Card(
      margin: EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(order.userName),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: order.status == 'pending'
                    ? Colors.orange.withOpacity(0.2)
                    : order.status == 'diproses'
                    ? Colors.green.withOpacity(0.2)
                    : Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                order.status.toUpperCase(),
                style: TextStyle(
                  color: order.status == 'pending'
                      ? Colors.orange
                      : order.status == 'diproses'
                      ? Colors.green
                      : Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text('${order.menuName} x${order.quantity}'),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Detail Pesanan:', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('Menu: ${order.menuName}'),
                Text('Jumlah: ${order.quantity}'),
                Text('Total: Rp ${order.totalPrice.toInt()}'),
                Text('Pembayaran: ${order.paymentMethod}'),
                SizedBox(height: 10),
                if (order.imageUrl != null && order.imageUrl!.isNotEmpty) ...[
                  Text('Bukti Pembayaran:', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Container(
                    height: 200,
                    width: double.infinity,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        base64Decode(order.imageUrl!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  SizedBox(height: 10),
                ],
                if (order.status == 'pending')
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            await _firebaseService.updateOrderStatus(order.id!, 'diproses');

                            NotificationService.showNotification(
                              title: 'Pesanan Diproses',
                              body: 'Pesanan ${order.menuName} telah disetujui',
                              context: context,
                            );
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          child: Text('Terima'),
                        ),
                      ),
                      SizedBox(width: 10),

                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            await _firebaseService.updateOrderStatus(order.id!, 'ditolak');

                            NotificationService.showNotification(
                              title: 'Pesanan Ditolak',
                              body: 'Pesanan ${order.menuName} telah ditolak',
                              context: context,
                            );
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          child: Text('Tolak'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
//mennu
class MenuTab extends StatefulWidget {
  @override
  _MenuTabState createState() => _MenuTabState();
}

class _MenuTabState extends State<MenuTab> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  Stream<List<Map<String, dynamic>>> _getMenuStream() {
    return FirebaseService.firestoreInstance
        .collection('menu')
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => {
      'id': doc.id,
      'name': doc['name'],
      'price': doc['price'],
    })
        .toList());
  }

  Future<void> _addMenu() async {
    if (_nameController.text.isEmpty || _priceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nama dan harga harus diisi!')),
      );
      return;
    }

    await FirebaseService.firestoreInstance.collection('menu').add({
      'name': _nameController.text,
      'price': int.tryParse(_priceController.text) ?? 0,
    });

    _nameController.clear();
    _priceController.clear();
  }

  Future<void> _editMenu(String id, String oldName, int oldPrice) async {
    _nameController.text = oldName;
    _priceController.text = oldPrice.toString();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Menu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: 'Nama Menu'),
            ),
            TextField(
              controller: _priceController,
              decoration: InputDecoration(labelText: 'Harga'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseService.firestoreInstance.collection('menu').doc(id).update({
                'name': _nameController.text,
                'price': int.tryParse(_priceController.text) ?? 0,
              });
              _nameController.clear();
              _priceController.clear();
              Navigator.pop(context);
            },
            child: Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMenu(String id) async {
    await FirebaseService.firestoreInstance.collection('menu').doc(id).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Nama Menu',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _priceController,
                  decoration: InputDecoration(
                    labelText: 'Harga',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              SizedBox(width: 10),
              ElevatedButton(
                onPressed: _addMenu,
                child: Text('Tambah'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.all(15),
                  backgroundColor: Colors.green,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _getMenuStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.restaurant_menu, size: 80, color: Colors.grey),
                      Text('Belum ada menu'),
                    ],
                  ),
                );
              }

              final menus = snapshot.data!;
              return ListView.builder(
                itemCount: menus.length,
                itemBuilder: (context, index) {
                  final menu = menus[index];
                  return Card(
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: ListTile(
                      title: Text(menu['name']),
                      subtitle: Text('Rp ${menu['price']}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _editMenu(
                              menu['id'],
                              menu['name'],
                              menu['price'],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteMenu(menu['id']),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}