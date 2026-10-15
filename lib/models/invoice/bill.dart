import 'package:hive/hive.dart';
import 'bill_item.dart';

part 'bill.g.dart';

@HiveType(typeId: 0)
class Bill extends HiveObject {
  @HiveField(0)
  late String billNumber;

  @HiveField(1)
  late String customerName;

  @HiveField(2)
  String? customerPhone;

  @HiveField(3)
  late String serviceType;

  @HiveField(4)
  late DateTime dateTime;

  @HiveField(5)
  late double subtotal;

  @HiveField(8)
  late double grandTotal;

  @HiveField(9)
  late List<BillItem> items;

  @HiveField(10)
  double advancePayment;

  @HiveField(11)
  double comboPrice;

  @HiveField(12)
  String? userId;

  Bill({
    required this.billNumber,
    required this.customerName,
    this.customerPhone,
    required this.serviceType,
    required this.dateTime,
    required this.subtotal,
    required this.grandTotal,
    required this.items,
    this.advancePayment = 0.0,
    this.comboPrice = 0.0,
    this.userId,
  });

  bool get hasComboItems => items.any((i) => i.price == null || i.price == 0);
  double get individualItemsTotal => items.fold(0.0, (sum, i) => sum + (i.price ?? 0.0));
  double get remainingAmount => (grandTotal - advancePayment).clamp(0.0, double.infinity);
  bool get isPaidInFull => remainingAmount <= 0;

  Map<String, dynamic> toMap() {
    return {
      'billNumber': billNumber,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'serviceType': serviceType,
      'dateTime': dateTime.toIso8601String(),
      'subtotal': subtotal,
      'grandTotal': grandTotal,
      'advancePayment': advancePayment,
      'comboPrice': comboPrice,
      'remainingAmount': remainingAmount,
      'isPaidInFull': isPaidInFull,
      'items': items.map((i) => i.toMap()).toList(),
      'userId': userId,
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  factory Bill.fromMap(Map<String, dynamic> map) {
    return Bill(
      billNumber: map['billNumber'] as String? ?? '',
      customerName: map['customerName'] as String? ?? '',
      customerPhone: map['customerPhone'] as String?,
      serviceType: map['serviceType'] as String? ?? 'Photography Service',
      dateTime: map['dateTime'] != null
          ? DateTime.tryParse(map['dateTime'].toString()) ?? DateTime.now()
          : DateTime.now(),
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      grandTotal: (map['grandTotal'] as num?)?.toDouble() ?? 0.0,
      advancePayment: (map['advancePayment'] as num?)?.toDouble() ?? 0.0,
      comboPrice: (map['comboPrice'] as num?)?.toDouble() ?? 0.0,
      userId: map['userId'] as String?,
      items: (map['items'] as List<dynamic>?)
              ?.map((item) => BillItem.fromMap(Map<String, dynamic>.from(item as Map)))
              .toList() ??
          [],
    );
  }
}

