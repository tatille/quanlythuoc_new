// ignore_for_file: avoid_print

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:async';
import 'package:quanlythuoc_new/models/medicine.dart';
import 'package:quanlythuoc_new/models/medicine_history.dart';
// Import for JSON encoding/decoding

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;

  static Database? _database;

  DatabaseHelper._internal();

  static const String tableName = 'medicines';
  static const String historyTableName = 'medicine_history';
  static const String usersTableName = 'users'; // New table name

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'medicine_app.db');
    return await openDatabase(
      path,
      version: 4, // Increased version
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $usersTableName(
        id TEXT PRIMARY KEY,
        username TEXT UNIQUE,
        password TEXT
      )
      ''');
    await db.execute('''
      CREATE TABLE $tableName(
        id TEXT PRIMARY KEY,
        user_id TEXT, -- New column
        name TEXT,
        dosage TEXT,
        timesPerDay INTEGER,
        startDate TEXT,
        endDate TEXT,
        notes TEXT,
        createdAt TEXT,
        specificIntakeTimes TEXT,
        FOREIGN KEY (user_id) REFERENCES $usersTableName (id) ON DELETE CASCADE
      )
      ''');
    await db.execute('''
      CREATE TABLE $historyTableName(
        id TEXT PRIMARY KEY,
        user_id TEXT, -- New column
        medicine_id TEXT,
        taken_at TEXT,
        status TEXT,
        notes TEXT,
        created_at TEXT,
        FOREIGN KEY (user_id) REFERENCES $usersTableName (id) ON DELETE CASCADE,
        FOREIGN KEY (medicine_id) REFERENCES $tableName (id) ON DELETE CASCADE
      )
      ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Migration logic
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE $tableName ADD COLUMN specificIntakeTimes TEXT',
      );
    }
    if (oldVersion < 3) {
      await db.execute('DROP TABLE IF EXISTS $historyTableName');
      await db.execute('''
        CREATE TABLE $historyTableName(
          id TEXT PRIMARY KEY,
          medicine_id TEXT,
          taken_at TEXT,
          status TEXT,
          notes TEXT,
          created_at TEXT,
          FOREIGN KEY (medicine_id) REFERENCES $tableName (id) ON DELETE CASCADE
        )
        ''');
    }
    if (oldVersion < 4) {
      // Upgrade to version 4
      // Create users table if it doesn't exist (for cases upgrading from < version 3)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $usersTableName(
          id TEXT PRIMARY KEY,
          username TEXT UNIQUE,
          password TEXT
        )
        ''');
      // Add user_id to medicines table
      await db.execute('ALTER TABLE $tableName ADD COLUMN user_id TEXT');
      // Add user_id to medicine_history table
      await db.execute('ALTER TABLE $historyTableName ADD COLUMN user_id TEXT');

      // Note: Data migration for existing records would be needed here
      // to assign a default user_id or handle appropriately. For simplicity,
      // new records will require a user_id.
    }
  }

  Future<void> insertMedicine(Medicine medicine) async {
    final db = await database;
    await db.insert(
      tableName,
      medicine.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Medicine>> getMedicines() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(tableName);
    // Convert the List<Map<String, dynamic>> into a List<Medicine>.
    return List.generate(maps.length, (i) {
      return Medicine.fromMap(maps[i]);
    });
  }

  Future<Medicine?> getMedicineById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Medicine.fromMap(maps.first);
    } else {
      return null;
    }
  }

  Future<void> updateMedicine(Medicine medicine) async {
    final db = await database;
    await db.update(
      tableName,
      medicine.toMap(),
      where: 'id = ?',
      whereArgs: [medicine.id],
    );
  }

  Future<void> deleteMedicine(String id) async {
    final db = await database;
    await db.delete(tableName, where: 'id = ?', whereArgs: [id]);
  }

  // Insert a medicine history record
  Future<void> insertMedicineHistory(MedicineHistory history) async {
    final db = await database;
    try {
      await db.insert(
        historyTableName,
        history.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('Successfully inserted history record: ${history.id}');
    } catch (e) {
      print('Error inserting history record: $e');
      rethrow;
    }
  }

  // Get all medicine history records
  Future<List<MedicineHistory>> getMedicineHistory() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(historyTableName);
    return List.generate(maps.length, (i) {
      return MedicineHistory.fromMap(maps[i]);
    });
  }

  // Get medicine history records for a specific date
  Future<List<MedicineHistory>> getMedicineHistoryForDate(DateTime date) async {
    final db = await database;
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay
        .add(const Duration(days: 1))
        .subtract(const Duration(seconds: 1));

    final List<Map<String, dynamic>> maps = await db.query(
      historyTableName,
      where: 'taken_at BETWEEN ? AND ?',
      whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
      orderBy: 'taken_at ASC',
    );

    return List.generate(maps.length, (i) {
      return MedicineHistory.fromMap(maps[i]);
    });
  }

  // Get medicine history records for the last specified number of days
  Future<List<MedicineHistory>> getMedicineHistoryForLastDays(int days) async {
    final db = await database;
    final now = DateTime.now();
    final startDate = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: days - 1)); // Include today

    final List<Map<String, dynamic>> maps = await db.query(
      historyTableName,
      where: 'taken_at >= ?',
      whereArgs: [startDate.toIso8601String()],
      orderBy: 'taken_at ASC',
    );

    return List.generate(maps.length, (i) {
      return MedicineHistory.fromMap(maps[i]);
    });
  }

  // Delete a medicine history record by ID
  Future<void> deleteMedicineHistory(String id) async {
    final db = await database;
    await db.delete(historyTableName, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteDatabase() async {
    String path = join(await getDatabasesPath(), 'medicine_app.db');
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }

  // New method to get a user by username
  Future<Map<String, dynamic>?> getUserByUsername(String username) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      usersTableName,
      where: 'username = ?',
      whereArgs: [username],
    );
    if (maps.isNotEmpty) {
      return maps.first;
    } else {
      return null;
    }
  }

  // New method to insert a new user
  Future<void> insertUser(Map<String, dynamic> user) async {
    final db = await database;
    await db.insert(
      usersTableName,
      user,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
