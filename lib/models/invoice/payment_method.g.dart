part of 'payment_method.dart';

class PaymentMethodAdapter extends TypeAdapter<PaymentMethod> {
  @override
  final int typeId = 3;

  @override
  PaymentMethod read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return PaymentMethod.cash;
      case 1:
        return PaymentMethod.upi;
      case 2:
        return PaymentMethod.bankTransfer;
      case 3:
        return PaymentMethod.card;
      case 4:
        return PaymentMethod.cheque;
      default:
        return PaymentMethod.cash;
    }
  }

  @override
  void write(BinaryWriter writer, PaymentMethod obj) {
    switch (obj) {
      case PaymentMethod.cash:
        writer.writeByte(0);
        break;
      case PaymentMethod.upi:
        writer.writeByte(1);
        break;
      case PaymentMethod.bankTransfer:
        writer.writeByte(2);
        break;
      case PaymentMethod.card:
        writer.writeByte(3);
        break;
      case PaymentMethod.cheque:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaymentMethodAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

