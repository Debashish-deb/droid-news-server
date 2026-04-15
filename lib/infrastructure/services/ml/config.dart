// ignore_for_file: avoid_classes_with_only_static_members

import 'package:flutter_dotenv/flutter_dotenv.dart';

class Config {
  static String get skOrV1Key => dotenv.env['GEMINI_API_KEY'] ?? '';
}
