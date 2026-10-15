import 'package:hive/hive.dart';

part 'app_settings.g.dart';

@HiveType(typeId: 2)
class AppSettings extends HiveObject {
  @HiveField(0)
  String shopName;

  @HiveField(2)
  bool autoIncrement;

  @HiveField(3)
  int lastBillNumber;

  @HiveField(4)
  String currencySymbol;

  /// Local file path to the shop logo image (null if not set)
  @HiveField(5)
  String? logoImagePath;

  AppSettings({
    this.shopName = 'MK Star',
    this.autoIncrement = true,
    this.lastBillNumber = 0,
    this.currencySymbol = '₹',
    this.logoImagePath,
  });

  Map<String, dynamic> toMap() {
    return {
      'shopName': shopName,
      'autoIncrement': autoIncrement,
      'lastBillNumber': lastBillNumber,
      'currencySymbol': currencySymbol,
      // Note: logoImagePath is device-local, not synced to cloud
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      shopName: map['shopName'] as String? ?? 'MK Star',
      autoIncrement: map['autoIncrement'] as bool? ?? true,
      lastBillNumber: (map['lastBillNumber'] as num?)?.toInt() ?? 0,
      currencySymbol: map['currencySymbol'] as String? ?? '₹',
      // logoImagePath intentionally not restored from cloud (device-local)
    );
  }
}
