import 'package:flutter_dotenv/flutter_dotenv.dart';

class Config {
  static String get skOrV1Key => dotenv.env['GEMINI_API_KEY'] ?? '';
}
