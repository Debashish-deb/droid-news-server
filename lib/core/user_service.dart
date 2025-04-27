import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> saveUserProfile({
    required String email,
    required String name,
    required String avatarUrl,
  }) async {
    final userDoc = _firestore.collection('users').doc(email);
    await userDoc.set({
      'name': name,
      'email': email,
      'avatar': avatarUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> getUserProfile(String email) async {
    final userDoc = await _firestore.collection('users').doc(email).get();
    return userDoc.exists ? userDoc.data() : null;
  }
}
