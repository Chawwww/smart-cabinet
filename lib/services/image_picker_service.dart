// lib/services/image_picker_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

class ImagePickerService {
  static final ImagePickerService _instance = ImagePickerService._internal();
  factory ImagePickerService() => _instance;
  ImagePickerService._internal();

  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ── Pick Image ──
  Future<File?> pickImage({ImageSource source = ImageSource.gallery}) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (image == null) return null;
      return File(image.path);
    } catch (e) {
      debugPrint('❌ Image pick error: $e');
      return null;
    }
  }

  Future<List<File>> pickMultipleImages({int maxCount = 5}) async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (images.isEmpty) return [];
      return images.map((x) => File(x.path)).toList();
    } catch (e) {
      debugPrint('❌ Multiple image pick error: $e');
      return [];
    }
  }

  // ── Upload to Firebase Storage ──
  Future<String> uploadImage({
    required File image,
    required String path,
    String? fileName,
  }) async {
    try {
      final filePath = fileName ?? path.basename(image.path);
      final ref = _storage.ref().child('$path/$filePath');
      await ref.putFile(image);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('❌ Image upload error: $e');
      rethrow;
    }
  }

  Future<List<String>> uploadMultipleImages({
    required List<File> images,
    required String path,
  }) async {
    final List<String> urls = [];
    for (final (index, image) in images.indexed) {
      try {
        final url = await uploadImage(
          image: image,
          path: path,
          fileName: '${DateTime.now().millisecondsSinceEpoch}_$index.jpg',
        );
        urls.add(url);
      } catch (e) {
        debugPrint('❌ Failed to upload image $index: $e');
      }
    }
    return urls;
  }

  // ── Delete Image ──
  Future<void> deleteImage(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (e) {
      debugPrint('❌ Image delete error: $e');
    }
  }

  // ── Compress Image ──
  Future<File> compressImage(File image, {int quality = 85}) async {
    try {
      final bytes = await image.readAsBytes();
      // For web/mobile, we use the image_picker quality setting instead
      return image;
    } catch (e) {
      debugPrint('❌ Image compression error: $e');
      return image;
    }
  }
}