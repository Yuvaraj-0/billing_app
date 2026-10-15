// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bill.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BillAdapter extends TypeAdapter<Bill> {
  @override
  final int typeId = 0;

  @override
  Bill read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Bill(
      billNumber: fields[0] as String,
      customerName: fields[1] as String,
      customerPhone: fields[2] as String?,
      serviceType: fields[3] as String,
      dateTime: fields[4] as DateTime,
      subtotal: fields[5] as double,
      grandTotal: fields[8] as double,
      items: (fields[9] as List).cast<BillItem>(),
      advancePayment: (fields[10] as double?) ?? 0.0,
      comboPrice: (fields[11] as double?) ?? 0.0,
      userId: fields[12] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Bill obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.billNumber)
      ..writeByte(1)
      ..write(obj.customerName)
      ..writeByte(2)
      ..write(obj.customerPhone)
      ..writeByte(3)
      ..write(obj.serviceType)
      ..writeByte(4)
      ..write(obj.dateTime)
      ..writeByte(5)
      ..write(obj.subtotal)
      ..writeByte(8)
      ..write(obj.grandTotal)
      ..writeByte(9)
      ..write(obj.items)
      ..writeByte(10)
      ..write(obj.advancePayment)
      ..writeByte(11)
      ..write(obj.comboPrice)
      ..writeByte(12)
      ..write(obj.userId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BillAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
