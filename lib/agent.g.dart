// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AgentAdapter extends TypeAdapter<Agent> {
  @override
  final int typeId = 0;

  @override
  Agent read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Agent()
      ..name = fields[0] as String
      ..persona = fields[1] as String
      ..toolNames = (fields[2] as List).cast<String>()
      ..iconName = fields[3] as String
      ..history = (fields[4] as List).cast<ChatMessage>();
  }

  @override
  void write(BinaryWriter writer, Agent obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.persona)
      ..writeByte(2)
      ..write(obj.toolNames)
      ..writeByte(3)
      ..write(obj.iconName)
      ..writeByte(4)
      ..write(obj.history);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AgentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
