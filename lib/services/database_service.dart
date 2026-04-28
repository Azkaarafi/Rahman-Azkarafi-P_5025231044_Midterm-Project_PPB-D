import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/order_model.dart';

class DatabaseService {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'mykantin.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE orders(
            id TEXT PRIMARY KEY,
            userId TEXT,
            userName TEXT,
            menuName TEXT,
            quantity INTEGER,
            totalPrice REAL,
            imageUrl TEXT,
            status TEXT,
            createdAt TEXT,
            paymentMethod TEXT,
            paymentNumber TEXT
          )
        ''');
      },
    );
  }

  Future<void> cacheOrders(List<OrderModel> orders) async {
    final db = await database;
    await db.delete('orders');

    for (var order in orders) {
      await db.insert('orders', {
        ...order.toMap(),
        'id': order.id,
      });
    }
  }

  Future<List<OrderModel>> getCachedOrders() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('orders');

    return maps.map((map) => OrderModel.fromMap(map, map['id'])).toList();
  }
}