import 'package:cloud_functions/cloud_functions.dart';

class CabinetShareService {
  CabinetShareService._();
  static final instance = CabinetShareService._();
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');

  Future<void> shareByEmail(
      {required String cabinetId,
      required String email,
      required String permission}) async {
    await _functions.httpsCallable('shareCabinetByEmail').call({
      'cabinetId': cabinetId,
      'email': email.trim().toLowerCase(),
      'permission': permission,
    });
  }

  Future<String> createInvite(
      {required String cabinetId, required String permission}) async {
    final result = await _functions.httpsCallable('createCabinetInvite').call({
      'cabinetId': cabinetId,
      'permission': permission,
    });
    return (result.data as Map)['link'] as String;
  }

  Future<void> acceptInvite(String input) async {
    final uri = Uri.tryParse(input.trim());
    final inviteId = uri?.queryParameters['invite'] ?? input.trim();
    await _functions
        .httpsCallable('acceptCabinetInvite')
        .call({'inviteId': inviteId});
  }
}
