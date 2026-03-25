import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  await Firebase.initializeApp();

  String? targetExtension;
  if (args.isNotEmpty) {
    targetExtension = args[0].startsWith('.') ? args[0].toLowerCase() : '.${args[0].toLowerCase()}';
  }

  await uploadProjectFiles(targetExtension);
}

Future<void> uploadProjectFiles(String? filterExtension) async {
  final Directory projectDir = Directory(Directory.current.path);
  final List<FileSystemEntity> files = await projectDir.list(recursive: true).toList();
  final List<File> filteredFiles = files.whereType<File>().where((File file) {
    if (filterExtension == null) return true;
    return p.extension(file.path).toLowerCase() == filterExtension;
  }).toList();

  final int totalFiles = filteredFiles.length;
  int uploadedFiles = 0;

  print('Starting upload of $totalFiles files...');

  for (File entity in filteredFiles) {
    final String extension = p.extension(entity.path).toLowerCase();
    final String fileName = p.basename(entity.path);
    final int fileSize = await entity.length();

    try {
      if (<String>['.dart', '.yaml', '.plist'].contains(extension) || (extension == '.json' && fileSize > 100 * 1024)) {
        final Reference ref = FirebaseStorage.instance.ref('source-backups/$fileName');
        await ref.putFile(entity);
        print('Uploaded $fileName to Firebase Storage.');
      } else if (extension == '.json' && fileSize <= 100 * 1024) {
        final String content = await entity.readAsString();
        final Map<String, dynamic> data = jsonDecode(content);
        await FirebaseFirestore.instance.collection('uploaded_data').doc(fileName).set(data);
        print('Uploaded $fileName to Firestore.');
      } else {
        final Reference ref = FirebaseStorage.instance.ref('other-backups/$fileName');
        await ref.putFile(entity);
        print('Uploaded $fileName to other-backups Storage folder.');
      }
    } catch (e) {
      print('Failed to upload $fileName: $e');
    }

    uploadedFiles++;
    final double progress = (uploadedFiles / totalFiles) * 100;
    print('Progress: ${progress.toStringAsFixed(2)}%');
  }

  print('All files processed. Upload complete.');
}
