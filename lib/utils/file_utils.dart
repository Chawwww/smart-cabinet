// lib/utils/file_utils.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

class FileUtils {
  // ── Get Temporary Directory ──
  static Future<String> getTempDirectory() async {
    final dir = await getTemporaryDirectory();
    return dir.path;
  }

  // ── Get Documents Directory ──
  static Future<String> getDocumentsDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  // ── Save File ──
  static Future<File> saveFile({
    required String fileName,
    required String content,
    String? directory,
  }) async {
    final dir = directory ?? await getDocumentsDirectory();
    final filePath = '$dir/$fileName';
    final file = File(filePath);
    await file.writeAsString(content);
    return file;
  }

  // ── Save Bytes ──
  static Future<File> saveBytes({
    required String fileName,
    required List<int> bytes,
    String? directory,
  }) async {
    final dir = directory ?? await getDocumentsDirectory();
    final filePath = '$dir/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(bytes);
    return file;
  }

  // ── Read File ──
  static Future<String> readFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return '';
    return await file.readAsString();
  }

  // ── Delete File ──
  static Future<bool> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // ── File Size ──
  static Future<int> getFileSize(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return await file.length();
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  // ── Get File Extension ──
  static String getFileExtension(String filePath) {
    return path.extension(filePath).replaceFirst('.', '').toLowerCase();
  }

  // ── Get File Name ──
  static String getFileName(String filePath) {
    return path.basename(filePath);
  }

  // ── Get File Name Without Extension ──
  static String getFileNameWithoutExtension(String filePath) {
    return path.basenameWithoutExtension(filePath);
  }

  // ── Check if File Exists ──
  static Future<bool> fileExists(String filePath) async {
    return await File(filePath).exists();
  }

  // ── Copy File ──
  static Future<File> copyFile({
    required String sourcePath,
    required String destinationPath,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) throw Exception('Source file does not exist');
    return await source.copy(destinationPath);
  }

  // ── Move File ──
  static Future<File> moveFile({
    required String sourcePath,
    required String destinationPath,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) throw Exception('Source file does not exist');
    return await source.rename(destinationPath);
  }

  // ── List Files in Directory ──
  static Future<List<FileSystemEntity>> listFiles(String directory) async {
    final dir = Directory(directory);
    if (!await dir.exists()) return [];
    return await dir.list().toList();
  }

  // ── Create Directory ──
  static Future<void> createDirectory(String directory) async {
    final dir = Directory(directory);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  // ── Delete Directory ──
  static Future<void> deleteDirectory(String directory) async {
    final dir = Directory(directory);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  // ── Get MIME Type ──
  static String getMimeType(String filePath) {
    final ext = getFileExtension(filePath);
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'svg':
        return 'image/svg+xml';
      case 'pdf':
        return 'application/pdf';
      case 'txt':
        return 'text/plain';
      case 'csv':
        return 'text/csv';
      case 'json':
        return 'application/json';
      case 'mp4':
        return 'video/mp4';
      case 'mp3':
        return 'audio/mpeg';
      default:
        return 'application/octet-stream';
    }
  }

  // ── Is Image ──
  static bool isImageFile(String filePath) {
    final ext = getFileExtension(filePath);
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg', 'heic'].contains(ext);
  }

  // ── Is Video ──
  static bool isVideoFile(String filePath) {
    final ext = getFileExtension(filePath);
    return ['mp4', 'avi', 'mov', 'wmv', 'flv', 'mkv'].contains(ext);
  }

  // ── Is Audio ──
  static bool isAudioFile(String filePath) {
    final ext = getFileExtension(filePath);
    return ['mp3', 'wav', 'aac', 'flac', 'ogg'].contains(ext);
  }

  // ── Pick File ──
  static Future<File?> pickFile({
    List<String>? allowedExtensions,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FilePickerType.custom,
        allowedExtensions: allowedExtensions,
      );
      if (result == null || result.files.isEmpty) return null;
      final file = result.files.first;
      if (file.path == null) return null;
      return File(file.path!);
    } catch (e) {
      debugPrint('❌ File pick error: $e');
      return null;
    }
  }

  // ── Pick Image ──
  static Future<File?> pickImage({ImageSource source = ImageSource.gallery}) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
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
}