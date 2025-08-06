// lib/models/chat_message.dart
import 'dart:typed_data';
import 'package:hive/hive.dart';

part 'chat_message.g.dart';

@HiveType(typeId: 1)
class ChatMessage extends HiveObject {
  @HiveField(0)
  late String text;

  @HiveField(1)
  late bool isUser;

  // This should only be here ONCE
  @HiveField(2)
  Uint8List? imageBytes;
}