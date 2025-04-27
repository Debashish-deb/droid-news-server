// lib/firebase_storage_service.dart

import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String> uploadUserProfilePicture(File file) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user');
    }
    final ref = _storage.ref('user_uploads/${user.uid}/profile_pic.jpg');
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  Future<String> uploadPrivateFile(File file, String fileName) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user');
    }
    final ref = _storage.ref('private/${user.uid}/$fileName');
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  Future<String> getPublicFileUrl(String fileName) async {
    final ref = _storage.ref('public/$fileName');
    return await ref.getDownloadURL();
  }

  Future<void> deleteUserProfilePicture() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user');
    }
    final ref = _storage.ref('user_uploads/${user.uid}/profile_pic.jpg');
    await ref.delete();
  }
}
