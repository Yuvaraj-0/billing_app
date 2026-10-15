part of 'payment_status.dart';

class PaymentStatusAdapter extends TypeAdapter<PaymentStatus> {
  @override
  final int typeId = 4;

  @override
  PaymentStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return PaymentStatus.pending;
      case 1:
        return PaymentStatus.partial;
      case 2:
        return PaymentStatus.paid;
      case 3:
        return PaymentStatus.cancelled;
      default:
        return PaymentStatus.pending;
    }
  }

  @override
  void write(BinaryWriter writer, PaymentStatus obj) {
    switch (obj) {
      case PaymentStatus.pending:
        writer.writeByte(0);
        break;
      case PaymentStatus.partial:
        writer.writeByte(1);
        break;
      case PaymentStatus.paid:
        writer.writeByte(2);
        break;
      case PaymentStatus.cancelled:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaymentStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

