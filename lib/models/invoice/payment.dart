import 'package:hive/hive.dart';
import 'payment_method.dart';

part 'payment.g.dart';

@HiveType(typeId: 5)
class Payment extends HiveObject {
  @HiveField(0)
  double amount;

  @HiveField(1)
  PaymentMethod method;

  @HiveField(2)
  DateTime paymentDate;

  @HiveField(3)
  String? notes;

  Payment({
    required this.amount,
    required this.method,
    required this.paymentDate,
    this.notes,
  });
}