import 'package:hive/hive.dart';

part 'payment_method.g.dart';

@HiveType(typeId: 3)
enum PaymentMethod {
  @HiveField(0)
  cash,

  @HiveField(1)
  upi,

  @HiveField(2)
  bankTransfer,

  @HiveField(3)
  card,

  @HiveField(4)
  cheque,
}