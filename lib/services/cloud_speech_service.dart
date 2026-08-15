import 'dart:convert';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';

class CloudSpeechService {
  CloudSpeechService._();
  static final instance = CloudSpeechService._();

  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  Future<String> transcribe(File recording, String languageCode) async {
    final bytes = await recording.readAsBytes();
    final result = await _functions.httpsCallable('transcribeVoice').call({
      'audioBase64': base64Encode(bytes),
      'languageCode': languageCode,
    });
    return ((result.data as Map)['transcript'] as String? ?? '').trim();
  }

  Future<bool> isAzureSpeechConfigured() async {
    try {
      final result = await _functions
          .httpsCallable('checkAzureSpeechAvailability')
          .call();
      return ((result.data as Map)['azureSpeechConfigured'] as bool?) ?? false;
    } catch (_) {
      return false;
    }
  }
}
