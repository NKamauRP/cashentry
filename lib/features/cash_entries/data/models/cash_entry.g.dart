// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cash_entry.dart';

class CashEntryAdapter extends TypeAdapter<CashEntry> {
  @override
  final int typeId = 0;

  @override
  CashEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    return CashEntry(
      date: fields[0] as DateTime,
      cash: (fields[1] as num).toDouble(),
      cashNotes: (fields[2] as num).toDouble(),
      coins: (fields[3] as num).toDouble(),
      till: (fields[4] as num).toDouble(),
      expenses: (fields[5] as num).toDouble(),
      userId: fields[6] as String? ?? '',
      branchId: fields[7] as String? ?? '',
    );
  }

  @override
  void write(BinaryWriter writer, CashEntry obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.cash)
      ..writeByte(2)
      ..write(obj.cashNotes)
      ..writeByte(3)
      ..write(obj.coins)
      ..writeByte(4)
      ..write(obj.till)
      ..writeByte(5)
      ..write(obj.expenses)
      ..writeByte(6)
      ..write(obj.userId)
      ..writeByte(7)
      ..write(obj.branchId);
  }
}
