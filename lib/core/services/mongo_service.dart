import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive/hive.dart' as hive;
import 'package:mongo_dart/mongo_dart.dart';
import '../../models/app_settings.dart';
import '../../models/invoice/bill.dart';
import '../../models/user_model.dart';

enum MongoConnectionStatus {
  disconnected,
  connecting,
  connected,
  error,
}

class MongoService {
  static final MongoService instance = MongoService._internal();
  MongoService._internal();

  static const String defaultUri =
      'mongodb+srv://yuvaraj525354_db_user:PUSHNlQ7zhQtcEWt@cluster0.kvv3uji.mongodb.net/mk_studio?retryWrites=true&w=majority&appName=Cluster0';

  Db? _db;
  final ValueNotifier<MongoConnectionStatus> statusNotifier =
      ValueNotifier<MongoConnectionStatus>(MongoConnectionStatus.disconnected);
  String? _lastError;

  MongoConnectionStatus get status => statusNotifier.value;
  bool get isConnected => _db != null && _db!.isConnected;
  String? get lastError => _lastError;

  String get connectionUri {
    try {
      if (dotenv.isInitialized) {
        final uri = dotenv.env['MONGODB_URI'];
        if (uri != null && uri.trim().isNotEmpty) {
          return uri.trim();
        }
      }
    } catch (_) {}
    return defaultUri;
  }

  /// Initialize connection to MongoDB Atlas asynchronously
  Future<bool> init() async {
    if (isConnected) return true;

    statusNotifier.value = MongoConnectionStatus.connecting;
    _lastError = null;

    try {
      final uri = connectionUri;
      debugPrint('[MongoService] Connecting to MongoDB Atlas...');
      _db = await Db.create(uri);
      await _db!.open().timeout(const Duration(seconds: 15));

      statusNotifier.value = MongoConnectionStatus.connected;
      debugPrint('[MongoService] Connected successfully to database: ${_db!.databaseName}');
      return true;
    } catch (e) {
      _lastError = e.toString();
      statusNotifier.value = MongoConnectionStatus.error;
      debugPrint('[MongoService] Failed to connect to MongoDB: $e');
      return false;
    }
  }

  /// Ensure connection is active before executing operations
  Future<bool> _ensureConnection() async {
    if (isConnected) return true;
    return await init();
  }

  // ==================== USER AUTHENTICATION ====================

  /// Register a new user in MongoDB Atlas
  Future<bool> registerUser(UserModel user) async {
    try {
      final connected = await _ensureConnection();
      if (!connected || _db == null) return false;

      final collection = _db!.collection('users');
      final normalizedEmail = user.email.toLowerCase().trim();

      // Check if user already exists
      final existing = await collection.findOne(where.eq('email', normalizedEmail));
      if (existing != null) {
        _lastError = 'User with this email already exists';
        return false;
      }

      await collection.insertOne(user.toMap());
      debugPrint('[MongoService] User registered in MongoDB: ${user.email}');
      return true;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('[MongoService] Error registering user: $e');
      return false;
    }
  }

  /// Find user by email for login
  Future<UserModel?> findUserByEmail(String email) async {
    try {
      final connected = await _ensureConnection();
      if (!connected || _db == null) return null;

      final collection = _db!.collection('users');
      final normalizedEmail = email.toLowerCase().trim();
      final doc = await collection.findOne(where.eq('email', normalizedEmail));

      if (doc != null) {
        return UserModel.fromMap(doc);
      }
      return null;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('[MongoService] Error finding user by email: $e');
      return null;
    }
  }

  /// Find user by ID
  Future<UserModel?> findUserById(String id) async {
    try {
      final connected = await _ensureConnection();
      if (!connected || _db == null) return null;

      final collection = _db!.collection('users');
      final doc = await collection.findOne(where.eq('id', id));

      if (doc != null) {
        return UserModel.fromMap(doc);
      }
      return null;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('[MongoService] Error finding user by ID: $e');
      return null;
    }
  }

  // ==================== BILLS (USER-ISOLATED) ====================

  /// Save or update a bill in MongoDB Atlas (tied to user)
  Future<bool> saveBill(Bill bill) async {
    try {
      final connected = await _ensureConnection();
      if (!connected || _db == null) return false;

      final collection = _db!.collection('bills');
      final billMap = bill.toMap();

      // Match by billNumber AND userId for user data isolation
      final query = (bill.userId != null && bill.userId!.isNotEmpty)
          ? where.eq('billNumber', bill.billNumber).eq('userId', bill.userId)
          : where.eq('billNumber', bill.billNumber);

      await collection.modernUpdate(
        query,
        billMap,
        upsert: true,
      );

      debugPrint('[MongoService] Saved bill ${bill.billNumber} for user ${bill.userId} to MongoDB');
      return true;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('[MongoService] Error saving bill to MongoDB: $e');
      return false;
    }
  }

  /// Delete a bill from MongoDB Atlas (for a specific user)
  Future<bool> deleteBill(String billNumber, {String? userId}) async {
    try {
      final connected = await _ensureConnection();
      if (!connected || _db == null) return false;

      final collection = _db!.collection('bills');
      final query = (userId != null && userId.isNotEmpty)
          ? where.eq('billNumber', billNumber).eq('userId', userId)
          : where.eq('billNumber', billNumber);

      await collection.deleteOne(query);

      debugPrint('[MongoService] Deleted bill $billNumber for user $userId from MongoDB');
      return true;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('[MongoService] Error deleting bill from MongoDB: $e');
      return false;
    }
  }

  /// Fetch bills from MongoDB Atlas, strictly filtered by userId
  Future<List<Bill>> getAllBills({String? userId}) async {
    try {
      final connected = await _ensureConnection();
      if (!connected || _db == null) return [];

      final collection = _db!.collection('bills');
      final selector = (userId != null && userId.isNotEmpty)
          ? where.eq('userId', userId).sortBy('dateTime', descending: true)
          : where.sortBy('dateTime', descending: true);

      final docs = await collection.find(selector).toList();
      return docs.map((doc) => Bill.fromMap(doc)).toList();
    } catch (e) {
      _lastError = e.toString();
      debugPrint('[MongoService] Error fetching bills from MongoDB: $e');
      return [];
    }
  }

  // ==================== SETTINGS (USER-ISOLATED) ====================

  /// Save application settings to MongoDB Atlas for a specific user
  Future<bool> saveSettings(AppSettings settings, {String? userId}) async {
    try {
      final connected = await _ensureConnection();
      if (!connected || _db == null) return false;

      final collection = _db!.collection('settings');
      final settingsMap = settings.toMap();
      settingsMap['type'] = 'app_settings';
      if (userId != null) settingsMap['userId'] = userId;

      final query = (userId != null && userId.isNotEmpty)
          ? where.eq('type', 'app_settings').eq('userId', userId)
          : where.eq('type', 'app_settings');

      await collection.modernUpdate(
        query,
        settingsMap,
        upsert: true,
      );

      debugPrint('[MongoService] Saved app settings for user $userId to MongoDB');
      return true;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('[MongoService] Error saving settings to MongoDB: $e');
      return false;
    }
  }

  /// Fetch application settings from MongoDB Atlas for a specific user
  Future<AppSettings?> getSettings({String? userId}) async {
    try {
      final connected = await _ensureConnection();
      if (!connected || _db == null) return null;

      final collection = _db!.collection('settings');
      final query = (userId != null && userId.isNotEmpty)
          ? where.eq('type', 'app_settings').eq('userId', userId)
          : where.eq('type', 'app_settings');

      final doc = await collection.findOne(query);

      if (doc != null) {
        return AppSettings.fromMap(doc);
      }
      return null;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('[MongoService] Error fetching settings from MongoDB: $e');
      return null;
    }
  }

  // ==================== SYNC (USER-ISOLATED) ====================

  /// Sync local bills for a specific user with MongoDB Atlas
  Future<int> syncAllBills(hive.Box<Bill> billsBox, {required String userId}) async {
    try {
      final connected = await _ensureConnection();
      if (!connected || _db == null) return 0;

      // 1. Push user's local bills to MongoDB
      final localBills = billsBox.values
          .where((b) => b.userId == null || b.userId == userId)
          .toList();

      for (final bill in localBills) {
        if (bill.userId == null || bill.userId!.isEmpty) {
          bill.userId = userId;
          await bill.save();
        }
        await saveBill(bill);
      }

      // 2. Fetch only this user's bills from MongoDB
      final remoteBills = await getAllBills(userId: userId);

      // 3. Merge remote bills missing in local Hive
      int newSyncedCount = 0;
      final localBillNumbers = localBills.map((b) => b.billNumber).toSet();

      for (final remoteBill in remoteBills) {
        if (!localBillNumbers.contains(remoteBill.billNumber)) {
          remoteBill.userId = userId;
          await billsBox.add(remoteBill);
          newSyncedCount++;
        }
      }

      debugPrint('[MongoService] Sync completed for user $userId. Synced $newSyncedCount remote bills.');
      return newSyncedCount;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('[MongoService] Error during sync: $e');
      return 0;
    }
  }

  /// Close connection gracefully
  Future<void> close() async {
    if (_db != null && _db!.isConnected) {
      await _db!.close();
      statusNotifier.value = MongoConnectionStatus.disconnected;
    }
  }
}
