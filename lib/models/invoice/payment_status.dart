import 'package:hive/hive.dart';

part 'payment_status.g.dart';

@HiveType(typeId: 4)
enum PaymentStatus {
  @HiveField(0)
  pending,

  @HiveField(1)
  partial,

  @HiveField(2)
  paid,

  @HiveField(3)
  cancelled,
}