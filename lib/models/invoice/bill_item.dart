import 'package:hive/hive.dart';

part 'bill_item.g.dart';

@HiveType(typeId: 1)
class BillItem extends HiveObject {
  @HiveField(0)
  String itemName;

  // Null when using package pricing
  @HiveField(1)
  double? price;

  // Whether to show this price in the invoice
  @HiveField(2)
  bool showPrice;

  BillItem({
    required this.itemName,
    this.price,
    this.showPrice = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'itemName': itemName,
      'price': price,
      'showPrice': showPrice,
    };
  }

  factory BillItem.fromMap(Map<String, dynamic> map) {
    return BillItem(
      itemName: map['itemName'] as String? ?? '',
      price: (map['price'] as num?)?.toDouble(),
      showPrice: map['showPrice'] as bool? ?? true,
    );
  }
}