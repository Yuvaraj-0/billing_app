import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../models/invoice/bill.dart';
import '../models/app_settings.dart';
import '../constants/app_constants.dart';
import '../core/services/mongo_service.dart';

class SettingsViewModel extends ChangeNotifier {
  late Box<AppSettings> _settingsBox;
  AppSettings _settings = AppSettings();
  String? _currentUserId;

  AppSettings get settings => _settings;
  String get shopName => _settings.shopName;
  bool get autoIncrement => _settings.autoIncrement;
  String get currencySymbol => _settings.currencySymbol;
  String? get currentUserId => _currentUserId;

  String get _currentSettingsKey =>
      (_currentUserId != null && _currentUserId!.isNotEmpty)
          ? 'settings_$_currentUserId'
          : AppConstants.settingsKey;

  /// Returns the local logo image file if it exists, null otherwise
  File? get logoFile {
    final path = _settings.logoImagePath;
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    return file.existsSync() ? file : null;
  }

  Future<void> init({String? userId, String? initialShopName}) async {
    _currentUserId = userId;
    _settingsBox = Hive.box<AppSettings>(AppConstants.settingsBoxName);

    final key = _currentSettingsKey;
    var userSettings = _settingsBox.get(key);

    if (userSettings == null) {
      userSettings = AppSettings(
        shopName: (initialShopName != null && initialShopName.isNotEmpty)
            ? initialShopName
            : 'MK Star',
      );
      await _settingsBox.put(key, userSettings);
    }

    _settings = userSettings;
    notifyListeners();

    // Try fetching latest cloud settings from MongoDB in background for this user
    _syncFromCloud();
  }

  Future<void> _syncFromCloud() async {
    try {
      final cloudSettings = await MongoService.instance.getSettings(userId: _currentUserId);
      if (cloudSettings != null) {
        // Preserve local logoImagePath — it's device-local, not from cloud
        final localLogoPath = _settings.logoImagePath;
        _settings = cloudSettings;
        _settings.logoImagePath = localLogoPath;
        await _settingsBox.put(_currentSettingsKey, _settings);
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> updateShopName(String name) async {
    _settings.shopName = name;
    await _settings.save();
    MongoService.instance.saveSettings(_settings, userId: _currentUserId);
    notifyListeners();
  }

  Future<void> updateCurrencySymbol(String symbol) async {
    _settings.currencySymbol = symbol;
    await _settings.save();
    MongoService.instance.saveSettings(_settings, userId: _currentUserId);
    notifyListeners();
  }

  Future<void> updateAutoIncrement(bool value) async {
    _settings.autoIncrement = value;
    await _settings.save();
    MongoService.instance.saveSettings(_settings, userId: _currentUserId);
    notifyListeners();
  }

  /// Pick an image from gallery or camera, copy it to app's persistent
  /// documents directory, and save the path in settings for this user.
  Future<String?> pickAndSaveLogoImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (picked == null) return null;

      final docsDir = await getApplicationDocumentsDirectory();
      final logoDir = Directory('${docsDir.path}/logos');
      if (!logoDir.existsSync()) logoDir.createSync(recursive: true);

      final uid = _currentUserId ?? 'default';
      final destPath = '${logoDir.path}/shop_logo_$uid.jpg';
      final srcFile = File(picked.path);
      await srcFile.copy(destPath);

      _settings.logoImagePath = destPath;
      await _settings.save();
      notifyListeners();

      return destPath;
    } catch (e) {
      debugPrint('[SettingsViewModel] Error picking logo: $e');
      return null;
    }
  }

  /// Remove the shop logo
  Future<void> removeLogo() async {
    final path = _settings.logoImagePath;
    if (path != null && path.isNotEmpty) {
      final file = File(path);
      if (file.existsSync()) {
        try {
          await file.delete();
        } catch (_) {}
      }
    }
    _settings.logoImagePath = null;
    await _settings.save();
    notifyListeners();
  }

  Future<void> clearAllData() async {
    final billsBox = Hive.box<Bill>(AppConstants.billsBoxName);
    final userBills = billsBox.values
        .where((b) => _currentUserId == null || b.userId == _currentUserId)
        .toList();

    for (final bill in userBills) {
      MongoService.instance.deleteBill(bill.billNumber, userId: _currentUserId);
      await bill.delete();
    }

    _settings.lastBillNumber = 0;
    await _settings.save();
    MongoService.instance.saveSettings(_settings, userId: _currentUserId);
    notifyListeners();
  }

  Future<String> exportAsJson() async {
    final billsBox = Hive.box<Bill>(AppConstants.billsBoxName);
    final bills = billsBox.values
        .where((b) => _currentUserId == null || b.userId == _currentUserId)
        .toList();

    final jsonList = bills.map((b) => {
      'billNumber': b.billNumber,
      'customerName': b.customerName,
      'customerPhone': b.customerPhone,
      'serviceType': b.serviceType,
      'dateTime': b.dateTime.toIso8601String(),
      'subtotal': b.subtotal,
      'grandTotal': b.grandTotal,
      'advancePayment': b.advancePayment,
      'remainingAmount': b.remainingAmount,
      'comboPrice': b.comboPrice,
      'items': b.items.map((i) => {'itemName': i.itemName, 'price': i.price}).toList(),
    }).toList();
    return jsonList.toString();
  }

  String generateBillNumber() {
    _settings.lastBillNumber += 1;
    if (_settings.isInBox) {
      _settings.save();
    } else {
      _settingsBox.put(_currentSettingsKey, _settings);
    }
    MongoService.instance.saveSettings(_settings, userId: _currentUserId);
    return 'MK-${_settings.lastBillNumber.toString().padLeft(3, '0')}';
  }
}
