// lib/tools/firebase_upload.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../lib/firebase_options.dart';

Future<void> uploadDataFromJson() async {
  final jsonString = await rootBundle.loadString('assets/data.json');
  final data = jsonDecode(jsonString);
  final newspapers = data['newspapers'] as List<dynamic>? ?? [];
  final magazines  = data['magazines']  as List<dynamic>? ?? [];

  final firestore = FirebaseFirestore.instance;
  final batch     = firestore.batch();

  for (var item in newspapers) {
    final id = item['id'] as String;
    batch.set(firestore.collection('newspapers').doc(id), item);
  }
  for (var item in magazines) {
    final id = item['id'] as String;
    batch.set(firestore.collection('magazines').doc(id), item);
  }

  await batch.commit();
  print('✅ Upload complete');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await uploadDataFromJson();
  // Exit the app after upload—no UI needed
  // On Android, this closes the process; on others it just ends.
}
