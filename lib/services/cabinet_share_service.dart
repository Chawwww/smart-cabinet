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

  /// Share cabinet with multiple users at once
  Future<Map<String, dynamic>> bulkShareCabinet({
    required String cabinetId,
    required List<String> emails,
    required String permission,
  }) async {
    final result = await _functions.httpsCallable('bulkShareCabinet').call({
      'cabinetId': cabinetId,
      'emails': emails.map((e) => e.trim().toLowerCase()).toList(),
      'permission': permission,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  /// List all pending (not yet accepted) invitations for a cabinet
  Future<List<Map<String, dynamic>>> listCabinetInvites(
      String cabinetId) async {
    final result = await _functions.httpsCallable('listCabinetInvites').call({
      'cabinetId': cabinetId,
    });
    final invites = (result.data as Map)['invites'] as List? ?? [];
    return invites.cast<Map<String, dynamic>>();
  }

  /// Revoke (delete) a pending invitation
  Future<void> revokeInvite({
    required String cabinetId,
    required String inviteId,
  }) async {
    await _functions.httpsCallable('revokeInvite').call({
      'cabinetId': cabinetId,
      'inviteId': inviteId,
    });
  }
}
